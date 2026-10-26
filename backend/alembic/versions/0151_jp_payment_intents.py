"""Create jp_payment_intents table — tracks payment requests to JP payment provider.

One intent per payment attempt. Provider (Komoju) returns a provider_intent_id which
is used for status polling and webhook correlation.

Status state machine:
  pending → processing → succeeded | failed | expired

Idempotent: checks has_table() before create.
Has downgrade(): drops table.

Revision ID: 0151_jp_payment_intents
Revises: 0150_jp_invoice_lines
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0151_jp_payment_intents"
down_revision = "0150_jp_invoice_lines"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    json_type = (
        postgresql.JSONB()
        if bind.dialect.name == "postgresql"
        else sa.JSON()
    )

    if not insp.has_table("jp_payment_intents"):
        op.create_table(
            "jp_payment_intents",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "org_id", sa.String(64), nullable=False, index=True,
                comment="Broker org tenant ID. MUST be filtered in every list query.",
            ),
            sa.Column(
                "region", sa.String(3), nullable=False, server_default="jp",
                comment="Defense-in-depth region tag. Always 'jp'.",
            ),
            # Parent invoice
            sa.Column(
                "invoice_id", sa.String(64), nullable=False, index=True,
                comment="Invoice UUID. No FK — cross-domain boundary.",
            ),
            # Provider details
            sa.Column(
                "provider", sa.String(32), nullable=False, server_default="komoju",
                comment="Payment provider name (e.g. komoju).",
            ),
            # No inline index=True — explicit op.create_index below owns the
            # ix_jp_payment_intents_provider_intent_id index.
            sa.Column(
                "provider_intent_id", sa.String(128), nullable=True,
                comment="Provider's opaque payment intent ID for correlation.",
            ),
            # Payment method
            sa.Column(
                "method", sa.String(20), nullable=False,
                comment="card | konbini | bank_transfer",
            ),
            # Status
            sa.Column(
                "status", sa.String(20), nullable=False, server_default="pending",
                comment="pending | processing | succeeded | failed | expired",
            ),
            # Amount
            sa.Column(
                "amount_jpy", sa.Numeric(12, 0), nullable=False,
                comment="Total amount in JPY.",
            ),
            # Extra provider data (voucher codes, URLs, etc.)
            sa.Column(
                "metadata", json_type, nullable=True,
                comment="Freeform provider metadata (konbini voucher code, bank ref, etc.).",
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column(
                "updated_at", sa.DateTime(), nullable=False,
                server_default=sa.func.now(), onupdate=sa.func.now(),
            ),
        )

        op.create_index(
            "ix_jp_payment_intents_provider_intent_id",
            "jp_payment_intents",
            ["provider_intent_id"],
        )


def downgrade() -> None:
    op.drop_table("jp_payment_intents")
