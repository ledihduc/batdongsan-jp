"""Pydantic schemas for JP deposit settlement endpoints."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator


class DeductionItemSchema(BaseModel):
    """One itemized deduction in a settlement."""

    label: str = Field(..., min_length=1, max_length=200)
    amount_jpy: int = Field(..., ge=0, description="Deduction amount in JPY")
    reason: str = Field(default="", max_length=500)


class CreateSettlementRequest(BaseModel):
    """POST /api/jp/deposit-settlements"""

    contract_id: int = Field(..., gt=0)
    gross_shikikin_jpy: int = Field(..., gt=0, description="Original deposit in JPY")

    class Config:
        json_schema_extra = {
            "example": {"contract_id": 42, "gross_shikikin_jpy": 200000}
        }


class PatchSettlementItemsRequest(BaseModel):
    """PATCH /api/jp/deposit-settlements/{id}/items"""

    deductions: list[DeductionItemSchema] = Field(
        default_factory=list, description="List of owner deductions"
    )

    @field_validator("deductions")
    @classmethod
    def validate_deductions(cls, v: list) -> list:
        if len(v) > 50:
            raise ValueError("Maximum 50 deduction items per settlement")
        return v


class SettlementResponse(BaseModel):
    """Response schema for a deposit settlement record."""

    id: int
    org_id: str
    contract_id: int
    status: str
    gross_shikikin_jpy: Decimal
    deductions_json: Optional[Any] = None
    refund_jpy: Optional[Decimal] = None
    refund_invoice_id: Optional[str] = None
    owner_signed_at: Optional[datetime] = None
    tenant_signed_at: Optional[datetime] = None
    payout_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class PayoutResponse(BaseModel):
    """Response for POST /api/jp/deposit-settlements/{id}/payout."""

    settlement_id: int
    status: str
    refund_jpy: Optional[Decimal]
    invoice_id: Optional[str]
    message: str
