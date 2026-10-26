"""Create jp_deposit_settlements table — 敷金精算 deposit settlement.

Tracks the itemized settlement of a tenant's security deposit at move-out.

Status state machine:
  draft → tenant_review → accepted | disputed → refunded

Idempotent: checks has_table() before create.
Has downgrade(): drops table.

Revision ID: 0157_deposit_settlements
Revises: 0156_contract_renewals
"""

from alembic import op
import sqlalchemy as sa

revision = "0157_deposit_settlements"
down_revision = "0156_contract_renewals"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_deposit_settlements"):
        op.create_table(
            "jp_deposit_settlements",
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
                "status", sa.String(20), nullable=False, server_default="draft",
                comment="draft | tenant_review | accepted | disputed | refunded",
            ),
            sa.Column(
                "gross_shikikin_jpy", sa.Numeric(12, 0), nullable=False,
                comment="Original security deposit amount in JPY.",
            ),
            # Deductions stored as JSON array: [{label, amount_jpy, reason}]
            sa.Column(
                "deductions_json", sa.JSON(), nullable=True,
                comment="List of owner deductions: [{label, amount_jpy, reason}].",
            ),
            sa.Column(
                "refund_jpy", sa.Numeric(12, 0), nullable=True,
                comment="Net refund to tenant = gross - sum(deductions). Null until computed.",
            ),
            sa.Column(
                "refund_invoice_id", sa.String(64), nullable=True,
                comment="JpInvoice.id for the refund invoice. Null until generated.",
            ),
            sa.Column(
                "owner_signed_at", sa.DateTime(timezone=True), nullable=True,
                comment="When owner confirmed the settlement.",
            ),
            sa.Column(
                "tenant_signed_at", sa.DateTime(timezone=True), nullable=True,
                comment="When tenant accepted the settlement.",
            ),
            sa.Column(
                "payout_at", sa.DateTime(timezone=True), nullable=True,
                comment="When refund payout was processed.",
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column(
                "updated_at", sa.DateTime(), nullable=False,
                server_default=sa.func.now(), onupdate=sa.func.now(),
            ),
        )

        op.create_index(
            "ix_jp_deposit_settlements_contract",
            "jp_deposit_settlements",
            ["contract_id"],
        )
        op.create_index(
            "ix_jp_deposit_settlements_org_status",
            "jp_deposit_settlements",
            ["org_id", "status"],
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if insp.has_table("jp_deposit_settlements"):
        op.drop_index("ix_jp_deposit_settlements_org_status", table_name="jp_deposit_settlements")
        op.drop_index("ix_jp_deposit_settlements_contract", table_name="jp_deposit_settlements")
        op.drop_table("jp_deposit_settlements")
