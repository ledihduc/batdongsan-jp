"""add_host_profile_audit_log

Create host_profiles, change_logs, cccd_access_logs tables.

Revision ID: 0004_add_host_profile_audit_log
Revises: 0003_rename_booking
Create Date: 2026-06-22
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "0004_add_host_profile_audit_log"
down_revision: Union[str, Sequence[str], None] = "0003_rename_booking"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── host_profiles ──────────────────────────────────────────────────────────
    op.create_table(
        "host_profiles",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("verified", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("cccd_front_path", sa.String(length=500), nullable=True),
        sa.Column("cccd_back_path", sa.String(length=500), nullable=True),
        sa.Column("cccd_number_hash", sa.String(length=200), nullable=True),
        sa.Column("bank_account_number", sa.String(length=50), nullable=True),
        sa.Column("bank_name", sa.String(length=100), nullable=True),
        sa.Column("bank_account_holder", sa.String(length=200), nullable=True),
        sa.Column("tax_id", sa.String(length=50), nullable=True),
        sa.Column("avg_response_hours", sa.Float(), nullable=True),
        sa.Column("rating", sa.Float(), nullable=True),
        sa.Column("payout_schedule", sa.String(length=20), nullable=True, server_default="monthly"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", name="uq_host_profiles_user_id"),
    )
    op.create_index(
        op.f("ix_host_profiles_user_id"), "host_profiles", ["user_id"], unique=True
    )

    # ── change_logs ────────────────────────────────────────────────────────────
    op.create_table(
        "change_logs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("entity_type", sa.String(length=50), nullable=False),
        sa.Column("entity_id", sa.Integer(), nullable=False),
        sa.Column("actor_id", sa.Integer(), nullable=True),
        sa.Column("action", sa.String(length=30), nullable=False),
        sa.Column("before_json", sa.Text(), nullable=True),
        sa.Column("after_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["actor_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_change_logs_entity_type"), "change_logs", ["entity_type"], unique=False
    )
    op.create_index(
        op.f("ix_change_logs_entity_id"), "change_logs", ["entity_id"], unique=False
    )
    op.create_index(
        op.f("ix_change_logs_created_at"), "change_logs", ["created_at"], unique=False
    )

    # ── cccd_access_logs ───────────────────────────────────────────────────────
    op.create_table(
        "cccd_access_logs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("file_path", sa.String(length=500), nullable=False),
        sa.Column("action", sa.String(length=20), nullable=False),
        sa.Column("accessed_at", sa.DateTime(), nullable=False),
        sa.Column("ip_address", sa.String(length=50), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_cccd_access_logs_user_id"), "cccd_access_logs", ["user_id"], unique=False
    )
    op.create_index(
        op.f("ix_cccd_access_logs_accessed_at"),
        "cccd_access_logs",
        ["accessed_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_cccd_access_logs_accessed_at"), table_name="cccd_access_logs")
    op.drop_index(op.f("ix_cccd_access_logs_user_id"), table_name="cccd_access_logs")
    op.drop_table("cccd_access_logs")

    op.drop_index(op.f("ix_change_logs_created_at"), table_name="change_logs")
    op.drop_index(op.f("ix_change_logs_entity_id"), table_name="change_logs")
    op.drop_index(op.f("ix_change_logs_entity_type"), table_name="change_logs")
    op.drop_table("change_logs")

    op.drop_index(op.f("ix_host_profiles_user_id"), table_name="host_profiles")
    op.drop_table("host_profiles")
