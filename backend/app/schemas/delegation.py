"""Pydantic v2 schemas for delegation lifecycle endpoints (Phase 03).

AC coverage:
  AC-01/02/03/04/31b: InvitationCreateRequest validators
  AC-05/06: InvitationResponse (status + kyc flags)
  AC-09/10/22: PauseRequest, TerminateRequest, ResignRequest
  AC-57: OutOfOfficeRequest
  AC-42/43/44: DelegationResponse (termination timestamps)
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, model_validator, field_validator


# ---------------------------------------------------------------------------
# Constants (mirror permission_set + domain enums)
# ---------------------------------------------------------------------------

VALID_ROLE_PRESETS = frozenset(["owner_view", "operator_full", "accountant", "viewer"])
VALID_SCOPE_TYPES = frozenset(["all", "building_list"])
VALID_PAUSE_REASONS_OWNER = frozenset(["owner_request"])
VALID_TERMINATE_REASONS = frozenset(
    ["owner_request", "fraud_suspected", "legal_dispute", "operator_resign"]
)


# ---------------------------------------------------------------------------
# Thresholds (AC-31b: all 5 required, ≥ 0, no defaults)
# ---------------------------------------------------------------------------


class ThresholdsRequest(BaseModel):
    """AC-31b: all 5 thresholds must be provided, all ≥ 0."""

    threshold_monthly_rent_vnd: Decimal
    threshold_term_months: int
    threshold_expense_vnd: Decimal
    threshold_rent_change_pct: Decimal
    threshold_refund_vnd: Decimal

    @field_validator(
        "threshold_monthly_rent_vnd",
        "threshold_expense_vnd",
        "threshold_rent_change_pct",
        "threshold_refund_vnd",
    )
    @classmethod
    def must_be_non_negative(cls, v: Decimal) -> Decimal:
        if v < 0:
            raise ValueError("Threshold values must be >= 0")
        return v

    @field_validator("threshold_term_months")
    @classmethod
    def term_months_positive(cls, v: int) -> int:
        if v < 0:
            raise ValueError("threshold_term_months must be >= 0")
        return v


# ---------------------------------------------------------------------------
# Invitation schemas
# ---------------------------------------------------------------------------


class InvitationCreateRequest(BaseModel):
    """AC-01/02/03/04/31b: create delegation invitation.

    commission_pct XOR commission_fixed_vnd — exactly one (AC-04).
    scope_type in {all, building_list} (AC-02).
    role_preset in valid presets (AC-03).
    All 5 thresholds required (AC-31b).
    """

    invited_phone_or_email: str
    role_preset: str
    scope_type: str
    scope_target_ids: Optional[list[int]] = None
    commission_pct: Optional[Decimal] = None
    commission_fixed_vnd: Optional[Decimal] = None
    thresholds: ThresholdsRequest
    poa_format: str = "digital"

    @field_validator("commission_pct")
    @classmethod
    def commission_pct_fraction(cls, v: Optional[Decimal]) -> Optional[Decimal]:
        """Enforce fraction convention: commission_pct must be in (0, 1].

        0.05 = 5%, 1.0 = 100%. Values like 5.00 (which would mean 500%) are rejected.
        """
        if v is None:
            return v
        if v <= Decimal("0") or v > Decimal("1"):
            raise ValueError(
                f"commission_pct must be a fraction in (0, 1]. "
                f"Example: Decimal('0.05') for 5%. Got: {v}"
            )
        return v

    @field_validator("role_preset")
    @classmethod
    def valid_role_preset(cls, v: str) -> str:
        if v not in VALID_ROLE_PRESETS:
            raise ValueError(
                f"role_preset must be one of {sorted(VALID_ROLE_PRESETS)}. "
                "Custom permission matrix is not supported in v1."
            )
        return v

    @field_validator("scope_type")
    @classmethod
    def valid_scope_type(cls, v: str) -> str:
        if v not in VALID_SCOPE_TYPES:
            raise ValueError(f"scope_type must be one of {sorted(VALID_SCOPE_TYPES)}")
        return v

    @field_validator("poa_format")
    @classmethod
    def valid_poa_format(cls, v: str) -> str:
        if v not in ("digital", "notarized"):
            raise ValueError("poa_format must be 'digital' or 'notarized'")
        return v

    @model_validator(mode="after")
    def commission_xor(self) -> "InvitationCreateRequest":
        """AC-04: exactly one of commission_pct / commission_fixed_vnd must be set."""
        has_pct = self.commission_pct is not None
        has_fixed = self.commission_fixed_vnd is not None
        if has_pct == has_fixed:  # both None or both set
            raise ValueError(
                "Exactly one of commission_pct or commission_fixed_vnd must be provided (AC-04)"
            )
        return self

    @model_validator(mode="after")
    def scope_target_ids_required_for_building_list(self) -> "InvitationCreateRequest":
        """AC-02: scope_target_ids required when scope_type=building_list."""
        if self.scope_type == "building_list" and not self.scope_target_ids:
            raise ValueError(
                "scope_target_ids must be provided when scope_type='building_list'"
            )
        return self


class InvitationResponse(BaseModel):
    """Response for a delegation invitation."""

    id: str
    owner_id: int
    invited_phone_or_email: str
    invited_user_id: Optional[int] = None
    status: str
    proposed_role_preset: str
    proposed_scope_type: str
    proposed_scope_target_ids: Optional[list[int]] = None
    proposed_commission_pct: Optional[Decimal] = None
    proposed_commission_fixed_vnd: Optional[Decimal] = None
    proposed_poa_format: str
    expires_at: datetime
    accepted_at: Optional[datetime] = None
    rejected_at: Optional[datetime] = None
    revoked_at: Optional[datetime] = None
    created_at: datetime
    # AC-06: KYC completion flag for Flutter button gate
    operator_kyc_complete: bool = False
    # Deep link for operator to accept
    accept_url: Optional[str] = None
    # AC-10b: revoke URL for duplicate invite 409 response
    revoke_url: Optional[str] = None

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Delegation schemas
# ---------------------------------------------------------------------------


class DelegationResponse(BaseModel):
    """Full delegation detail response."""

    id: str
    owner_id: int
    operator_id: int
    invitation_id: Optional[str] = None
    status: str
    paused_reason: Optional[str] = None
    paused_until: Optional[datetime] = None
    role_preset: str
    scope_type: str
    scope_target_ids: Optional[list[int]] = None
    commission_pct: Optional[Decimal] = None
    commission_fixed_vnd: Optional[Decimal] = None
    # Thresholds
    threshold_monthly_rent_vnd: Decimal
    threshold_term_months: int
    threshold_expense_vnd: Decimal
    threshold_rent_change_pct: Decimal
    threshold_refund_vnd: Decimal
    # POA
    poa_format: str
    # OOO
    out_of_office_start: Optional[datetime] = None
    out_of_office_end: Optional[datetime] = None
    # Lifecycle timestamps
    activated_at: Optional[datetime] = None
    terminate_requested_at: Optional[datetime] = None
    terminate_reason: Optional[str] = None
    terminated_at: Optional[datetime] = None
    archived_at: Optional[datetime] = None
    # Retention
    retention_tier: str
    created_at: datetime
    updated_at: datetime
    # Convenience: is_terminating flag for Flutter
    is_terminating: bool = False

    model_config = {"from_attributes": True}

    @model_validator(mode="after")
    def set_is_terminating(self) -> "DelegationResponse":
        self.is_terminating = self.status == "terminating"
        return self


class DelegationListItem(BaseModel):
    """Abbreviated delegation item for list endpoints."""

    id: str
    owner_id: int
    operator_id: int
    status: str
    role_preset: str
    scope_type: str
    created_at: datetime
    activated_at: Optional[datetime] = None
    terminate_requested_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Mutation request schemas
# ---------------------------------------------------------------------------


class PauseRequest(BaseModel):
    """AC-09: owner pause with explicit reason."""

    reason: str = "owner_request"
    paused_until: Optional[datetime] = None

    @field_validator("reason")
    @classmethod
    def valid_pause_reason(cls, v: str) -> str:
        # Owners can only supply owner_request; system reasons set by cron.
        if v not in VALID_PAUSE_REASONS_OWNER:
            raise ValueError(
                f"Owners may only pause with reason 'owner_request'. "
                f"System reasons ({sorted(VALID_TERMINATE_REASONS)}) are set internally."
            )
        return v


class ResumeRequest(BaseModel):
    """Owner resumes a paused delegation. Body is optional (no required fields)."""

    pass


class TerminateRequest(BaseModel):
    """AC-10/45: owner terminates delegation.

    Default = 30d notice (status='terminating').
    fraud_suspected / legal_dispute → immediate termination.
    """

    reason: str = "owner_request"

    @field_validator("reason")
    @classmethod
    def valid_terminate_reason(cls, v: str) -> str:
        if v not in VALID_TERMINATE_REASONS:
            raise ValueError(
                f"reason must be one of {sorted(VALID_TERMINATE_REASONS)}"
            )
        return v

    @property
    def is_immediate(self) -> bool:
        return self.reason in ("fraud_suspected", "legal_dispute")


class ResignRequest(BaseModel):
    """AC-22: operator self-resign. Operator provides reason."""

    reason: str = "operator_resign"


class CancelTerminationRequest(BaseModel):
    """Owner cancels pending 30d termination notice (reverts to active)."""

    pass


class OutOfOfficeRequest(BaseModel):
    """AC-57: operator sets out-of-office date range.

    Set both to null to clear OOO.
    start must be before end when both provided.
    """

    out_of_office_start: Optional[datetime] = None
    out_of_office_end: Optional[datetime] = None

    @model_validator(mode="after")
    def validate_oof_pair(self) -> "OutOfOfficeRequest":
        start = self.out_of_office_start
        end = self.out_of_office_end
        # Either both None (clear) or both set (set range)
        if (start is None) != (end is None):
            raise ValueError(
                "out_of_office_start and out_of_office_end must both be set or both be null"
            )
        if start is not None and end is not None and start >= end:
            raise ValueError("out_of_office_start must be before out_of_office_end")
        return self


class ThresholdUpdateRequest(BaseModel):
    """Owner updates delegation thresholds mid-contract."""

    thresholds: ThresholdsRequest


# ---------------------------------------------------------------------------
# Acceptance schemas
# ---------------------------------------------------------------------------


class InvitationAcceptRequest(BaseModel):
    """Operator accepts an invitation. Optional: disclosure ACK."""

    shared_login_disclosure_ack: bool = False


class AcceptResponse(BaseModel):
    """Response after accepting an invitation.

    AC-05: if operator KYC not complete → status=pending_op_kyc + kyc_redirect hint.
    """

    delegation: DelegationResponse
    # AC-06: indicates KYC required before activation
    kyc_required: bool = False
    kyc_redirect_url: Optional[str] = None


# ---------------------------------------------------------------------------
# Audit response
# ---------------------------------------------------------------------------


class AuditLogEntry(BaseModel):
    """AC-46: audit log entry for delegation-related changes."""

    id: int
    actor_user_id: int
    on_behalf_of_user_id: Optional[int] = None
    delegation_id: Optional[str] = None
    action: str
    entity_type: Optional[str] = None
    entity_id: Optional[int] = None
    diff_json: Optional[dict] = None
    created_at: datetime

    model_config = {"from_attributes": True}
