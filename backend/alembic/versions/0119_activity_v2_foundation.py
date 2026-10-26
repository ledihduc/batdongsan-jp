"""Activity v2 foundation: Sale applications, policy versions and audit.

Revision ID: 0119_activity_v2_foundation
Revises: 0118_fix_journey_lists
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0119_activity_v2_foundation"
down_revision = "0118_fix_journey_lists"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sale_applications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("applicant_user_id", sa.Integer(), nullable=False),
        sa.Column("full_name", sa.String(length=200), nullable=False),
        sa.Column("email", sa.String(length=200), nullable=False, server_default=""),
        sa.Column("phone", sa.String(length=50), nullable=False, server_default=""),
        sa.Column("bio", sa.Text(), nullable=True),
        sa.Column("service_areas", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("evidence_urls", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="SUBMITTED"),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("submitted_at", sa.DateTime(), nullable=False),
        sa.Column("reviewed_at", sa.DateTime(), nullable=True),
        sa.Column("reviewed_by", sa.Integer(), nullable=True),
        sa.Column("review_note", sa.Text(), nullable=True),
        sa.Column("rejection_code", sa.String(length=80), nullable=True),
        sa.Column("withdrawn_at", sa.DateTime(), nullable=True),
        sa.Column("approved_sale_profile_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["applicant_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["approved_sale_profile_id"], ["sale_profiles.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_sale_applications_applicant_user_id", "sale_applications", ["applicant_user_id"])
    op.create_index("ix_sale_applications_status", "sale_applications", ["status"])
    op.create_index("ix_sale_applications_reviewed_by", "sale_applications", ["reviewed_by"])

    op.create_table(
        "activity_policy_versions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("policy_version", sa.Integer(), nullable=False),
        sa.Column("short_stay_primary_deposit_bps", sa.Integer(), nullable=False, server_default="1000"),
        sa.Column("long_term_platform_deposit_bps", sa.Integer(), nullable=False, server_default="5000"),
        sa.Column("effective_at", sa.DateTime(), nullable=False),
        sa.Column("reason", sa.String(length=500), nullable=False),
        sa.Column("created_by", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "short_stay_primary_deposit_bps >= 0 AND short_stay_primary_deposit_bps <= 10000",
            name="ck_activity_policy_short_deposit_bps",
        ),
        sa.CheckConstraint(
            "long_term_platform_deposit_bps >= 0 AND long_term_platform_deposit_bps <= 10000",
            name="ck_activity_policy_long_deposit_bps",
        ),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("policy_version", name="uq_activity_policy_version"),
    )
    op.create_index("ix_activity_policy_versions_effective_at", "activity_policy_versions", ["effective_at"])
    op.create_index("ix_activity_policy_versions_created_by", "activity_policy_versions", ["created_by"])

    op.create_table(
        "activity_audit_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("actor_user_id", sa.Integer(), nullable=False),
        sa.Column("action", sa.String(length=80), nullable=False),
        sa.Column("idempotency_key", sa.String(length=128), nullable=False),
        sa.Column("target_type", sa.String(length=80), nullable=False),
        sa.Column("target_id", sa.Integer(), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.UniqueConstraint(
            "actor_user_id", "action", "idempotency_key",
            name="uq_activity_audit_actor_action_key",
        ),
    )
    op.create_index("ix_activity_audit_events_actor_user_id", "activity_audit_events", ["actor_user_id"])
    op.create_index("ix_activity_audit_events_action", "activity_audit_events", ["action"])
    op.create_index("ix_activity_audit_events_target_id", "activity_audit_events", ["target_id"])
    op.create_index(
        "ix_activity_audit_target_created",
        "activity_audit_events",
        ["target_type", "target_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_activity_audit_target_created", table_name="activity_audit_events")
    op.drop_index("ix_activity_audit_events_target_id", table_name="activity_audit_events")
    op.drop_index("ix_activity_audit_events_action", table_name="activity_audit_events")
    op.drop_index("ix_activity_audit_events_actor_user_id", table_name="activity_audit_events")
    op.drop_table("activity_audit_events")
    op.drop_index("ix_activity_policy_versions_created_by", table_name="activity_policy_versions")
    op.drop_index("ix_activity_policy_versions_effective_at", table_name="activity_policy_versions")
    op.drop_table("activity_policy_versions")
    op.drop_index("ix_sale_applications_reviewed_by", table_name="sale_applications")
    op.drop_index("ix_sale_applications_status", table_name="sale_applications")
    op.drop_index("ix_sale_applications_applicant_user_id", table_name="sale_applications")
    op.drop_table("sale_applications")
