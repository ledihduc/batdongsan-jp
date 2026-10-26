"""source_id_not_null_v2

Phase 04 analytics — enforce NOT NULL trên reservations.source_id và
contracts.source_id sau khi service layer dual-write source_id trên mọi INSERT.

Lịch sử:
- 0014: backfill source_id từ source string sang FK
- 0017: ORIGINAL plan để enforce NOT NULL — chuyển thành no-op vì service
        layer chưa dual-write, gây cascade NotNullViolation trong tests
- 0018: thực thi enforce NOT NULL sau khi reservation_service /
        contract_service / marketplace_sync_service đã dual-write source_id

Idempotent backfill (re-run 0014 logic) chạy trước ALTER COLUMN — phòng trường
hợp có row nào insert giữa 0014 và 0018 mà bypass service layer.

SQLite: dùng batch_alter_table để Alembic tái tạo bảng với constraint mới.

Revision ID: 0018_source_id_not_null_v2
Revises: 0017_source_id_not_null
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0018_source_id_not_null_v2"
down_revision: Union[str, Sequence[str], None] = "0017_source_id_not_null"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_UPDATE_RESERVATIONS = sa.text(
    """
    UPDATE reservations
    SET source_id = (
        SELECT rs.id FROM revenue_sources rs
        WHERE rs.host_id = reservations.host_id
          AND rs.name = CASE reservations.source
            WHEN 'marketplace' THEN 'Marketplace nội bộ'
            WHEN 'direct'      THEN 'Trực tiếp'
            WHEN 'manual'      THEN 'Khác'
            ELSE                    'Khác'
          END
        LIMIT 1
    )
    WHERE reservations.source_id IS NULL
    """
)
_UPDATE_CONTRACTS = sa.text(
    """
    UPDATE contracts
    SET source_id = (
        SELECT rs.id FROM revenue_sources rs
        WHERE rs.host_id = contracts.host_id
          AND rs.name = CASE contracts.source
            WHEN 'marketplace' THEN 'Marketplace nội bộ'
            WHEN 'direct'      THEN 'Trực tiếp'
            WHEN 'manual'      THEN 'Khác'
            ELSE                    'Khác'
          END
        LIMIT 1
    )
    WHERE contracts.source_id IS NULL
    """
)
_COUNT_NULL_RESERVATIONS = sa.text(
    "SELECT COUNT(*) FROM reservations WHERE source_id IS NULL"
)
_COUNT_NULL_CONTRACTS = sa.text(
    "SELECT COUNT(*) FROM contracts WHERE source_id IS NULL"
)


def upgrade() -> None:
    connection = op.get_bind()

    # Phase 1 — idempotent re-backfill (catches anything inserted between 0014
    # và 0018 mà chưa có source_id, dù service layer hiện đã dual-write).
    connection.execute(_UPDATE_RESERVATIONS)
    connection.execute(_UPDATE_CONTRACTS)

    # Phase 2 — pre-check: phải sạch 100% trước khi ALTER NOT NULL.
    null_res = connection.execute(_COUNT_NULL_RESERVATIONS).scalar() or 0
    null_con = connection.execute(_COUNT_NULL_CONTRACTS).scalar() or 0
    if null_res > 0 or null_con > 0:
        raise RuntimeError(
            f"Cannot enforce NOT NULL: {null_res} reservation(s) and "
            f"{null_con} contract(s) still have source_id IS NULL after "
            "re-backfill. Investigate orphan rows trước khi tiếp tục."
        )

    # Phase 3 — enforce NOT NULL (batch mode để SQLite tái tạo bảng).
    with op.batch_alter_table("reservations") as batch_op:
        batch_op.alter_column(
            "source_id",
            existing_type=sa.Integer(),
            nullable=False,
        )

    with op.batch_alter_table("contracts") as batch_op:
        batch_op.alter_column(
            "source_id",
            existing_type=sa.Integer(),
            nullable=False,
        )


def downgrade() -> None:
    # Revert NOT NULL → nullable=True. Không null-ify dữ liệu (downgrade
    # không có lý do gì xoá FK đã backfill).
    with op.batch_alter_table("contracts") as batch_op:
        batch_op.alter_column(
            "source_id",
            existing_type=sa.Integer(),
            nullable=True,
        )

    with op.batch_alter_table("reservations") as batch_op:
        batch_op.alter_column(
            "source_id",
            existing_type=sa.Integer(),
            nullable=True,
        )
