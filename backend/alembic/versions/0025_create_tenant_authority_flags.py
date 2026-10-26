"""create tenant_authority_flags table

Revision ID: 0025_create_tenant_authority_flags
Revises: 0024_create_owner_death_certificates
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-63: tenant can report unauthorized operator activity
  - Admin 48h SLA to review reports
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0025_create_tenant_authority_flags"
down_revision = "0024_create_owner_death_certificates"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tenant_authority_flags",
        sa.Column("id", sa.String(36), primary_key=True),
        # Reporting tenant
        sa.Column(
            "tenant_id",
            sa.Integer,
            sa.ForeignKey("tenants.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
        # Reported operator user
        sa.Column(
            "reported_operator_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
        # Correlated delegation (if system can identify it)
        sa.Column(
            "delegation_id",
            sa.String(36),
            sa.ForeignKey("delegations.id", ondelete="SET NULL"),
            nullable=True,
            index=True,
        ),
        sa.Column("report_reason", sa.Text, nullable=False),
        # Admin review: pending | valid | invalid
        sa.Column(
            "status",
            sa.String(20),
            nullable=False,
            server_default="pending",
            index=True,
        ),
        sa.Column("reviewed_at", sa.DateTime, nullable=True),
        sa.Column(
            "reviewed_by_admin_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
    )

    op.create_index(
        "ix_tenant_auth_tenant_id", "tenant_authority_flags", ["tenant_id"]
    )
    op.create_index(
        "ix_tenant_auth_operator", "tenant_authority_flags", ["reported_operator_user_id"]
    )
    op.create_index(
        "ix_tenant_auth_delegation_id", "tenant_authority_flags", ["delegation_id"]
    )
    op.create_index("ix_tenant_auth_status", "tenant_authority_flags", ["status"])
    op.create_index("ix_tenant_auth_created_at", "tenant_authority_flags", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_tenant_auth_created_at", table_name="tenant_authority_flags")
    op.drop_index("ix_tenant_auth_status", table_name="tenant_authority_flags")
    op.drop_index("ix_tenant_auth_delegation_id", table_name="tenant_authority_flags")
    op.drop_index("ix_tenant_auth_operator", table_name="tenant_authority_flags")
    op.drop_index("ix_tenant_auth_tenant_id", table_name="tenant_authority_flags")
    op.drop_table("tenant_authority_flags")
