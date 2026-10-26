"""Pydantic schemas for JP rental terms (月額家賃/敷金/礼金/etc.).

Request and Response types with validators for legal correctness.
"""

from __future__ import annotations

from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator

from app.domain.jp.rental_terms import TAX_TREATMENT_VALUES


class JpRentalTermsCreate(BaseModel):
    """Request body for creating JP rental terms."""

    monthly_rent_jpy: Decimal = Field(
        ...,
        gt=0,
        description="月額家賃 in JPY. Must be positive (legal requirement).",
    )
    management_fee_jpy: Optional[Decimal] = Field(
        None, ge=0, description="共益費 in JPY. Null if included in rent."
    )
    shikikin_months: Optional[Decimal] = Field(
        None, ge=0, le=12, description="敷金 in months of rent (0-12)."
    )
    reikin_months: Optional[Decimal] = Field(
        None, ge=0, le=12, description="礼金 in months of rent (0-12)."
    )
    hoshou_months: Optional[Decimal] = Field(
        None, ge=0, le=12, description="保証金 in months of rent (0-12)."
    )
    koushinryo_months: Optional[Decimal] = Field(
        None, ge=0, le=12, description="更新料 in months of rent (0-12)."
    )
    brokerage_rate: Optional[Decimal] = Field(
        None, ge=0, le=1.1,
        description="仲介手数料率 as decimal (max 1.1 per 宅建業法).",
    )
    hoshou_fee_jpy: Optional[Decimal] = Field(
        None, ge=0, description="保証会社手数料 in JPY."
    )
    tax_treatment: str = Field(
        "included",
        description="消費税扱い: included | excluded | exempt",
    )

    @field_validator("tax_treatment")
    @classmethod
    def validate_tax_treatment(cls, v: str) -> str:
        if v not in TAX_TREATMENT_VALUES:
            raise ValueError(
                f"tax_treatment must be one of: {', '.join(TAX_TREATMENT_VALUES)}"
            )
        return v

    @field_validator("brokerage_rate")
    @classmethod
    def validate_brokerage_rate(cls, v: Optional[Decimal]) -> Optional[Decimal]:
        """Enforce 宅建業法 cap: brokerage rate max 1.1 months."""
        if v is not None and v > Decimal("1.1"):
            raise ValueError(
                "brokerage_rate exceeds legal maximum of 1.1 months (宅建業法 cap)"
            )
        return v


class JpRentalTermsUpdate(BaseModel):
    """Request body for partially updating JP rental terms. All fields optional."""

    monthly_rent_jpy: Optional[Decimal] = Field(None, gt=0)
    management_fee_jpy: Optional[Decimal] = Field(None, ge=0)
    shikikin_months: Optional[Decimal] = Field(None, ge=0, le=12)
    reikin_months: Optional[Decimal] = Field(None, ge=0, le=12)
    hoshou_months: Optional[Decimal] = Field(None, ge=0, le=12)
    koushinryo_months: Optional[Decimal] = Field(None, ge=0, le=12)
    brokerage_rate: Optional[Decimal] = Field(None, ge=0, le=1.1)
    hoshou_fee_jpy: Optional[Decimal] = Field(None, ge=0)
    tax_treatment: Optional[str] = None

    @field_validator("tax_treatment")
    @classmethod
    def validate_tax_treatment(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in TAX_TREATMENT_VALUES:
            raise ValueError(
                f"tax_treatment must be one of: {', '.join(TAX_TREATMENT_VALUES)}"
            )
        return v


class JpRentalTermsResponse(BaseModel):
    """Response schema for JP rental terms."""

    id: int
    org_id: Optional[str]
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
