"""Create jp_invoice_lines table — multi-line JP invoice with 消費税 handling.

Line types reflect JP rental money breakdown:
  rent | management | shikikin | reikin | koushinryo | brokerage | hoshou | other

Tax treatment per JP residential law:
  - 家賃 (rent) → exempt (非課税)
  - 共益費 (management) → taxable 10%
  - 仲介手数料 (brokerage) → taxable 10%
  - 敷金/礼金/更新料/保証 → exempt (非課税, deposit/fee nature)

Idempotent: checks has_table() before create.
Has downgrade(): drops table.

Revision ID: 0150_jp_invoice_lines
Revises: 0149_org_provider_configs
"""

from alembic import op
import sqlalchemy as sa

revision = "0150_jp_invoice_lines"
down_revision = "0149_org_provider_configs"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_invoice_lines"):
        op.create_table(
            "jp_invoice_lines",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "org_id", sa.String(64), nullable=False, index=True,
                comment="Broker org tenant ID. MUST be filtered in every list query.",
            ),
            sa.Column(
                "region", sa.String(3), nullable=False, server_default="jp",
                comment="Defense-in-depth region tag. Always 'jp'.",
            ),
            # Parent invoice — string UUID to avoid cross-domain FK
            # No inline index=True — explicit op.create_index below owns the
            # ix_jp_invoice_lines_invoice_id index.
            sa.Column(
                "invoice_id", sa.String(64), nullable=False,
                comment="Invoice UUID. No FK — cross-domain boundary.",
            ),
            # Line item classification
            sa.Column(
                "line_type", sa.String(20), nullable=False,
                comment=(
                    "rent | management | shikikin | reikin | koushinryo "
                    "| brokerage | hoshou | other"
                ),
            ),
            sa.Column(
                "amount_jpy", sa.Numeric(12, 0), nullable=False,
                comment="Pre-tax amount in JPY.",
            ),
            sa.Column(
                "tax_treatment", sa.String(20), nullable=False,
                comment="taxable | exempt | zero_rated",
            ),
            sa.Column(
                "tax_amount_jpy", sa.Numeric(12, 0), nullable=False, server_default="0",
                comment="Consumption tax amount in JPY. 0 for exempt/zero_rated.",
            ),
            sa.Column(
                "description", sa.String(200), nullable=True,
                comment="Human-readable label for this line (e.g. '家賃 2025年1月分').",
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        )

        op.create_index(
            "ix_jp_invoice_lines_invoice_id",
            "jp_invoice_lines",
            ["invoice_id"],
        )


def downgrade() -> None:
    op.drop_table("jp_invoice_lines")
