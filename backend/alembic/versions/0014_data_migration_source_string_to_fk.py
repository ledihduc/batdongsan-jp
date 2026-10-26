"""data_migration_source_string_to_fk

Phase 04 analytics — backfill source_id từ giá trị String enum cũ sang FK.

Mapping:
  'marketplace' → 'Marketplace nội bộ'
  'direct'      → 'Trực tiếp'
  'manual'      → 'Khác'
  ELSE          → 'Khác'   (fallback cho giá trị không xác định)

Sau UPDATE, chạy verify query: nếu còn bất kỳ row nào có source_id IS NULL
thì raise RuntimeError để fail migration (transaction rollback).

Downgrade: đặt source_id về NULL (data migration có thể re-run sau khi revert).

Revision ID: 0014_backfill_source_id
Revises: 0013_add_source_id_fk_nullable
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0014_backfill_source_id"
down_revision: Union[str, Sequence[str], None] = "0013_add_source_id_fk_nullable"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Mapping từ string enum → tên nguồn thu trong revenue_sources
_SOURCE_NAME_MAP = {
    "marketplace": "Marketplace nội bộ",
    "direct": "Trực tiếp",
    "manual": "Khác",
}

# Câu UPDATE dùng subquery CASE để map inline — không cần loop Python.
# Dùng LIMIT 1 trong subquery để tránh lỗi "more than one row" trên dữ liệu bất thường.
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

    # Backfill reservations
    connection.execute(_UPDATE_RESERVATIONS)

    # Backfill contracts
    connection.execute(_UPDATE_CONTRACTS)

    # Verify: nếu còn NULL → fail fast (transaction sẽ rollback)
    null_res = connection.execute(_COUNT_NULL_RESERVATIONS).scalar() or 0
    null_con = connection.execute(_COUNT_NULL_CONTRACTS).scalar() or 0

    if null_res > 0 or null_con > 0:
        raise RuntimeError(
            f"Data migration failed: {null_res} reservation(s) and "
            f"{null_con} contract(s) still have source_id IS NULL. "
            "Check for rows with NULL host_id or missing revenue_sources seed."
        )


def downgrade() -> None:
    # NULL-ify source_id — idempotent, safe để re-run upgrade() sau khi revert
    connection = op.get_bind()
    connection.execute(sa.text("UPDATE reservations SET source_id = NULL"))
    connection.execute(sa.text("UPDATE contracts SET source_id = NULL"))
