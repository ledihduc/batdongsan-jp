"""Add nullable currency column to invoices; backfill VND for existing VN rows.

Phase 00 JP foundation: invoices need a currency field to distinguish VND (VN)
from JPY (JP) in a multi-region deployment.

Strategy (two-migration approach per spec):
  - Migration 0141 (this): add nullable currency VARCHAR(3), backfill to 'VND'.
    Nullable so existing rows without values are not broken during migration.
  - Migration 0142 (future, when JP writes are live): add NOT NULL constraint.

Idempotent: uses inspect().has_column() before adding column.
Has downgrade(): removes the column if rolled back.

Revision ID: 0141_invoice_currency
Revises: 0140_ekyc_chu_nha
"""

from alembic import op
import sqlalchemy as sa

revision = "0141_invoice_currency"
down_revision = "0140_ekyc_chu_nha"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # Idempotent: only add if not already present.
    existing_cols = {col["name"] for col in insp.get_columns("invoices")}
    if "currency" not in existing_cols:
        op.add_column(
            "invoices",
            sa.Column(
                "currency",
                sa.String(3),
                nullable=True,
                comment="ISO 4217 currency code (VND, JPY). NULL = legacy VN row.",
            ),
        )
        # Backfill all existing rows to 'VND' (they are VN rows by definition).
        op.execute(
            sa.text("UPDATE invoices SET currency = 'VND' WHERE currency IS NULL")
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    existing_cols = {col["name"] for col in insp.get_columns("invoices")}
    if "currency" in existing_cols:
        op.drop_column("invoices", "currency")
