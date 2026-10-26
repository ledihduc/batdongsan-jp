"""add_commission_columns

Phase 04 analytics — thêm commission_rate và commission_amount vào reservations
và invoices.

Thiết kế denormalized (cả 2 bảng):
  - Reservation.commission_rate: tỉ lệ % hoa hồng áp dụng cho booking.
  - Reservation.commission_amount: tổng hoa hồng (computed = rate × total_amount).
  - Invoice.commission_rate: snapshot tỉ lệ tại thời điểm xuất hóa đơn.
  - Invoice.commission_amount: hoa hồng thực thu (locked khi Invoice.paid_at, per Q3).

NULL = booking cũ không có hoa hồng (legacy). Xử lý theo AC-04: NULL → 0 trong
analytics queries (gross = net với data cũ).

Index ix_invoices_commission trên (host_id, commission_amount) hỗ trợ revenue
report query theo host theo tháng.

Revision ID: 0015_add_commission_columns
Revises: 0014_backfill_source_id
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0015_add_commission_columns"
down_revision: Union[str, Sequence[str], None] = "0014_backfill_source_id"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # reservations: commission_rate + commission_amount
    op.add_column(
        "reservations",
        sa.Column("commission_rate", sa.Float(), nullable=True),
    )
    op.add_column(
        "reservations",
        sa.Column("commission_amount", sa.Float(), nullable=True),
    )

    # invoices: commission_rate + commission_amount
    op.add_column(
        "invoices",
        sa.Column("commission_rate", sa.Float(), nullable=True),
    )
    op.add_column(
        "invoices",
        sa.Column("commission_amount", sa.Float(), nullable=True),
    )

    # Composite index để tăng tốc analytics query theo host + commission
    op.create_index(
        "ix_invoices_commission",
        "invoices",
        ["host_id", "commission_amount"],
    )


def downgrade() -> None:
    op.drop_index("ix_invoices_commission", table_name="invoices")
    op.drop_column("invoices", "commission_amount")
    op.drop_column("invoices", "commission_rate")
    op.drop_column("reservations", "commission_amount")
    op.drop_column("reservations", "commission_rate")
