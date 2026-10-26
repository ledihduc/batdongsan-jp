"""extend invoices with platform fee columns (NFR-15 forward-compat)

Revision ID: 0034_extend_invoices_platform_fee
Revises: 0033_extend_audit_logs_dual_identity
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

NFR-15 / TL-2: platform_fee_pct and platform_fee_amount forward-compat columns.
  - v1: both NULL (FREE tier — no platform fee charged)
  - v1.5 freemium: set platform_fee_pct at invoice generation; platform_fee_amount
    computed = total_amount × platform_fee_pct and locked at paid_at
    (mirrors existing commission_amount immutability pattern)
  - NOT on a separate payouts table (TL-2 decision: denormalized snapshot on invoices)

AC-33: expected_owner_payout = total_amount - commission_amount - platform_fee_amount
  (computed at read time when platform_fee_amount is non-NULL)

NUMERIC(5,4) allows fractional percentage: e.g., 0.0250 = 2.5%.
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0034_extend_invoices_platform_fee"
down_revision = "0033_extend_audit_logs_dual_identity"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("invoices") as batch_op:
        # Platform fee percentage at invoice generation (NULL = FREE tier v1)
        # NUMERIC(5,4): supports 0.0001 to 99.9999 (fractional percent precision)
        batch_op.add_column(
            sa.Column("platform_fee_pct", sa.Numeric(5, 4), nullable=True)
        )
        # Platform fee amount locked at paid_at (mirrors commission immutability)
        # NUMERIC(15,0): whole VND
        batch_op.add_column(
            sa.Column("platform_fee_amount", sa.Numeric(15, 0), nullable=True)
        )


def downgrade() -> None:
    with op.batch_alter_table("invoices") as batch_op:
        batch_op.drop_column("platform_fee_amount")
        batch_op.drop_column("platform_fee_pct")
