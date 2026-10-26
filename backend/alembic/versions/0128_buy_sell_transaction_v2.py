"""P14 separate buy/sell transaction workflow.

Revision ID: 0128_buy_sell_transaction_v2
Revises: 0127_short_stay_workflow_v2
"""
import sqlalchemy as sa
from alembic import op

revision = "0128_buy_sell_transaction_v2"
down_revision = "0127_short_stay_workflow_v2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table("sale_transactions", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("deal_id", sa.Integer(), sa.ForeignKey("deals.id", ondelete="RESTRICT"), nullable=False), sa.Column("buyer_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("seller_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("sale_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")), sa.Column("stage", sa.String(30), nullable=False, server_default="INTERESTED"), sa.Column("offer_amount", sa.Float()), sa.Column("agreed_amount", sa.Float()), sa.Column("lost_reason_code", sa.String(50)), sa.Column("lost_note", sa.Text()), sa.Column("created_at", sa.DateTime(), nullable=False), sa.Column("updated_at", sa.DateTime(), nullable=False), sa.UniqueConstraint("deal_id", name="uq_sale_transaction_deal"))
    for c in ("buyer_user_id", "seller_user_id", "sale_user_id", "stage"): op.create_index(f"ix_sale_transactions_{c}", "sale_transactions", [c])
    op.create_table("sale_transaction_events", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("transaction_id", sa.Integer(), sa.ForeignKey("sale_transactions.id", ondelete="CASCADE"), nullable=False), sa.Column("actor_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("actor_role", sa.String(20), nullable=False), sa.Column("from_stage", sa.String(30), nullable=False), sa.Column("to_stage", sa.String(30), nullable=False), sa.Column("note", sa.Text()), sa.Column("created_at", sa.DateTime(), nullable=False))
    op.create_index("ix_sale_transaction_events_transaction_id", "sale_transaction_events", ["transaction_id"]); op.create_index("ix_sale_transaction_events_created_at", "sale_transaction_events", ["created_at"]); op.create_index("ix_sale_transaction_event_tx_created", "sale_transaction_events", ["transaction_id", "created_at"])
    op.create_table("sale_transaction_documents", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("transaction_id", sa.Integer(), sa.ForeignKey("sale_transactions.id", ondelete="CASCADE"), nullable=False), sa.Column("document_type", sa.String(40), nullable=False), sa.Column("file_url", sa.String(500), nullable=False), sa.Column("uploaded_by_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("created_at", sa.DateTime(), nullable=False))
    op.create_index("ix_sale_transaction_documents_transaction_id", "sale_transaction_documents", ["transaction_id"])


def downgrade() -> None:
    op.drop_table("sale_transaction_documents"); op.drop_table("sale_transaction_events"); op.drop_table("sale_transactions")
