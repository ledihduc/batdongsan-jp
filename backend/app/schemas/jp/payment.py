"""Pydantic schemas for JP payment endpoints.

Schemas here cover:
  - Payment intent creation request/response
  - Payment status response
  - Konbini voucher response
  - Invoice detail with lines and totals
"""

from __future__ import annotations

from decimal import Decimal
from typing import Any, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Payment intent
# ---------------------------------------------------------------------------

class CreatePaymentIntentRequest(BaseModel):
    """POST /api/jp/payments/intents"""
    invoice_id: str = Field(..., description="Invoice UUID to pay.")
    amount_jpy: int = Field(..., gt=0, description="Amount in JPY (integer yen).")
    method: str = Field(..., description="card | konbini | bank_transfer")

    class Config:
        json_schema_extra = {
            "example": {
                "invoice_id": "inv-abc123",
                "amount_jpy": 80000,
                "method": "konbini",
            }
        }


class PaymentIntentResponse(BaseModel):
    """Response for payment intent creation or status."""
    id: int
    org_id: str
    invoice_id: str
    provider: str
    provider_intent_id: Optional[str]
    method: str
    status: str
    amount_jpy: Decimal
    metadata: Optional[Any] = None

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Konbini voucher
# ---------------------------------------------------------------------------

class KonbiniVoucherResponse(BaseModel):
    """Response for POST /api/jp/payments/intents/{id}/konbini-voucher"""
    store_name: str
    confirmation_number: str
    expiry_at: str
    instructions_url: Optional[str] = None


# ---------------------------------------------------------------------------
# Invoice lines
# ---------------------------------------------------------------------------

class InvoiceLineResponse(BaseModel):
    id: int
    line_type: str
    amount_jpy: Decimal
    tax_treatment: str
    tax_amount_jpy: Decimal
    description: Optional[str] = None

    class Config:
        from_attributes = True


class InvoiceTotalsResponse(BaseModel):
    subtotal_jpy: Decimal
    tax_amount_jpy: Decimal
    total_jpy: Decimal


class InvoiceDetailResponse(BaseModel):
    """GET /api/jp/invoices/{invoice_id}"""
    invoice_id: str
    org_id: str
    lines: list[InvoiceLineResponse]
    totals: InvoiceTotalsResponse
