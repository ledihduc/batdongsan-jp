"""Pydantic v2 schemas for approval workflow endpoints (Phase 04).

AC coverage:
  AC-24..AC-31b: ApprovalCreateRequest (action_type + payload)
  AC-29b: requires_biometric flag in response
  AC-30: expires_at in response
  AC-31: audit fields in response
  AC-43b: lockdown_fraud_termination in response
  AC-55..AC-55d: KB04 schemas (pre-file + fast-track)
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, field_validator, model_validator


# ---------------------------------------------------------------------------
# Approval Decision (owner approves or rejects)
# ---------------------------------------------------------------------------


class ApprovalDecideRequest(BaseModel):
    """Body for POST /api/approvals/{id}/approve and /reject."""

    decision: str  # 'approved' | 'rejected'
    reason: Optional[str] = None
    biometric_token: Optional[str] = None  # AC-29b: required for high-value approvals

    @field_validator("decision")
    @classmethod
    def valid_decision(cls, v: str) -> str:
        if v not in ("approved", "rejected"):
            raise ValueError("decision must be 'approved' or 'rejected'")
        return v

    @model_validator(mode="after")
    def reason_required_for_rejection(self) -> "ApprovalDecideRequest":
        if self.decision == "rejected" and not self.reason:
            raise ValueError("reason is required when decision is 'rejected'")
        return self


# ---------------------------------------------------------------------------
# Approval Cancel (operator cancels own request)
# ---------------------------------------------------------------------------


class ApprovalCancelRequest(BaseModel):
    """Body for POST /api/approvals/{id}/cancel."""

    reason: Optional[str] = "operator_cancelled"


# ---------------------------------------------------------------------------
# Approval Response
# ---------------------------------------------------------------------------


class ApprovalResponse(BaseModel):
    """Response schema for a DelegationApproval row."""

    id: str
    delegation_id: str
    requester_user_id: int
    owner_id: int
    action_type: str
    entity_type: Optional[str] = None
    entity_id: Optional[int] = None
    action_payload_json: Optional[dict] = None
    requested_amount_vnd: Optional[Decimal] = None
    requires_biometric: bool
    status: str
    sla_class: str
    expires_at: datetime
    decided_at: Optional[datetime] = None
    decided_by_user_id: Optional[int] = None
    decision_reason: Optional[str] = None
    escalation_state: str
    last_notified_at: Optional[datetime] = None
    lockdown_fraud_termination: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Approval List Response
# ---------------------------------------------------------------------------


class ApprovalListResponse(BaseModel):
    """Paginated list of approvals."""

    items: list[ApprovalResponse]
    total: int
    offset: int
    limit: int


# ---------------------------------------------------------------------------
# KB04 Fast-Track (POST /api/kb04/{khai_bao_id}/submit-fast-track)
# ---------------------------------------------------------------------------


class KB04FastTrackRequest(BaseModel):
    """Operator submits KB04 fast-track for tenant registration."""

    khai_bao_id: int
    form_data: Optional[dict] = None  # Additional CT01 form fields


class KB04FastTrackResponse(BaseModel):
    """Response after KB04 fast-track submission."""

    approval: ApprovalResponse
    auto_approved: bool  # True if operator_full preset triggered auto-approval
    message: str


# ---------------------------------------------------------------------------
# KB04 Pre-file (POST /api/kb04/pre-file) — AC-55b
# ---------------------------------------------------------------------------


class KB04PreFileRequest(BaseModel):
    """Operator submits CT01 form data before tenant move-in."""

    contract_id: int
    tenant_full_name: str
    tenant_cccd: str
    expected_move_in_date: datetime
    room_id: Optional[int] = None
    additional_form_data: Optional[dict] = None  # Extra CT01 fields

    @field_validator("tenant_cccd")
    @classmethod
    def cccd_format(cls, v: str) -> str:
        v = v.strip()
        if len(v) not in (9, 12):
            raise ValueError("CCCD must be 9 or 12 digits")
        if not v.isdigit():
            raise ValueError("CCCD must contain only digits")
        return v


class KB04PreFileResponse(BaseModel):
    """Response after KB04 pre-file submission."""

    approval: ApprovalResponse
    contract_id: int
    pre_filed_at: datetime
    message: str
    district_warning: Optional[str] = None  # Set if district flag is NULL (AC-55c)


# ---------------------------------------------------------------------------
# Fraud Termination (operator reports fraud — AC-43b)
# ---------------------------------------------------------------------------


class FraudReportRequest(BaseModel):
    """Operator reports fraud on a delegation."""

    fraud_reason: str
    evidence_urls: Optional[list[str]] = None

    @field_validator("fraud_reason")
    @classmethod
    def reason_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("fraud_reason cannot be empty")
        return v.strip()


class FraudReportResponse(BaseModel):
    """Response after fraud report submission."""

    approval: ApprovalResponse
    message: str


# ---------------------------------------------------------------------------
# Query parameters for list endpoints
# ---------------------------------------------------------------------------


class ApprovalListQueryParams(BaseModel):
    """Query parameters for GET /api/approvals."""

    role: Optional[str] = None  # 'owner' | 'operator'
    status: Optional[str] = None  # 'pending' | 'approved' | 'rejected' | 'cancelled' | 'auto_rejected'
    limit: int = 50
    offset: int = 0

    @field_validator("role")
    @classmethod
    def valid_role(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in ("owner", "operator"):
            raise ValueError("role must be 'owner' or 'operator'")
        return v

    @field_validator("status")
    @classmethod
    def valid_status(cls, v: Optional[str]) -> Optional[str]:
        valid = frozenset(["pending", "approved", "rejected", "cancelled", "auto_rejected"])
        if v is not None and v not in valid:
            raise ValueError(f"status must be one of {sorted(valid)}")
        return v
