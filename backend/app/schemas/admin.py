"""Pydantic schemas for admin API endpoints — Phase 10.

Covers:
  - AdminDashboardSummary    — GET /api/admin/dashboard/summary
  - AdminAuditTrailResponse  — GET /api/admin/audit-trail/{delegation_id}
  - AdminUserDelegationsResponse — GET /api/admin/users/{user_id}/delegations
  - ForceRevokeRequest/Response — POST /api/admin/delegations/{id}/force-revoke
  - SuspendOperatorRequest/Response — POST /api/admin/users/{user_id}/suspend-operator
  - ReinstateOperatorRequest/Response — POST /api/admin/users/{user_id}/reinstate-operator
  - DisputeEscalateRequest/Response — POST /api/admin/disputes/{id}/escalate
  - DisputeResolveRequest/Response  — POST /api/admin/disputes/{id}/resolve
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, field_validator


# ---------------------------------------------------------------------------
# Dashboard summary
# ---------------------------------------------------------------------------


class AdminDashboardSummary(BaseModel):
    """Aggregate counts for the admin ops dashboard (US-A5 / phase-10 Step 2)."""

    pending_kyc_count: int
    pending_death_certs_count: int
    pending_poa_reviews_count: int  # approvals in 'pending' status
    fraud_reports_last_24h_count: int
    stuck_approvals_count: int  # approvals pending > 60h (US-A5)
    active_delegations_count: int
    paused_delegations_count: int
    as_of: datetime


# ---------------------------------------------------------------------------
# Audit trail
# ---------------------------------------------------------------------------


class AuditTrailEntry(BaseModel):
    """Single entry in a delegation's dual-identity audit trail."""

    id: int
    action: str
    actor_id: Optional[int]
    on_behalf_of_user_id: Optional[int]
    acted_via_delegation_id: Optional[str]
    entity_type: str
    entity_id: int
    created_at: datetime
    extra: Optional[dict] = None


class AdminAuditTrailResponse(BaseModel):
    """Full audit history for a delegation (dual-identity ChangeLog rows)."""

    delegation_id: str
    entries: list[AuditTrailEntry]
    total: int


# ---------------------------------------------------------------------------
# User delegations
# ---------------------------------------------------------------------------


class DelegationSummary(BaseModel):
    """Slim delegation record for admin view."""

    id: str
    owner_id: int
    operator_id: int
    status: str
    role_preset: str
    paused_reason: Optional[str]
    retention_tier: str
    created_at: datetime
    activated_at: Optional[datetime]
    terminate_requested_at: Optional[datetime]
    terminated_at: Optional[datetime]


class AdminUserDelegationsResponse(BaseModel):
    """All delegations where user is owner or operator."""

    user_id: int
    as_owner: list[DelegationSummary]
    as_operator: list[DelegationSummary]


# ---------------------------------------------------------------------------
# Force-revoke
# ---------------------------------------------------------------------------


class ForceRevokeRequest(BaseModel):
    """Admin force-revokes a delegation (AC-45 / fraud / court order)."""

    reason: str
    immediate: bool = True

    @field_validator("reason")
    @classmethod
    def reason_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("reason must not be empty")
        return v.strip()


class ForceRevokeResponse(BaseModel):
    delegation_id: str
    status: str  # 'terminated'
    terminated_at: datetime
    admin_action: str = "admin_force_revoke"
    reason: str


# ---------------------------------------------------------------------------
# Suspend / reinstate operator
# ---------------------------------------------------------------------------


class SuspendOperatorRequest(BaseModel):
    """Admin globally suspends all of an operator's active delegations."""

    reason: str

    @field_validator("reason")
    @classmethod
    def reason_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("reason must not be empty")
        return v.strip()


class SuspendOperatorResponse(BaseModel):
    user_id: int
    delegations_paused: int
    reason: str
    suspended_at: datetime


class ReinstateOperatorRequest(BaseModel):
    """Admin reinstates an operator — resumes delegations paused for admin_suspend."""

    reason: str

    @field_validator("reason")
    @classmethod
    def reason_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("reason must not be empty")
        return v.strip()


class ReinstateOperatorResponse(BaseModel):
    user_id: int
    delegations_reinstated: int
    reason: str
    reinstated_at: datetime


# ---------------------------------------------------------------------------
# Dispute escalate / resolve (AC-63)
# ---------------------------------------------------------------------------


class DisputeEscalateRequest(BaseModel):
    """Mark a tenant authority flag for priority manual review."""

    reason: str

    @field_validator("reason")
    @classmethod
    def reason_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("reason must not be empty")
        return v.strip()


class DisputeEscalateResponse(BaseModel):
    dispute_id: str
    status: str  # 'escalated'
    escalated_at: datetime
    reason: str


class DisputeResolveRequest(BaseModel):
    """Admin closes a dispute with a verdict (AC-63 48h SLA)."""

    outcome: str  # 'prima_facie_valid' | 'invalid' | 'requires_evidence'
    action: str  # 'pause_delegation' | 'no_action' | 'request_more_info'
    reason: str

    @field_validator("outcome")
    @classmethod
    def validate_outcome(cls, v: str) -> str:
        allowed = {"prima_facie_valid", "invalid", "requires_evidence"}
        if v not in allowed:
            raise ValueError(f"outcome must be one of {sorted(allowed)}")
        return v

    @field_validator("action")
    @classmethod
    def validate_action(cls, v: str) -> str:
        allowed = {"pause_delegation", "no_action", "request_more_info"}
        if v not in allowed:
            raise ValueError(f"action must be one of {sorted(allowed)}")
        return v

    @field_validator("reason")
    @classmethod
    def reason_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("reason must not be empty")
        return v.strip()


class DisputeResolveResponse(BaseModel):
    dispute_id: str
    outcome: str
    action: str
    reason: str
    resolved_at: datetime
    delegation_paused: bool  # True only when action == 'pause_delegation'
