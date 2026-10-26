"""create delegations and delegation_invitations tables

Revision ID: 0021_create_delegations_and_invitations
Revises: 0020_create_tt200_exports
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

New tables:
  - delegations: core delegation record (UUID PK — non-guessable for HTTP header transport)
  - delegation_invitations: pending invites with TTL (separate for declined-invite audit)

AC coverage:
  - AC-01: invitation token UNIQUE + token_used_at + expires_at 7d default
  - AC-04: CHECK constraint mutually exclusive commission columns
  - AC-07: no unique on operator_id — multi-owner support
  - AC-08: partial UNIQUE (owner_id) WHERE status='active' — 1 active per owner
  - AC-10b: partial UNIQUE (owner_id, invited_phone_or_email) WHERE status='pending'
  - AC-31b: 5 threshold columns NOT NULL (no server defaults — must be set at invite)
  - AC-43/44: terminate_requested_at + archived_at + retention_tier columns
  - AC-55d: poa_format enum field
  - AC-57: out_of_office pair CHECK
  - AC-62: (acted_at added in 0032; delegations.activated_at here)
  - AC-66: shared_login_disclosure_ack_at

NFR-13 (TL-1): scope_type STR(20) + scope_target_ids JSON array (KISS, no separate Scope table)
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0021_create_delegations_and_invitations"
down_revision = "0020_create_tt200_exports"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── Widen alembic_version.version_num to VARCHAR(64) ──────────────────────
    # Default Alembic creates `alembic_version.version_num VARCHAR(32)`. Starting
    # at this revision the ID is 39 chars (`0021_create_delegations_and_invitations`)
    # and later IDs reach 42 chars (`0003_rename_booking_to_viewing_appointment`).
    # Fresh-DB `alembic upgrade head` fails here on PostgreSQL with
    # StringDataRightTruncation when Alembic UPDATEs version_num. SQLite stores
    # as TEXT regardless of declared length so this ALTER is a no-op there, but
    # kept unconditional for simplicity. Postgres `ALTER TYPE` on a 1-row table
    # is instant. 64 chars covers all current + near-future revision IDs.
    _widen_alembic_version_column(64)

    # ── delegation_invitations (created before delegations — FK from delegations.invitation_id) ──
    op.create_table(
        "delegation_invitations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "owner_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        # Single field — resolved to user_id on accept
        sa.Column("invited_phone_or_email", sa.String(200), nullable=False),
        sa.Column(
            "invited_user_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        # Single-use token (AC-01)
        sa.Column("token", sa.String(64), nullable=False, unique=True),
        sa.Column("token_used_at", sa.DateTime, nullable=True),
        # Proposed delegation parameters (copied to delegations on accept)
        sa.Column("proposed_role_preset", sa.String(30), nullable=False),
        sa.Column("proposed_scope_type", sa.String(20), nullable=False),
        sa.Column("proposed_scope_target_ids", sa.JSON, nullable=True),
        sa.Column("proposed_commission_pct", sa.Numeric(5, 2), nullable=True),
        sa.Column("proposed_commission_fixed_vnd", sa.Numeric(15, 0), nullable=True),
        # All 5 thresholds bundled as JSON (service layer validates before accepting)
        sa.Column("proposed_thresholds_json", sa.JSON, nullable=True),
        sa.Column("proposed_poa_format", sa.String(20), nullable=False, server_default="digital"),
        # Status: pending | accepted | rejected | expired | revoked_by_owner
        sa.Column("status", sa.String(20), nullable=False, index=True),
        # Default 7 days TTL (AC-01) — set by service at creation time
        sa.Column("expires_at", sa.DateTime, nullable=False),
        sa.Column("accepted_at", sa.DateTime, nullable=True),
        sa.Column("rejected_at", sa.DateTime, nullable=True),
        sa.Column("revoked_at", sa.DateTime, nullable=True),
        sa.Column(
            "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index(
        "ix_del_inv_owner_status", "delegation_invitations", ["owner_id", "status"]
    )
    op.create_index(
        "ix_del_inv_created_at", "delegation_invitations", ["created_at"]
    )
    op.create_index(
        "ix_del_inv_owner_id", "delegation_invitations", ["owner_id"]
    )
    op.create_index(
        "ix_del_inv_invited_user_id", "delegation_invitations", ["invited_user_id"]
    )

    # AC-10b: partial UNIQUE (owner_id, invited_phone_or_email) WHERE status='pending'
    # Blocks re-invite while one is pending (HTTP 409 in service layer).
    # op.execute() required — Alembic create_unique_constraint doesn't support WHERE.
    _run_postgres_only(
        "CREATE UNIQUE INDEX uq_del_inv_owner_phone_pending "
        "ON delegation_invitations (owner_id, invited_phone_or_email) "
        "WHERE status = 'pending'"
    )

    # ── delegations — core delegation record ──────────────────────────────────
    op.create_table(
        "delegations",
        sa.Column("id", sa.String(36), primary_key=True),
        # FK cascade = RESTRICT: cannot delete user with active delegation
        sa.Column(
            "owner_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "operator_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "invitation_id",
            sa.String(36),
            sa.ForeignKey("delegation_invitations.id", ondelete="SET NULL"),
            nullable=True,
        ),
        # Status: pending_op_kyc | active | paused | terminating | terminated | archived
        sa.Column("status", sa.String(30), nullable=False, index=True),
        # Pause metadata: owner_request | kyc_expired | gpkd_revoked | owner_death | fraud_flag | admin_force
        sa.Column("paused_reason", sa.String(50), nullable=True),
        sa.Column("paused_until", sa.DateTime, nullable=True),
        # Role preset: owner_view | operator_full | accountant | viewer
        sa.Column("role_preset", sa.String(30), nullable=False),
        # Scope (TL-1 / NFR-13): 'all' | 'building_list' (v2 adds 'room_list')
        sa.Column("scope_type", sa.String(20), nullable=False, index=True),
        # JSON array of int building IDs; NULL when scope_type='all'
        sa.Column("scope_target_ids", sa.JSON, nullable=True),
        # Commission — AC-04: exactly one must be non-NULL (CHECK below)
        sa.Column("commission_pct", sa.Numeric(5, 2), nullable=True),
        sa.Column("commission_fixed_vnd", sa.Numeric(15, 0), nullable=True),
        # Threshold columns — ALL NOT NULL, no server defaults (AC-24/25/26/28/31b)
        # Must be set explicitly at invitation time.
        sa.Column("threshold_monthly_rent_vnd", sa.Numeric(15, 0), nullable=False),
        sa.Column("threshold_term_months", sa.Integer, nullable=False),
        sa.Column("threshold_expense_vnd", sa.Numeric(15, 0), nullable=False),
        sa.Column("threshold_rent_change_pct", sa.Numeric(5, 2), nullable=False),
        sa.Column("threshold_refund_vnd", sa.Numeric(15, 0), nullable=False),
        # POA (AC-55d, US-O19): 'digital' | 'notarized'
        sa.Column("poa_format", sa.String(20), nullable=False, server_default="digital"),
        sa.Column("poa_document_path", sa.String(500), nullable=True),
        # AC-66: operator-doanh-nghiệp shared login disclosure
        sa.Column("shared_login_disclosure_ack_at", sa.DateTime, nullable=True),
        # Out-of-office window (AC-57) — CHECK: both NULL or both set
        sa.Column("out_of_office_start", sa.DateTime, nullable=True),
        sa.Column("out_of_office_end", sa.DateTime, nullable=True),
        # Lifecycle timestamps
        sa.Column("activated_at", sa.DateTime, nullable=True),
        sa.Column("terminate_requested_at", sa.DateTime, nullable=True),
        sa.Column("terminate_reason", sa.String(50), nullable=True),
        sa.Column("terminated_at", sa.DateTime, nullable=True),
        sa.Column("archived_at", sa.DateTime, nullable=True),
        # 4-tier retention (D9, AC-44): hot | warm | cold | legal_hold
        sa.Column(
            "retention_tier", sa.String(10), nullable=False, server_default="hot"
        ),
        sa.Column("retention_tier_transitioned_at", sa.DateTime, nullable=True),
        sa.Column(
            "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
        # AC-04: commission XOR — exactly one must be non-NULL
        sa.CheckConstraint(
            "(commission_pct IS NULL) != (commission_fixed_vnd IS NULL)",
            name="ck_delegations_commission_xor",
        ),
        # AC-57: out_of_office pair consistency — both NULL or both set
        sa.CheckConstraint(
            "(out_of_office_start IS NULL) = (out_of_office_end IS NULL)",
            name="ck_delegations_oof_pair",
        ),
    )

    # Composite indexes for dashboard + cron queries
    op.create_index("ix_delegations_owner_status", "delegations", ["owner_id", "status"])
    op.create_index("ix_delegations_operator_status", "delegations", ["operator_id", "status"])
    op.create_index(
        "ix_delegations_status_terminate",
        "delegations",
        ["status", "terminate_requested_at"],
    )
    op.create_index(
        "ix_delegations_retention_tier",
        "delegations",
        ["retention_tier", "retention_tier_transitioned_at"],
    )
    op.create_index("ix_delegations_created_at", "delegations", ["created_at"])
    op.create_index("ix_delegations_owner_id", "delegations", ["owner_id"])
    op.create_index("ix_delegations_operator_id", "delegations", ["operator_id"])
    op.create_index("ix_delegations_invitation_id", "delegations", ["invitation_id"])

    # AC-08: partial UNIQUE (owner_id) WHERE status='active'
    # Ensures only one active delegation per owner at any time.
    # Uses op.execute() — Alembic create_unique_constraint lacks WHERE clause support.
    # Falls back to application-layer guard on SQLite (dialect check).
    _run_postgres_only(
        "CREATE UNIQUE INDEX uq_delegations_owner_active "
        "ON delegations (owner_id) WHERE status = 'active'"
    )


def downgrade() -> None:
    # Drop in reverse FK order
    # delegations.invitation_id → delegation_invitations, so drop delegations first
    op.drop_index("ix_delegations_invitation_id", table_name="delegations")
    op.drop_index("ix_delegations_operator_id", table_name="delegations")
    op.drop_index("ix_delegations_owner_id", table_name="delegations")
    op.drop_index("ix_delegations_created_at", table_name="delegations")
    op.drop_index("ix_delegations_retention_tier", table_name="delegations")
    op.drop_index("ix_delegations_status_terminate", table_name="delegations")
    op.drop_index("ix_delegations_operator_status", table_name="delegations")
    op.drop_index("ix_delegations_owner_status", table_name="delegations")
    _run_postgres_only("DROP INDEX IF EXISTS uq_delegations_owner_active")
    op.drop_table("delegations")

    _run_postgres_only("DROP INDEX IF EXISTS uq_del_inv_owner_phone_pending")
    op.drop_index("ix_del_inv_invited_user_id", table_name="delegation_invitations")
    op.drop_index("ix_del_inv_owner_id", table_name="delegation_invitations")
    op.drop_index("ix_del_inv_created_at", table_name="delegation_invitations")
    op.drop_index("ix_del_inv_owner_status", table_name="delegation_invitations")
    op.drop_table("delegation_invitations")


def _run_postgres_only(sql: str) -> None:
    """Execute raw SQL only on PostgreSQL — skip on SQLite dev DB.

    SQLite does not support partial (WHERE) indexes. The application layer
    enforces the same uniqueness constraint for SQLite (dev-mode only).
    """
    conn = op.get_bind()
    if conn.dialect.name == "postgresql":
        conn.execute(sa.text(sql))


def _widen_alembic_version_column(target_length: int) -> None:
    """Widen alembic_version.version_num on PostgreSQL (SQLite TEXT is dynamic).

    Idempotent: inspects current column length and only runs ALTER if narrower
    than target. No-op on SQLite (declared length ignored by storage class).
    """
    conn = op.get_bind()
    if conn.dialect.name != "postgresql":
        return
    current = conn.execute(
        sa.text(
            "SELECT character_maximum_length FROM information_schema.columns "
            "WHERE table_name = 'alembic_version' AND column_name = 'version_num'"
        )
    ).scalar()
    if current is None or current >= target_length:
        return
    conn.execute(
        sa.text(
            f"ALTER TABLE alembic_version "
            f"ALTER COLUMN version_num TYPE VARCHAR({target_length})"
        )
    )
