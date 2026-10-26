"""create operator_business_profiles table

Revision ID: 0023_create_operator_business_profiles
Revises: 0022_create_delegation_approvals
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-49/50b: GPKD business operator KYC schema
  - AC-65: legal representative change audit (previous_legal_rep_user_id + legal_rep_changed_at)
  - AS-06: 1 pháp nhân = 1 user (UNIQUE user_id constraint)

Note: This table is referenced by users.business_operator_profile_id (added in migration 0027).
The FK on users is added in 0027 to avoid forward-reference issues.
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0023_create_operator_business_profiles"
down_revision = "0022_create_delegation_approvals"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "operator_business_profiles",
        sa.Column("id", sa.Integer, primary_key=True),
        # 1:1 with legal-rep user (AS-06: 1 pháp nhân = 1 user)
        sa.Column(
            "user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
            unique=True,
            index=True,
        ),
        # Business identity
        sa.Column("business_name", sa.String(300), nullable=False),
        sa.Column("business_registration_number", sa.String(50), nullable=False),
        # GPKD document — encrypted-at-rest path
        sa.Column("gpkd_document_path", sa.String(500), nullable=False),
        # JSON array of ngành codes (validated at admin review — Q6.3 legal confirm)
        sa.Column("gpkd_industry_codes_json", sa.JSON, nullable=True),
        sa.Column("gpkd_issued_at", sa.DateTime, nullable=False),
        # Drives AC-50/AC-61 expiry cron
        sa.Column("gpkd_expires_at", sa.DateTime, nullable=True),
        # Legal representative identity
        sa.Column("legal_representative_name", sa.String(300), nullable=False),
        # Bcrypt hash — mirrors existing CCCD pattern in HostProfile (compare-only)
        sa.Column(
            "legal_representative_cccd_number_hash", sa.String(200), nullable=True
        ),
        # Encrypted-at-rest file paths
        sa.Column(
            "legal_representative_cccd_front_path", sa.String(500), nullable=True
        ),
        sa.Column(
            "legal_representative_cccd_back_path", sa.String(500), nullable=True
        ),
        sa.Column("legal_representative_phone", sa.String(50), nullable=False),
        # Verification state machine: pending | verified | rejected | revoked
        sa.Column(
            "verification_status",
            sa.String(20),
            nullable=False,
            server_default="pending",
            index=True,
        ),
        sa.Column("verified_at", sa.DateTime, nullable=True),
        sa.Column(
            "verified_by_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        # AC-65: legal rep change audit (most-recent predecessor)
        sa.Column(
            "previous_legal_rep_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("legal_rep_changed_at", sa.DateTime, nullable=True),
        sa.Column(
            "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
    )

    op.create_index(
        "ix_op_biz_user_id", "operator_business_profiles", ["user_id"], unique=True
    )
    op.create_index(
        "ix_op_biz_verification_status",
        "operator_business_profiles",
        ["verification_status"],
    )
    op.create_index(
        "ix_op_biz_gpkd_expires_at",
        "operator_business_profiles",
        ["gpkd_expires_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_op_biz_gpkd_expires_at", table_name="operator_business_profiles")
    op.drop_index(
        "ix_op_biz_verification_status", table_name="operator_business_profiles"
    )
    op.drop_index("ix_op_biz_user_id", table_name="operator_business_profiles")
    op.drop_table("operator_business_profiles")
