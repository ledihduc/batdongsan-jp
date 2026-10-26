"""Pydantic schemas for KYC and onboarding endpoints (Phase 05).

All schemas use strict types. No `any` escapes.
File paths are NEVER included in API responses (security: internal server paths only).
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


# ---------------------------------------------------------------------------
# Operator individual KYC
# ---------------------------------------------------------------------------


class IndividualKycStatusResponse(BaseModel):
    """GET /api/kyc/operator/individual/status — summary for Flutter UI."""

    kyc_complete: bool
    verified: bool
    has_cccd: bool
    has_bank: bool
    kyc_expires_at: Optional[datetime] = None
    kyc_grace_period_until: Optional[datetime] = None


# ---------------------------------------------------------------------------
# Operator business KYC — step-by-step wizard
# ---------------------------------------------------------------------------


class BusinessInfoRequest(BaseModel):
    """Step 1: POST /api/kyc/operator/business/info."""

    business_name: str = Field(..., min_length=2, max_length=300)
    business_registration_number: str = Field(..., min_length=5, max_length=50)
    gpkd_industry_codes: list[str] = Field(
        default_factory=list,
        description="List of ngành codes from GPKD (validated by admin at review stage).",
    )

    @field_validator("business_name")
    @classmethod
    def normalize_business_name(cls, v: str) -> str:
        """NFC-normalize Vietnamese diacritics (NFR-12)."""
        import unicodedata
        return unicodedata.normalize("NFC", v.strip())

    @field_validator("business_registration_number")
    @classmethod
    def strip_registration_number(cls, v: str) -> str:
        return v.strip()


class BusinessInfoResponse(BaseModel):
    """Step 1 response — profile id for subsequent steps."""

    profile_id: int
    business_name: str
    business_registration_number: str
    verification_status: str
    created_at: datetime


class BusinessGpkdUploadResponse(BaseModel):
    """Step 2 response — confirms GPKD was stored."""

    profile_id: int
    gpkd_stored: bool
    gpkd_issued_at: Optional[datetime] = None
    gpkd_expires_at: Optional[datetime] = None


class LegalRepInfoRequest(BaseModel):
    """Step 3 form fields (files uploaded separately as multipart)."""

    legal_representative_name: str = Field(..., min_length=2, max_length=300)
    legal_representative_cccd_number: str = Field(..., min_length=9, max_length=20)
    legal_representative_phone: str = Field(..., min_length=9, max_length=20)

    @field_validator("legal_representative_name")
    @classmethod
    def normalize_name(cls, v: str) -> str:
        import unicodedata
        return unicodedata.normalize("NFC", v.strip())

    @field_validator("legal_representative_cccd_number")
    @classmethod
    def strip_cccd(cls, v: str) -> str:
        return v.strip().replace(" ", "")

    @field_validator("legal_representative_phone")
    @classmethod
    def strip_phone(cls, v: str) -> str:
        return v.strip()


class LegalRepInfoResponse(BaseModel):
    """Step 3 response."""

    profile_id: int
    legal_representative_name: str
    verification_status: str


class BusinessProfileResponse(BaseModel):
    """GET /api/kyc/operator/business/me — full profile summary."""

    profile_id: int
    user_id: int
    business_name: str
    business_registration_number: str
    gpkd_industry_codes: list[str]
    gpkd_issued_at: Optional[datetime] = None
    gpkd_expires_at: Optional[datetime] = None
    legal_representative_name: str
    legal_representative_phone: str
    verification_status: str
    verified_at: Optional[datetime] = None
    legal_rep_changed_at: Optional[datetime] = None
    created_at: datetime


class LegalRepChangeRequest(BaseModel):
    """POST /api/kyc/operator/business/legal-rep-change — AC-50b / AC-65."""

    new_legal_representative_name: str = Field(..., min_length=2, max_length=300)
    new_legal_representative_cccd_number: str = Field(..., min_length=9, max_length=20)
    new_legal_representative_phone: str = Field(..., min_length=9, max_length=20)
    reason: str = Field(..., min_length=10, max_length=1000)

    @field_validator("new_legal_representative_name")
    @classmethod
    def normalize_name(cls, v: str) -> str:
        import unicodedata
        return unicodedata.normalize("NFC", v.strip())


# ---------------------------------------------------------------------------
# Digital signature
# ---------------------------------------------------------------------------


class DigitalSignatureInitiateRequest(BaseModel):
    """POST /api/kyc/digital-signature/initiate."""

    delegation_id: str = Field(..., description="UUID of the delegation requiring POA signing.")
    document_name: str = Field(default="POA_delegation.pdf", max_length=200)


class DigitalSignatureInitiateResponse(BaseModel):
    """Response with signing session info (no document bytes returned)."""

    status: str
    signature_ref: str
    session_url: Optional[str] = None
    provider: str


class DigitalSignatureCallbackRequest(BaseModel):
    """POST /api/kyc/digital-signature/callback — vendor webhook body."""

    # Vendor-specific fields — accept arbitrary dict, validate at service layer
    signature_ref: Optional[str] = None
    ref: Optional[str] = None  # Some vendors use 'ref' as key
    status: Optional[str] = None


# ---------------------------------------------------------------------------
# Owner attestations
# ---------------------------------------------------------------------------


class SoleOwnershipAttestationRequest(BaseModel):
    """PATCH /api/kyc/owner/sole-ownership-attestation — AC-64."""

    attested: bool = Field(..., description="Must be True to record attestation.")

    @field_validator("attested")
    @classmethod
    def must_be_true(cls, v: bool) -> bool:
        if not v:
            raise ValueError(
                "attested must be True. "
                "Revoking attestation is not self-service in v1 (contact admin)."
            )
        return v


class SoleOwnershipAttestationResponse(BaseModel):
    """GET or PATCH response."""

    attested_at: Optional[datetime] = None
    attested: bool


class SharedLoginDisclosureAckResponse(BaseModel):
    """PATCH /api/kyc/delegation/{id}/shared-login-disclosure-ack — AC-66."""

    delegation_id: str
    shared_login_disclosure_ack_at: Optional[datetime] = None
    ack_recorded: bool


# ---------------------------------------------------------------------------
# Admin endpoints
# ---------------------------------------------------------------------------


class AdminBusinessApproveRequest(BaseModel):
    """POST /admin/kyc/operator-business/{id}/approve."""

    note: Optional[str] = Field(None, max_length=1000)


class AdminBusinessRejectRequest(BaseModel):
    """POST /admin/kyc/operator-business/{id}/reject."""

    reason: str = Field(..., min_length=5, max_length=1000)


class AdminGpkdRevokeRequest(BaseModel):
    """PATCH /admin/kyc/operator-business/{id}/revoke-gpkd."""

    reason: str = Field(..., min_length=5, max_length=1000)


class AdminKycQueueItem(BaseModel):
    """Single item in the admin KYC review queue."""

    profile_id: int
    user_id: int
    kyc_type: str  # 'individual' | 'business'
    verification_status: str
    business_name: Optional[str] = None
    legal_representative_name: Optional[str] = None
    submitted_at: Optional[datetime] = None
    overdue: bool = False


class AdminKycQueueResponse(BaseModel):
    """GET /admin/kyc/queue."""

    items: list[AdminKycQueueItem]
    total: int


class OnboardingStatusResponse(BaseModel):
    """GET /api/kyc/onboarding/status — full operator onboarding status."""

    user_id: int
    is_operator_capable: bool
    operator_type: str
    individual: dict
    business: dict
    sole_ownership_attested: bool


class PmcLegalRepUpdateRequest(BaseModel):
    """POST /api/kyc/owner/pmc-legal-rep-update — AC-65 admin-reviewed update."""

    profile_id: int = Field(..., description="OperatorBusinessProfile id.")
    new_legal_representative_name: str = Field(..., min_length=2, max_length=300)
    new_legal_representative_cccd_number: str = Field(..., min_length=9, max_length=20)
    new_legal_representative_phone: str = Field(..., min_length=9, max_length=20)
    reason: str = Field(..., min_length=10, max_length=1000)


class SharedLoginDisclosureRequest(BaseModel):
    """POST /api/kyc/owner/shared-login-disclosure — AC-66 disclosure acknowledgment."""

    delegation_id: str = Field(..., description="UUID of the delegation being acked.")
    acknowledged: bool = Field(..., description="Must be True to record disclosure.")

    @field_validator("acknowledged")
    @classmethod
    def must_be_true(cls, v: bool) -> bool:
        if not v:
            raise ValueError(
                "acknowledged must be True to complete shared-login disclosure."
            )
        return v
