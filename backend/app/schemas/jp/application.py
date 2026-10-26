"""Pydantic schemas for JP tenant applications and review decisions.

Validators enforce:
  - annual_income_jpy: positive if provided
  - decision: approved | rejected | needs_info
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator

from app.domain.jp.application import APPLICATION_STATUS_VALUES, REVIEW_DECISION_VALUES


class JpTenantApplicationCreate(BaseModel):
    """Request body for creating a tenant application (initial draft)."""

    listing_id: str = Field(..., min_length=1, description="Target listing UUID")
    employer_name: Optional[str] = Field(None, max_length=200)
    annual_income_jpy: Optional[Decimal] = Field(
        None, gt=0, description="年収 in JPY. Must be positive if provided."
    )
    guarantor_name: Optional[str] = Field(None, max_length=200)
    guarantor_phone: Optional[str] = Field(None, max_length=20)
    emergency_contact_name: Optional[str] = Field(None, max_length=200)
    emergency_contact_phone: Optional[str] = Field(None, max_length=20)
    documents: Optional[dict[str, str]] = Field(
        None,
        description="Dict of doc_type -> URL. Keys e.g. income_cert, id_front, id_back.",
    )

    @field_validator("annual_income_jpy")
    @classmethod
    def validate_income(cls, v: Optional[Decimal]) -> Optional[Decimal]:
        if v is not None and v <= 0:
            raise ValueError("annual_income_jpy must be positive")
        return v


class JpTenantApplicationUpdate(BaseModel):
    """Partial update for a draft application. All fields optional."""

    employer_name: Optional[str] = Field(None, max_length=200)
    annual_income_jpy: Optional[Decimal] = Field(None, gt=0)
    guarantor_name: Optional[str] = Field(None, max_length=200)
    guarantor_phone: Optional[str] = Field(None, max_length=20)
    emergency_contact_name: Optional[str] = Field(None, max_length=200)
    emergency_contact_phone: Optional[str] = Field(None, max_length=20)
    documents: Optional[dict[str, str]] = None


class JpTenantApplicationResponse(BaseModel):
    """Response schema for a tenant application."""

    id: int
    org_id: Optional[str]
    listing_id: str
    applicant_user_id: int
    employer_name: Optional[str]
    annual_income_jpy: Optional[Decimal]
    guarantor_name: Optional[str]
    # Phone fields masked in responses (PII) — caller may choose to expose to owner/reviewer
    guarantor_phone: Optional[str]
    emergency_contact_name: Optional[str]
    emergency_contact_phone: Optional[str]
    documents: Optional[dict[str, str]]
    status: str
    submitted_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class JpApplicationReviewCreate(BaseModel):
    """Request body for submitting a review decision."""

    decision: str = Field(
        ...,
        description=f"Review decision. One of: {', '.join(REVIEW_DECISION_VALUES)}",
    )
    notes: Optional[str] = Field(None, max_length=2000)

    @field_validator("decision")
    @classmethod
    def validate_decision(cls, v: str) -> str:
        if v not in REVIEW_DECISION_VALUES:
            raise ValueError(
                f"decision must be one of: {', '.join(REVIEW_DECISION_VALUES)}"
            )
        return v


class JpApplicationReviewResponse(BaseModel):
    """Response schema for a review decision."""

    id: int
    application_id: int
    reviewer_user_id: int
    decision: str
    notes: Optional[str]
    decided_at: Optional[datetime]
    org_id: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class JpListingCreateRequest(BaseModel):
    """Composite request for creating a JP listing with all JP-specific fields.

    Wraps the JP extensions — core listing fields come from existing listing schema.
    This type is used by the JP listings router (POST /api/jp/listings).
    """

    # Core listing identification (references existing listing)
    listing_id: str = Field(..., description="Existing listing UUID to attach JP data to")

    # JP extensions (all optional — can be added incrementally)
    rental_terms: Optional["JpRentalTermsCreateInline"] = None
    property_info: Optional["JpPropertyInfoCreateInline"] = None
    transit_access: Optional[list["TransitAccessCreateInline"]] = None


class JpRentalTermsCreateInline(BaseModel):
    """Inline rental terms for composite listing request."""
    monthly_rent_jpy: Decimal = Field(..., gt=0)
    management_fee_jpy: Optional[Decimal] = Field(None, ge=0)
    shikikin_months: Optional[Decimal] = Field(None, ge=0, le=12)
    reikin_months: Optional[Decimal] = Field(None, ge=0, le=12)
    hoshou_months: Optional[Decimal] = Field(None, ge=0, le=12)
    koushinryo_months: Optional[Decimal] = Field(None, ge=0, le=12)
    brokerage_rate: Optional[Decimal] = Field(None, ge=0, le=1.1)
    hoshou_fee_jpy: Optional[Decimal] = Field(None, ge=0)
    tax_treatment: str = "included"


class JpPropertyInfoCreateInline(BaseModel):
    """Inline property info for composite listing request."""
    layout: Optional[str] = None
    floor_area_sqm: Optional[Decimal] = Field(None, gt=0)
    building_year: Optional[int] = Field(None, ge=1900, le=2100)
    structure: Optional[str] = None
    floor_number: Optional[int] = Field(None, ge=-5, le=100)
    orientation: Optional[str] = None
    available_from: Optional[str] = None  # ISO date string


class TransitAccessCreateInline(BaseModel):
    """Inline transit access for composite listing request."""
    station_id: int
    walk_min: int = Field(..., ge=1, le=60)


class JpListingResponse(BaseModel):
    """Composite response for a JP listing with all JP-specific fields."""

    listing_id: str
    rental_terms: Optional["JpRentalTermsInlineResponse"] = None
    property_info: Optional["JpPropertyInfoInlineResponse"] = None
    transit_access: list["TransitAccessInlineResponse"] = []


class JpRentalTermsInlineResponse(BaseModel):
    id: int
    monthly_rent_jpy: Decimal
    management_fee_jpy: Optional[Decimal]
    shikikin_months: Optional[Decimal]
    reikin_months: Optional[Decimal]
    hoshou_months: Optional[Decimal]
    koushinryo_months: Optional[Decimal]
    brokerage_rate: Optional[Decimal]
    hoshou_fee_jpy: Optional[Decimal]
    tax_treatment: str
    model_config = {"from_attributes": True}


class JpPropertyInfoInlineResponse(BaseModel):
    id: int
    layout: Optional[str]
    floor_area_sqm: Optional[Decimal]
    building_year: Optional[int]
    structure: Optional[str]
    floor_number: Optional[int]
    orientation: Optional[str]
    available_from: Optional[str]
    model_config = {"from_attributes": True}


class TransitAccessInlineResponse(BaseModel):
    id: int
    station_id: int
    walk_min: int
    station_name_ja: Optional[str] = None
    line_name_ja: Optional[str] = None
    model_config = {"from_attributes": True}
