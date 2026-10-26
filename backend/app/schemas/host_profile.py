"""Pydantic v2 schemas for HostProfile endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, field_validator


class HostProfileBase(BaseModel):
    """Fields that a host can read and write (no security-sensitive fields)."""
    cover_path: Optional[str] = None
    tax_id: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_name: Optional[str] = None
    bank_account_holder: Optional[str] = None
    payout_schedule: Optional[str] = "monthly"


class HostProfileCreate(HostProfileBase):
    """Schema used internally when creating a new HostProfile row."""
    user_id: int


class HostProfileUpdate(HostProfileBase):
    """PATCH /api/host/profile — all fields optional."""
    pass


class HostProfileResponse(BaseModel):
    """Read-only response envelope. Exposes safe fields only — no CCCD paths."""
    id: int
    user_id: int
    verified: bool
    cover_path: Optional[str] = None
    # CCCD: expose booleans (uploaded / not) — never expose actual paths
    cccd_front_uploaded: bool
    cccd_back_uploaded: bool
    bank_account_number: Optional[str] = None
    bank_name: Optional[str] = None
    bank_account_holder: Optional[str] = None
    tax_id: Optional[str] = None
    avg_response_hours: Optional[float] = None
    rating: Optional[float] = None
    payout_schedule: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_safe(cls, profile: object) -> "HostProfileResponse":
        """Build response from ORM model, replacing sensitive path fields with booleans."""
        return cls(
            id=profile.id,  # type: ignore[attr-defined]
            user_id=profile.user_id,  # type: ignore[attr-defined]
            verified=profile.verified,  # type: ignore[attr-defined]
            cover_path=getattr(profile, "cover_path", None),
            cccd_front_uploaded=bool(profile.cccd_front_path),  # type: ignore[attr-defined]
            cccd_back_uploaded=bool(profile.cccd_back_path),  # type: ignore[attr-defined]
            bank_account_number=profile.bank_account_number,  # type: ignore[attr-defined]
            bank_name=profile.bank_name,  # type: ignore[attr-defined]
            bank_account_holder=profile.bank_account_holder,  # type: ignore[attr-defined]
            tax_id=profile.tax_id,  # type: ignore[attr-defined]
            avg_response_hours=profile.avg_response_hours,  # type: ignore[attr-defined]
            rating=profile.rating,  # type: ignore[attr-defined]
            payout_schedule=profile.payout_schedule,  # type: ignore[attr-defined]
            created_at=profile.created_at,  # type: ignore[attr-defined]
            updated_at=profile.updated_at,  # type: ignore[attr-defined]
        )


class CccdUploadResponse(BaseModel):
    success: bool
    front_uploaded: bool
    back_uploaded: bool


class UpgradeToHostResponse(BaseModel):
    token: str
    message: str
