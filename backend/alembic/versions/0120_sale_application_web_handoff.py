"""Secure one-time app-to-web Sale application handoff.

Revision ID: 0120_sale_application_web_handoff
Revises: 0119_activity_v2_foundation
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0120_sale_application_web_handoff"
down_revision = "0119_activity_v2_foundation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sale_application_web_sessions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("ticket_hash", sa.String(length=64), nullable=False),
        sa.Column("web_session_hash", sa.String(length=64), nullable=True),
        sa.Column("ticket_expires_at", sa.DateTime(), nullable=False),
        sa.Column("web_session_expires_at", sa.DateTime(), nullable=True),
        sa.Column("exchanged_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("ticket_hash", name="uq_sale_application_web_ticket_hash"),
        sa.UniqueConstraint("web_session_hash", name="uq_sale_application_web_session_hash"),
    )
    op.create_index("ix_sale_application_web_sessions_user_id", "sale_application_web_sessions", ["user_id"])
    op.create_index("ix_sale_application_web_sessions_ticket_hash", "sale_application_web_sessions", ["ticket_hash"])
    op.create_index("ix_sale_application_web_sessions_web_session_hash", "sale_application_web_sessions", ["web_session_hash"])
    op.create_index("ix_sale_application_web_sessions_ticket_expires_at", "sale_application_web_sessions", ["ticket_expires_at"])
    op.create_index("ix_sale_application_web_sessions_web_session_expires_at", "sale_application_web_sessions", ["web_session_expires_at"])


def downgrade() -> None:
    op.drop_index("ix_sale_application_web_sessions_web_session_expires_at", table_name="sale_application_web_sessions")
    op.drop_index("ix_sale_application_web_sessions_ticket_expires_at", table_name="sale_application_web_sessions")
    op.drop_index("ix_sale_application_web_sessions_web_session_hash", table_name="sale_application_web_sessions")
    op.drop_index("ix_sale_application_web_sessions_ticket_hash", table_name="sale_application_web_sessions")
    op.drop_index("ix_sale_application_web_sessions_user_id", table_name="sale_application_web_sessions")
    op.drop_table("sale_application_web_sessions")
