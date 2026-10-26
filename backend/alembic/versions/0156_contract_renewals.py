"""Create jp_contract_renewals table — 更新 renewal cycle.

Tracks 60-day pre-expiry renewal invoicing for JP rental contracts.

Status state machine:
  pending → invoiced → confirmed → renewed | expired

Idempotent: checks has_table() before create.
Has downgrade(): drops table.

Revision ID: 0156_contract_renewals
Revises: 0155_jp_econtracts
"""

from alembic import op
import sqlalchemy as sa

revision = "0156_contract_renewals"
down_revision = "0155_jp_econtracts"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_contract_renewals"):
        op.create_table(
            "jp_contract_renewals",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "org_id", sa.String(64), nullable=False, index=True,
                comment="Broker org tenant ID. MUST be filtered in every list query.",
            ),
            sa.Column(
                "region", sa.String(3), nullable=False, server_default="jp",
                comment="Defense-in-depth region tag. Always 'jp'.",
            ),
            sa.Column(
                "contract_id", sa.Integer(), nullable=False, index=True,
                comment="Platform contract ID. No FK — cross-domain boundary.",
            ),
            sa.Column(
                "scheduled_at", sa.DateTime(timezone=True), nullable=False,
                comment="When renewal notification/invoice should fire (contract.expires_at - 60d).",
            ),
            sa.Column(
                "renewal_fee_jpy", sa.Numeric(12, 0), nullable=True,
                comment="更新料 in JPY. Null until invoice is generated.",
            ),
            sa.Column(
                "status", sa.String(20), nullable=False, server_default="pending",
                comment="pending | invoiced | confirmed | renewed | expired",
            ),
            sa.Column(
                "invoice_id", sa.String(64), nullable=True,
                comment="JpInvoice.id once generated. Null until invoiced.",
            ),
            sa.Column(
                "notified_at", sa.DateTime(timezone=True), nullable=True,
                comment="When tenant notification was enqueued.",
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column(
                "updated_at", sa.DateTime(), nullable=False,
                server_default=sa.func.now(), onupdate=sa.func.now(),
            ),
        )

        op.create_index(
            "ix_jp_contract_renewals_contract_status",
            "jp_contract_renewals",
            ["contract_id", "status"],
        )
        op.create_index(
            "ix_jp_contract_renewals_org_status",
            "jp_contract_renewals",
            ["org_id", "status"],
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if insp.has_table("jp_contract_renewals"):
        op.drop_index("ix_jp_contract_renewals_org_status", table_name="jp_contract_renewals")
        op.drop_index("ix_jp_contract_renewals_contract_status", table_name="jp_contract_renewals")
        op.drop_table("jp_contract_renewals")
