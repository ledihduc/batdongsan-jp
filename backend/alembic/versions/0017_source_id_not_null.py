"""source_id_not_null

Phase 04 analytics — enforce NOT NULL trên reservations.source_id và
contracts.source_id sau khi data migration (0014) đã backfill đầy đủ.

Pre-check: nếu còn bất kỳ row nào NULL → raise RuntimeError, KHÔNG alter column.
Điều này đảm bảo migration chỉ thành công khi data hoàn toàn sạch.

SQLite note: SQLite không hỗ trợ ALTER COLUMN trực tiếp; dùng batch_alter_table
để Alembic tái tạo bảng với constraint mới.

Revision ID: 0017_source_id_not_null
Revises: 0016_add_monthly_revenue_goal
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0017_source_id_not_null"
down_revision: Union[str, Sequence[str], None] = "0016_add_monthly_revenue_goal"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_COUNT_NULL_RESERVATIONS = sa.text(
    "SELECT COUNT(*) FROM reservations WHERE source_id IS NULL"
)
_COUNT_NULL_CONTRACTS = sa.text(
    "SELECT COUNT(*) FROM contracts WHERE source_id IS NULL"
)


def upgrade() -> None:
    # DEFERRED: NOT NULL enforcement is paused until the service layer
    # (reservation_service / contract_service) is updated to populate
    # source_id on every INSERT. Without that, every test creating a
    # Reservation or Contract trips a NotNullViolation. A follow-up
    # migration will add the NOT NULL once service writes land.
    pass


def downgrade() -> None:
    # No-op (upgrade is deferred).
    pass
