"""create delegation_approvals table

Revision ID: 0022_create_delegation_approvals
Revises: 0021_create_delegations_and_invitations
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-29b: requires_biometric flag (amount >= 50M VND)
  - AC-30: SLA class + expires_at enforcement
  - AC-30b: escalation_state ladder (push_only → push_email → push_email_sms → escalated_admin)
  - AC-31: delivery_channels_used_json
  - AC-43b: lockdown_fraud_termination flag
  - AC-55: kb04_fast_track_6h SLA class
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0022_create_delegation_approvals"
down_revision = "0021_create_delegations_and_invitations"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "delegation_approvals",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "delegation_id",
            sa.String(36),
            sa.ForeignKey("delegations.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
        # Snapshot of operator_id at request time (denormalized — in case delegation changes)
        sa.Column(
            "requester_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        # Denormalized for fast owner inbox query — avoids join through delegations
        sa.Column(
            "owner_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
            index=True,
        ),
        # Action type
        # contract_create | contract_terminate | invoice_high_amount | expense_high_amount
        # rent_change | refund_high_amount | kb04_fast_track | kb04_pre_file
        # fraud_termination | threshold_change
        sa.Column("action_type", sa.String(40), nullable=False),
        # Entity the action targets (NULL for threshold_change)
        sa.Column("entity_type", sa.String(30), nullable=True),
        sa.Column("entity_id", sa.Integer, nullable=True),
        # Full request snapshot for replay-safe approval
        sa.Column("action_payload_json", sa.JSON, nullable=True),
        # High-value biometric trigger (AC-29b): amount >= 50M VND → requires_biometric=True
        sa.Column("requested_amount_vnd", sa.Numeric(15, 0), nullable=True),
        sa.Column(
            "requires_biometric",
            sa.Boolean,
            nullable=False,
            server_default=sa.false(),
        ),
        # Status: pending | approved | rejected | expired | auto_rejected | cancelled
        sa.Column("status", sa.String(20), nullable=False, index=True),
        # SLA: default_72h | kb04_fast_track_6h | fraud_termination_24h
        sa.Column(
            "sla_class",
            sa.String(20),
            nullable=False,
            server_default="default_72h",
        ),
        sa.Column("expires_at", sa.DateTime, nullable=False),
        # Decision
        sa.Column("decided_at", sa.DateTime, nullable=True),
        sa.Column(
            "decided_by_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("decision_reason", sa.Text, nullable=True),
        # AC-30b escalation ladder
        sa.Column(
            "escalation_state",
            sa.String(20),
            nullable=False,
            server_default="push_only",
        ),
        sa.Column("last_notified_at", sa.DateTime, nullable=True),
        sa.Column("delivery_channels_used_json", sa.JSON, nullable=True),
        # AC-43b: fraud termination lockdown flag
        sa.Column(
            "lockdown_fraud_termination",
            sa.Boolean,
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column(
            "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
    )

    # Owner inbox + escalation cron (status + expires_at)
    op.create_index(
        "ix_del_appr_owner_status_expires",
        "delegation_approvals",
        ["owner_id", "status", "expires_at"],
    )
    # Audit: all approvals for a delegation in time order
    op.create_index(
        "ix_del_appr_delegation_created",
        "delegation_approvals",
        ["delegation_id", "created_at"],
    )
    # Expiry cron: scan pending rows ordered by expires_at
    op.create_index(
        "ix_del_appr_status_expires",
        "delegation_approvals",
        ["status", "expires_at"],
    )
    op.create_index(
        "ix_del_appr_requester_user_id", "delegation_approvals", ["requester_user_id"]
    )
    op.create_index(
        "ix_del_appr_decided_by", "delegation_approvals", ["decided_by_user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_del_appr_decided_by", table_name="delegation_approvals")
    op.drop_index("ix_del_appr_requester_user_id", table_name="delegation_approvals")
    op.drop_index("ix_del_appr_status_expires", table_name="delegation_approvals")
    op.drop_index("ix_del_appr_delegation_created", table_name="delegation_approvals")
    op.drop_index("ix_del_appr_owner_status_expires", table_name="delegation_approvals")
    op.drop_table("delegation_approvals")
