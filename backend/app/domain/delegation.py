"""SQLAlchemy ORM models for the Owner-Operator Delegation domain.

New tables: delegations, delegation_invitations, delegation_approvals.
These support BA v4 AC-01..AC-08, AC-22/23, AC-31b, AC-43/44, AC-55d, AC-62/64/66.

FK cascade strategy (AC-52):
  - owner_id / operator_id → RESTRICT (cannot delete user with active delegation).
  - invitation_id → SET NULL (invitation can be cleaned up independently).

Scope mechanism (TL-1 / NFR-13):
  - scope_type STR(20): 'all' | 'building_list'  (v2 adds 'room_list')
  - scope_target_ids: JSON array of int IDs (NULL when scope_type='all')
  Using SQLAlchemy JSON (generic) → Postgres maps to JSONB, SQLite maps to TEXT.
  Partial unique index on (owner_id) WHERE status='active' enforces AC-08.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


def _new_uuid() -> str:
    """Generate UUID4 string — cross-DB compatible (no PG UUID type dependency)."""
    return str(uuid.uuid4())


# ---------------------------------------------------------------------------
# Delegation — core delegation record
# ---------------------------------------------------------------------------


class Delegation(Base):
    """Core delegation record linking an owner (host) with an operator.

    UUID PK (not INT) because id is transported in HTTP header
    X-Acting-As-Delegation-Id — INT would allow enumeration attacks.

    Constraints enforced at DB level:
      - Partial UNIQUE (owner_id) WHERE status='active' → AC-08 (1 active per owner)
        Created via op.execute() in migration 0021 (Alembic helpers lack WHERE support).
      - CHECK commission_pct XOR commission_fixed_vnd → AC-04 (mutually exclusive).
      - CHECK out_of_office pair consistency.

    role column: 'operator' = primary login persona; is_operator_capable flag on users
    = can accept delegation invites. Both may be True (host who also operates — AC-56).
    """

    __tablename__ = "delegations"
    __table_args__ = (
        # AC-04: commission XOR — exactly one must be non-NULL.
        CheckConstraint(
            "(commission_pct IS NULL) != (commission_fixed_vnd IS NULL)",
            name="ck_delegations_commission_xor",
        ),
        # out_of_office pair: both NULL or both set, and start < end when set.
        CheckConstraint(
            "(out_of_office_start IS NULL) = (out_of_office_end IS NULL)",
            name="ck_delegations_oof_pair",
        ),
        # Composite indexes for dashboard + cron queries.
        Index("ix_delegations_owner_status", "owner_id", "status"),
        Index("ix_delegations_operator_status", "operator_id", "status"),
        Index("ix_delegations_status_terminate", "status", "terminate_requested_at"),
        Index("ix_delegations_retention_tier", "retention_tier", "retention_tier_transitioned_at"),
        Index("ix_delegations_created_at", "created_at"),
    )

    # Primary key — UUID string (cross-DB compatible)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)

    # Owner (RESTRICT: cannot delete user with active delegation)
    owner_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    # Operator (RESTRICT: same reason)
    operator_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    # Backref to originating invite (NULL for admin-created delegations)
    invitation_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("delegation_invitations.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Status: pending_op_kyc | active | paused | terminating | terminated | archived
    status: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    # Pause metadata
    paused_reason: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    # owner_request | kyc_expired | gpkd_revoked | owner_death | fraud_flag | admin_force
    paused_until: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Role preset: owner_view | operator_full | accountant | viewer  (BA §3, AC-19/20/21)
    role_preset: Mapped[str] = mapped_column(String(30), nullable=False)

    # Scope mechanism (TL-1 / NFR-13)
    # scope_type: 'all' | 'building_list' — v2 adds 'room_list'
    scope_type: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    # JSON array of int building IDs; NULL when scope_type='all'
    scope_target_ids: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Commission — exactly one of these must be non-NULL (AC-04 CHECK above)
    commission_pct: Mapped[Optional[object]] = mapped_column(
        Numeric(5, 2), nullable=True  # e.g. 5.00 = 5%
    )
    commission_fixed_vnd: Mapped[Optional[object]] = mapped_column(
        Numeric(15, 0), nullable=True
    )

    # Threshold columns — ALL NOT NULL, no server defaults (AC-24/25/26/28/31b)
    # Must be explicitly set at invitation time — no silent fallback.
    threshold_monthly_rent_vnd: Mapped[object] = mapped_column(Numeric(15, 0), nullable=False)
    threshold_term_months: Mapped[int] = mapped_column(Integer, nullable=False)
    threshold_expense_vnd: Mapped[object] = mapped_column(Numeric(15, 0), nullable=False)
    threshold_rent_change_pct: Mapped[object] = mapped_column(Numeric(5, 2), nullable=False)
    threshold_refund_vnd: Mapped[object] = mapped_column(Numeric(15, 0), nullable=False)

    # POA fields (AC-55d, US-O19)
    poa_format: Mapped[str] = mapped_column(
        String(20), nullable=False, default="digital"
    )  # 'digital' | 'notarized'
    poa_document_path: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True
    )  # Encrypted-at-rest path

    # Operator disclosure acknowledgement — required for doanh-nghiệp (AC-66)
    shared_login_disclosure_ack_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True
    )

    # Out-of-office window (AC-57) — CHECK constraint above enforces pair
    out_of_office_start: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    out_of_office_end: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Lifecycle timestamps
    activated_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    terminate_requested_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True
    )  # Start of 30d lockdown clock (AC-43)
    terminate_reason: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True
    )  # owner_request | operator_resign | fraud_suspected | legal_dispute | kyc_expired_grace_lapsed
    terminated_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    archived_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # 4-tier retention (D9, AC-44): hot | warm | cold | legal_hold
    retention_tier: Mapped[str] = mapped_column(
        String(10), nullable=False, default="hot"
    )
    retention_tier_transitioned_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=_now_utc, onupdate=_now_utc
    )

    # ORM relationships (lazy load — avoid N+1 in list endpoints)
    owner: Mapped[Optional["User"]] = relationship(  # type: ignore[name-defined]
        "User", foreign_keys=[owner_id], lazy="select"
    )
    operator: Mapped[Optional["User"]] = relationship(  # type: ignore[name-defined]
        "User", foreign_keys=[operator_id], lazy="select"
    )
    invitation: Mapped[Optional["DelegationInvitation"]] = relationship(
        "DelegationInvitation", foreign_keys=[invitation_id], lazy="select"
    )
    approvals: Mapped[list["DelegationApproval"]] = relationship(
        "DelegationApproval", back_populates="delegation", lazy="select"
    )

    def __repr__(self) -> str:
        return (
            f"<Delegation id={self.id} owner={self.owner_id} "
            f"operator={self.operator_id} status={self.status}>"
        )


# ---------------------------------------------------------------------------
# DelegationInvitation — pending invites with TTL
# ---------------------------------------------------------------------------


class DelegationInvitation(Base):
    """Delegation invite lifecycle record.

    Kept separate from delegations so declined/expired invites are auditable
    without polluting the active delegation table.

    token: URL-safe random 64-char string — single-use (AC-01).
    token_used_at: set on accept → blocks re-use.
    expires_at: default created_at + 7 days (AC-01).

    UNIQUE(owner_id, invited_phone_or_email) WHERE status='pending' → AC-10b:
    no duplicate pending invite for same (owner, invitee). Applied via
    op.execute() in migration 0021.
    """

    __tablename__ = "delegation_invitations"
    __table_args__ = (
        Index("ix_del_inv_owner_status", "owner_id", "status"),
        Index("ix_del_inv_created_at", "created_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)

    owner_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    # Single field — resolved to user_id on accept
    invited_phone_or_email: Mapped[str] = mapped_column(String(200), nullable=False)
    # Set if invited user already has an account (resolved at invite creation)
    invited_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Invite token — 64 char URL-safe random; single-use
    token: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    token_used_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Proposed delegation parameters (copied to Delegation on accept)
    proposed_role_preset: Mapped[str] = mapped_column(String(30), nullable=False)
    proposed_scope_type: Mapped[str] = mapped_column(String(20), nullable=False)
    proposed_scope_target_ids: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    proposed_commission_pct: Mapped[Optional[object]] = mapped_column(
        Numeric(5, 2), nullable=True
    )
    proposed_commission_fixed_vnd: Mapped[Optional[object]] = mapped_column(
        Numeric(15, 0), nullable=True
    )
    # All 5 thresholds bundled as JSON (validated against schema in service layer)
    proposed_thresholds_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    proposed_poa_format: Mapped[str] = mapped_column(
        String(20), nullable=False, default="digital"
    )

    # Status: pending | accepted | rejected | expired | revoked_by_owner
    status: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    # TTL: default created_at + 7 days (AC-01); set by service at creation
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)

    accepted_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    rejected_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    revoked_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now_utc)

    def __repr__(self) -> str:
        return (
            f"<DelegationInvitation id={self.id} owner={self.owner_id} "
            f"to={self.invited_phone_or_email} status={self.status}>"
        )


# ---------------------------------------------------------------------------
# DelegationApproval — approval queue + state machine
# ---------------------------------------------------------------------------


class DelegationApproval(Base):
    """Owner approval queue for operator-triggered actions that exceed thresholds.

    Each row = one operator action that required owner sign-off.
    action_payload_json is a full snapshot so approval can be processed even if
    the originating request context changes.

    sla_class drives expires_at computation:
      - default_72h (AC-30)
      - kb04_fast_track_6h (AC-55)
      - fraud_termination_24h (AC-43b)

    escalation_state tracks notification ladder (AC-30b):
      push_only → push_email → push_email_sms → escalated_admin
    """

    __tablename__ = "delegation_approvals"
    __table_args__ = (
        # Owner inbox + escalation cron
        Index("ix_del_appr_owner_status_expires", "owner_id", "status", "expires_at"),
        # Audit
        Index("ix_del_appr_delegation_created", "delegation_id", "created_at"),
        # Expiry cron — partial-style via WHERE in migration (op.execute)
        Index("ix_del_appr_status_expires", "status", "expires_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)

    delegation_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("delegations.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    # Snapshot of operator_id at request time (in case delegation transferred)
    requester_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    # Denormalized for fast inbox query — avoids join through delegations
    owner_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )

    # What the operator wanted to do
    action_type: Mapped[str] = mapped_column(
        String(40), nullable=False
    )
    # contract_create | contract_terminate | invoice_high_amount | expense_high_amount
    # rent_change | refund_high_amount | kb04_fast_track | kb04_pre_file
    # fraud_termination | threshold_change

    # Entity the action targets (NULL for threshold_change type)
    entity_type: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    entity_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Full request snapshot — approval can still be acted on if request changes
    action_payload_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # High-value biometric trigger (AC-29b): amount >= 50M VND
    requested_amount_vnd: Mapped[Optional[object]] = mapped_column(
        Numeric(15, 0), nullable=True
    )
    requires_biometric: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    # Status: pending | approved | rejected | expired | auto_rejected | cancelled
    status: Mapped[str] = mapped_column(String(20), nullable=False, index=True)

    # SLA classification (drives expires_at)
    sla_class: Mapped[str] = mapped_column(
        String(20), nullable=False, default="default_72h"
    )
    # default_72h | kb04_fast_track_6h | fraud_termination_24h
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)

    # Decision fields
    decided_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    decided_by_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    # Normally = owner_id; can be executor (AC-58d)
    decision_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Notification escalation ladder (AC-30b)
    escalation_state: Mapped[str] = mapped_column(
        String(20), nullable=False, default="push_only"
    )
    # push_only | push_email | push_email_sms | escalated_admin
    last_notified_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    delivery_channels_used_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # AC-43b: fraud termination lockdown flag
    lockdown_fraud_termination: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now_utc)

    # ORM relationships
    delegation: Mapped[Optional["Delegation"]] = relationship(
        "Delegation", foreign_keys=[delegation_id], back_populates="approvals", lazy="select"
    )
    owner: Mapped[Optional["User"]] = relationship(  # type: ignore[name-defined]
        "User", foreign_keys=[owner_id], lazy="select"
    )
    requester: Mapped[Optional["User"]] = relationship(  # type: ignore[name-defined]
        "User", foreign_keys=[requester_user_id], lazy="select"
    )

    def __repr__(self) -> str:
        return (
            f"<DelegationApproval id={self.id} action={self.action_type} "
            f"status={self.status} delegation={self.delegation_id}>"
        )
