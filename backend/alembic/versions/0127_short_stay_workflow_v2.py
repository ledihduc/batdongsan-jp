"""P11-P13 shared short-stay workflow events.

Revision ID: 0127_short_stay_workflow_v2
Revises: 0126_room_type_inventory_v2
"""
import sqlalchemy as sa
from alembic import op

revision = "0127_short_stay_workflow_v2"
down_revision = "0126_room_type_inventory_v2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("room_type_booking_requests", sa.Column("workflow_data", sa.JSON(), nullable=False, server_default="{}"))
    op.add_column("room_type_booking_requests", sa.Column("cancellation_reason", sa.Text(), nullable=True))
    op.create_table("short_stay_workflow_events", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("request_id", sa.Integer(), sa.ForeignKey("room_type_booking_requests.id", ondelete="CASCADE"), nullable=False), sa.Column("actor_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("actor_role", sa.String(20), nullable=False), sa.Column("event_type", sa.String(40), nullable=False), sa.Column("from_status", sa.String(30), nullable=False), sa.Column("to_status", sa.String(30), nullable=False), sa.Column("payload", sa.JSON(), nullable=False, server_default="{}"), sa.Column("created_at", sa.DateTime(), nullable=False))
    op.create_index("ix_short_stay_workflow_events_request_id", "short_stay_workflow_events", ["request_id"]); op.create_index("ix_short_stay_workflow_events_created_at", "short_stay_workflow_events", ["created_at"]); op.create_index("ix_short_workflow_request_created", "short_stay_workflow_events", ["request_id", "created_at"])


def downgrade() -> None:
    op.drop_table("short_stay_workflow_events"); op.drop_column("room_type_booking_requests", "cancellation_reason"); op.drop_column("room_type_booking_requests", "workflow_data")
