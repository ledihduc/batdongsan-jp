"""Pydantic schemas for JP contract renewal endpoints."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field


class RenewalResponse(BaseModel):
    """Response schema for a contract renewal record."""

    id: int
    org_id: str
    contract_id: int
    scheduled_at: datetime
    renewal_fee_jpy: Optional[Decimal] = None
    status: str
    invoice_id: Optional[str] = None
    notified_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class RenewalInvoiceResponse(BaseModel):
    """Response for POST /api/jp/renewals/{id}/invoice."""

    renewal_id: int
    status: str
    invoice_lines: list[dict]
    renewal_fee_jpy: Decimal
    message: str


class RenewalConfirmResponse(BaseModel):
    """Response for POST /api/jp/renewals/{id}/confirm."""

    renewal_id: int
    status: str
    message: str
