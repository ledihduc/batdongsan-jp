"""P08 stay facade collaboration records.

Revision ID: 0124_stay_v2
Revises: 0123_sale_crm_v2
"""

import sqlalchemy as sa
from alembic import op

revision = "0124_stay_v2"
down_revision = "0123_sale_crm_v2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "stay_support_cases",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("contract_id", sa.Integer(), sa.ForeignKey("contracts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("opened_by_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("opened_by_role", sa.String(20), nullable=False),
        sa.Column("assignee_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("category", sa.String(40), nullable=False),
        sa.Column("priority", sa.String(16), nullable=False, server_default="NORMAL"),
        sa.Column("status", sa.String(24), nullable=False, server_default="OPEN"),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("evidence_urls", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("sla_due_at", sa.DateTime(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    for name, cols in (
        ("ix_stay_support_cases_contract_id", ["contract_id"]),
        ("ix_stay_support_cases_opened_by_user_id", ["opened_by_user_id"]),
        ("ix_stay_support_cases_assignee_user_id", ["assignee_user_id"]),
        ("ix_stay_support_cases_status", ["status"]),
        ("ix_stay_support_cases_sla_due_at", ["sla_due_at"]),
        ("ix_stay_support_contract_status", ["contract_id", "status"]),
        ("ix_stay_support_assignee_status", ["assignee_user_id", "status"]),
    ): op.create_index(name, "stay_support_cases", cols)
    op.create_table(
        "stay_support_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("case_id", sa.Integer(), sa.ForeignKey("stay_support_cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("actor_role", sa.String(20), nullable=False),
        sa.Column("event_type", sa.String(40), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("evidence_urls", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("payload", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_stay_support_events_case_id", "stay_support_events", ["case_id"])
    op.create_index("ix_stay_support_events_created_at", "stay_support_events", ["created_at"])
    op.create_index("ix_stay_support_event_case_created", "stay_support_events", ["case_id", "created_at"])
    op.create_table(
        "stay_change_requests",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("contract_id", sa.Integer(), sa.ForeignKey("contracts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("requester_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("requester_role", sa.String(20), nullable=False),
        sa.Column("request_type", sa.String(20), nullable=False),
        sa.Column("proposed_end_date", sa.String(20), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="PENDING"),
        sa.Column("reviewed_by_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("review_note", sa.Text(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_stay_change_requests_contract_id", "stay_change_requests", ["contract_id"])
    op.create_index("ix_stay_change_requests_status", "stay_change_requests", ["status"])
    op.create_index("ix_stay_change_contract_status", "stay_change_requests", ["contract_id", "status"])


def downgrade() -> None:
    op.drop_table("stay_change_requests")
    op.drop_table("stay_support_events")
    op.drop_table("stay_support_cases")
