"""create bank_account_reveal_logs table

Revision ID: 0026_create_bank_account_reveal_logs
Revises: 0025_create_tenant_authority_flags
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-53: PDPL audit trail for bank account number reveals by operators
  - Mirrors CCCDAccessLog pattern for consistent PDPL compliance

Bank account masking (AC-53) is a read-layer concern enforced in phase-07.
This table audits every reveal event (when operator views full account number).
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0026_create_bank_account_reveal_logs"
down_revision = "0025_create_tenant_authority_flags"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "bank_account_reveal_logs",
        sa.Column("id", sa.String(36), primary_key=True),
        # Account owner
        sa.Column(
            "owner_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
        # Who accessed (operator)
        sa.Column(
            "operator_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
        # The active delegation that authorized this access
        sa.Column(
            "delegation_id",
            sa.String(36),
            sa.ForeignKey("delegations.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "revealed_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
        # One-time owner consent reference (64-char token)
        sa.Column("consent_token", sa.String(64), nullable=False),
        # IPv6 max 45 chars — same as CCCDAccessLog pattern
        sa.Column("ip_address", sa.String(50), nullable=False),
    )

    op.create_index(
        "ix_bank_reveal_owner_user_id", "bank_account_reveal_logs", ["owner_user_id"]
    )
    op.create_index(
        "ix_bank_reveal_operator_user_id",
        "bank_account_reveal_logs",
        ["operator_user_id"],
    )
    op.create_index(
        "ix_bank_reveal_delegation_id", "bank_account_reveal_logs", ["delegation_id"]
    )
    op.create_index(
        "ix_bank_reveal_revealed_at", "bank_account_reveal_logs", ["revealed_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_bank_reveal_revealed_at", table_name="bank_account_reveal_logs")
    op.drop_index("ix_bank_reveal_delegation_id", table_name="bank_account_reveal_logs")
    op.drop_index(
        "ix_bank_reveal_operator_user_id", table_name="bank_account_reveal_logs"
    )
    op.drop_index("ix_bank_reveal_owner_user_id", table_name="bank_account_reveal_logs")
    op.drop_table("bank_account_reveal_logs")
