"""Pydantic schemas for owner death workflow endpoints — Phase 06.

AC coverage:
  AC-58: death certificate report / verify / reject
  AC-58a/b/c: heir designation and ownership transitions
  AC-58d: executor exception override
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


# ---------------------------------------------------------------------------
# Death certificate — report (POST /api/owner-death/report)
# ---------------------------------------------------------------------------


class DeathReportRequest(BaseModel):
    """Request body for reporting an owner's death."""

    owner_user_id: int = Field(..., description="User ID of the deceased owner", gt=0)
    death_certificate_path: str = Field(
        ...,
        description="Path to uploaded death certificate file (must be a valid upload path)",
        min_length=1,
        max_length=500,
    )
    notarized_poa_path: Optional[str] = Field(
        default=None,
        description="Path to notarized Power of Attorney document (optional at report time)",
        max_length=500,
    )
    executor_user_id: Optional[int] = Field(
        default=None,
        description="Optional designated executor/heir user ID",
        gt=0,
    )

    @field_validator("death_certificate_path")
    @classmethod
    def validate_cert_path(cls, v: str) -> str:
        import os
        normalized = os.path.normpath(v)
        if normalized.startswith("..") or "\x00" in v:
            raise ValueError("Invalid file path — path traversal detected")
        return v

    @field_validator("notarized_poa_path")
    @classmethod
    def validate_poa_path(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        import os
        normalized = os.path.normpath(v)
        if normalized.startswith("..") or "\x00" in v:
            raise ValueError("Invalid POA path — path traversal detected")
        return v


class DeathCertificateResponse(BaseModel):
    """Response schema for an OwnerDeathCertificate record."""

    id: str
    owner_user_id: int
    submitted_by_user_id: Optional[int] = None
    death_certificate_path: str
    notarized_poa_path: Optional[str] = None
    verification_status: str
    verified_at: Optional[datetime] = None
    verified_by_admin_id: Optional[int] = None
    executor_user_id: Optional[int] = None
    executor_onboarded_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Death certificate — verify (POST /api/admin/owner-death/{id}/verify)
# ---------------------------------------------------------------------------


class DeathVerifyRequest(BaseModel):
    """Admin verifies a death certificate."""

    notes: Optional[str] = Field(
        default=None,
        description="Admin reviewer notes (stored in audit log)",
        max_length=2000,
    )
    in_flight_handling_policy: str = Field(
        default="auto_reject",
        description=(
            "'auto_reject' (safe default) or 'executor_may_decide' "
            "(requires gate O3 legal sign-off)"
        ),
    )

    @field_validator("in_flight_handling_policy")
    @classmethod
    def validate_policy(cls, v: str) -> str:
        valid = {"auto_reject", "executor_may_decide"}
        if v not in valid:
            raise ValueError(f"Must be one of {sorted(valid)}")
        return v


class DeathVerifyResponse(BaseModel):
    """Response after admin verification."""

    certificate: DeathCertificateResponse
    delegations_paused: int = Field(description="Number of delegations paused")
    delegation_ids_paused: list[str] = Field(default_factory=list)
    sla_warning: bool = Field(
        default=False,
        description="True if verification exceeded 24h business-hours SLA",
    )


# ---------------------------------------------------------------------------
# Death certificate — reject (POST /api/admin/owner-death/{id}/reject)
# ---------------------------------------------------------------------------


class DeathRejectRequest(BaseModel):
    """Admin rejects a death certificate."""

    rejection_reason: str = Field(
        ...,
        description="Reason for rejection (required for audit trail)",
        min_length=10,
        max_length=2000,
    )


# ---------------------------------------------------------------------------
# Heir designation (POST /api/owner-death/{id}/designate-heir)
# ---------------------------------------------------------------------------


class HeirDesignateRequest(BaseModel):
    """Admin designates a heir for the deceased owner."""

    heir_user_id: int = Field(..., description="User ID of the designated heir", gt=0)
    create_inherit_view: bool = Field(
        default=True,
        description="If True, creates an inherit_view delegation for the heir",
    )


class HeirDesignateResponse(BaseModel):
    """Response after heir designation."""

    certificate: DeathCertificateResponse
    inherit_view_delegation_id: Optional[str] = Field(
        default=None,
        description="ID of the created inherit_view delegation (if create_inherit_view=True)",
    )


# ---------------------------------------------------------------------------
# Executor exception (AC-58d — gated by OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED)
# ---------------------------------------------------------------------------


class ExecutorDecisionRequest(BaseModel):
    """Executor makes a decision on an in-flight approval."""

    approval_id: str = Field(
        ..., description="UUID of the delegation_approval being decided"
    )
    decision: str = Field(..., description="'approved' or 'rejected'")
    notes: Optional[str] = Field(
        default=None,
        description="Optional notes from the executor",
        max_length=1000,
    )

    @field_validator("decision")
    @classmethod
    def validate_decision(cls, v: str) -> str:
        if v not in ("approved", "rejected"):
            raise ValueError("Must be 'approved' or 'rejected'")
        return v


class ExecutorDecisionResponse(BaseModel):
    """Response after executor decision."""

    approval_id: str
    decision: str
    executor_override: bool = True
    decision_by_executor: bool = True
    decided_at: str
    notes: Optional[str] = None


# ---------------------------------------------------------------------------
# Death status query (GET /api/owner-death/{owner_id})
# ---------------------------------------------------------------------------


class DeathStatusResponse(BaseModel):
    """Current death workflow status for an owner."""

    owner_user_id: int
    certificate: Optional[DeathCertificateResponse] = None
    delegations_paused_count: int = 0
    has_heir_window: bool = False
    message: str = ""
