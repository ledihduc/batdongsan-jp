"""create audit_logs table

Revision ID: 0019_create_audit_logs
Revises: 0018_source_id_not_null_v2
Create Date: 2026-06-28

Phase 09 — TT200 export audit trail.
Tracks every export attempt (success + failure) per host for legal compliance.
"""

from alembic import op
import sqlalchemy as sa

revision = "0019_create_audit_logs"
down_revision = "0018_source_id_not_null_v2"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "audit_logs",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column(
            "host_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        # action: e.g. "export_tt200"
        sa.Column("action", sa.String(50), nullable=False),
        # period: "YYYY-MM" for export actions; NULL for others
        sa.Column("period", sa.String(7), nullable=True),
        sa.Column("success", sa.Boolean, nullable=False),
        # ip: up to 45 chars to accommodate IPv6
        sa.Column("ip", sa.String(45), nullable=True),
        sa.Column("user_agent", sa.String(500), nullable=True),
        # extra: arbitrary JSON blob for future extensibility
        sa.Column("extra", sa.Text, nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime,
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    # Composite index for dashboard query: all exports by host sorted by date
    op.create_index(
        "ix_audit_logs_host_action_created",
        "audit_logs",
        ["host_id", "action", "created_at"],
    )


def downgrade():
    op.drop_index("ix_audit_logs_host_action_created", table_name="audit_logs")
    op.drop_table("audit_logs")
