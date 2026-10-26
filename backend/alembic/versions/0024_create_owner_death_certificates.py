"""create owner_death_certificates table

Revision ID: 0024_create_owner_death_certificates
Revises: 0023_create_operator_business_profiles
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-58: admin verification of death certificate (24h SLA — US-A7)
  - AC-58b: heir/executor onboarding
  - AC-58d: executor can approve delegation_approvals on owner's behalf
  - US-A6: admin panel for death cert review
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0024_create_owner_death_certificates"
down_revision = "0023_create_operator_business_profiles"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "owner_death_certificates",
        sa.Column("id", sa.String(36), primary_key=True),
        # UNIQUE: one active death cert per owner (prevents duplicate submissions)
        sa.Column(
            "owner_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
            unique=True,
            index=True,
        ),
        # Document paths — encrypted-at-rest volume, mediated by sensitive_file_service
        sa.Column("death_certificate_path", sa.String(500), nullable=False),
        sa.Column("notarized_poa_path", sa.String(500), nullable=True),
        # Who submitted (heir or admin-on-behalf)
        sa.Column(
            "submitted_by_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        # Admin verification: pending | verified | rejected
        sa.Column(
            "verification_status",
            sa.String(20),
            nullable=False,
            server_default="pending",
            index=True,
        ),
        sa.Column("verified_at", sa.DateTime, nullable=True),
        sa.Column(
            "verified_by_admin_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        # Executor who takes over delegation approval rights (AC-58b/d)
        sa.Column(
            "executor_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("executor_onboarded_at", sa.DateTime, nullable=True),
        sa.Column(
            "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
    )

    op.create_index(
        "ix_owner_death_owner_user_id",
        "owner_death_certificates",
        ["owner_user_id"],
        unique=True,
    )
    op.create_index(
        "ix_owner_death_verification_status",
        "owner_death_certificates",
        ["verification_status"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_owner_death_verification_status", table_name="owner_death_certificates"
    )
    op.drop_index(
        "ix_owner_death_owner_user_id", table_name="owner_death_certificates"
    )
    op.drop_table("owner_death_certificates")
