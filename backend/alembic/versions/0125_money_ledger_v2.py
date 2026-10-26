"""P09 record-only money ledger.

Revision ID: 0125_money_ledger_v2
Revises: 0124_stay_v2
"""
import sqlalchemy as sa
from alembic import op

revision = "0125_money_ledger_v2"
down_revision = "0124_stay_v2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table("platform_payments",
        sa.Column("id", sa.Integer(), primary_key=True), sa.Column("source_type", sa.String(30), nullable=False), sa.Column("source_id", sa.Integer(), nullable=False),
        sa.Column("payer_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")), sa.Column("amount", sa.Float(), nullable=False), sa.Column("currency", sa.String(3), nullable=False, server_default="VND"),
        sa.Column("status", sa.String(20), nullable=False, server_default="RECORDED"), sa.Column("method", sa.String(30), nullable=False, server_default="MANUAL_PROOF"), sa.Column("external_reference", sa.String(120), nullable=False),
        sa.Column("evidence_urls", sa.JSON(), nullable=False, server_default="[]"), sa.Column("recorded_by_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("paid_at", sa.DateTime(), nullable=False), sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("source_type", "source_id", "external_reference", name="uq_platform_payment_source_ref"), sa.CheckConstraint("amount >= 0", name="ck_platform_payment_amount_nonnegative"))
    for c in ("source_type", "source_id", "status"): op.create_index(f"ix_platform_payments_{c}", "platform_payments", [c])
    op.create_table("payment_allocations", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("payment_id", sa.Integer(), sa.ForeignKey("platform_payments.id", ondelete="CASCADE"), nullable=False), sa.Column("allocation_type", sa.String(30), nullable=False), sa.Column("beneficiary_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")), sa.Column("amount", sa.Float(), nullable=False), sa.Column("rule_version", sa.String(50)), sa.Column("created_at", sa.DateTime(), nullable=False), sa.UniqueConstraint("payment_id", "allocation_type", "beneficiary_user_id", name="uq_payment_allocation_bucket"), sa.CheckConstraint("amount >= 0", name="ck_payment_allocation_nonnegative"))
    op.create_index("ix_payment_allocations_payment_id", "payment_allocations", ["payment_id"])
    op.create_table("owner_settlements", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("owner_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("period", sa.String(7), nullable=False), sa.Column("gross_amount", sa.Float(), nullable=False), sa.Column("net_amount", sa.Float(), nullable=False), sa.Column("status", sa.String(20), nullable=False, server_default="PENDING_MANUAL"), sa.Column("snapshot", sa.JSON(), nullable=False, server_default="{}"), sa.Column("created_at", sa.DateTime(), nullable=False), sa.Column("settled_at", sa.DateTime()))
    for c in ("owner_user_id", "period", "status"): op.create_index(f"ix_owner_settlements_{c}", "owner_settlements", [c])
    op.create_table("sale_commissions", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("sale_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("source_type", sa.String(30), nullable=False), sa.Column("source_id", sa.Integer(), nullable=False), sa.Column("amount", sa.Float(), nullable=False), sa.Column("rule_snapshot", sa.JSON(), nullable=False, server_default="{}"), sa.Column("status", sa.String(24), nullable=False, server_default="DEFERRED_POLICY"), sa.Column("recognized_at", sa.DateTime(), nullable=False), sa.UniqueConstraint("source_type", "source_id", "sale_user_id", name="uq_sale_commission_source"))
    op.create_index("ix_sale_commissions_sale_user_id", "sale_commissions", ["sale_user_id"]); op.create_index("ix_sale_commissions_status", "sale_commissions", ["status"])
    op.create_table("commission_payouts", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("commission_id", sa.Integer(), sa.ForeignKey("sale_commissions.id", ondelete="RESTRICT"), nullable=False), sa.Column("amount", sa.Float(), nullable=False), sa.Column("status", sa.String(24), nullable=False, server_default="NOT_SCHEDULED"), sa.Column("external_reference", sa.String(120)), sa.Column("created_at", sa.DateTime(), nullable=False), sa.Column("paid_at", sa.DateTime()))
    op.create_index("ix_commission_payouts_commission_id", "commission_payouts", ["commission_id"])
    op.create_table("money_refunds", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("payment_id", sa.Integer(), sa.ForeignKey("platform_payments.id", ondelete="RESTRICT"), nullable=False), sa.Column("amount", sa.Float(), nullable=False), sa.Column("reason_code", sa.String(40), nullable=False), sa.Column("note", sa.Text()), sa.Column("status", sa.String(24), nullable=False, server_default="RECORDED"), sa.Column("recorded_by_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("created_at", sa.DateTime(), nullable=False), sa.CheckConstraint("amount >= 0", name="ck_money_refund_nonnegative"))
    op.create_index("ix_money_refunds_payment_id", "money_refunds", ["payment_id"])


def downgrade() -> None:
    for table in ("money_refunds", "commission_payouts", "sale_commissions", "owner_settlements", "payment_allocations", "platform_payments"):
        op.drop_table(table)
