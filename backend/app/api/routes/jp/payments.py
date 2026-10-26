"""JP payment endpoints.

Routes:
  POST /api/jp/payments/intents          — create payment intent
  GET  /api/jp/payments/intents/{id}     — get intent status
  POST /api/jp/payments/intents/{id}/konbini-voucher — issue konbini voucher

All routes guarded by require_region('jp').
"""

from __future__ import annotations

import logging
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.payment_intent import JpPaymentIntentRepository
from app.schemas.jp.payment import (
    CreatePaymentIntentRequest,
    KonbiniVoucherResponse,
    PaymentIntentResponse,
)
from app.services.payment.jp.provider_resolver import resolve_payment_adapter

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/payments",
    tags=["jp-payments"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_org_id(request: Request) -> str:
    """Extract org_id from request state (set by auth middleware)."""
    org_id: Optional[str] = getattr(request.state, "org_id", None)
    if not org_id:
        raise HTTPException(status_code=401, detail="org_id not found in token")
    return org_id


@router.post("/intents", response_model=PaymentIntentResponse, status_code=201)
async def create_payment_intent(
    body: CreatePaymentIntentRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> PaymentIntentResponse:
    """Create a payment intent for a JP invoice.

    Validates input, creates a JpPaymentIntent row (status=pending), then calls
    the payment adapter to register with the provider.
    """
    org_id = _get_org_id(request)

    valid_methods = ("card", "konbini", "bank_transfer")
    if body.method not in valid_methods:
        raise HTTPException(
            status_code=422,
            detail=f"method must be one of: {', '.join(valid_methods)}",
        )

    repo = JpPaymentIntentRepository(db)

    # Create DB row first (pending) — provider call may fail
    intent = repo.create(
        org_id=org_id,
        invoice_id=body.invoice_id,
        amount_jpy=Decimal(body.amount_jpy),
        method=body.method,
        provider="komoju",
    )

    try:
        adapter = await resolve_payment_adapter(org_id, db)
        result = await adapter.create_payment_intent(
            invoice_id=body.invoice_id,
            amount_jpy=body.amount_jpy,
            method=body.method,
        )
        repo.update_status(
            intent,
            status=result.status,
            provider_intent_id=result.provider_intent_id,
            metadata=result.metadata,
        )
        db.commit()
        db.refresh(intent)
    except Exception as exc:
        db.rollback()
        logger.error("create_payment_intent failed for org=%s: %s", org_id, exc)
        raise HTTPException(status_code=502, detail="Payment provider error") from exc

    return PaymentIntentResponse(
        id=intent.id,
        org_id=intent.org_id,
        invoice_id=intent.invoice_id,
        provider=intent.provider,
        provider_intent_id=intent.provider_intent_id,
        method=intent.method,
        status=intent.status,
        amount_jpy=intent.amount_jpy,
        metadata=intent.metadata_,
    )


@router.get("/intents/{intent_id}", response_model=PaymentIntentResponse)
async def get_payment_intent(
    intent_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> PaymentIntentResponse:
    """Get current status of a payment intent."""
    org_id = _get_org_id(request)
    repo = JpPaymentIntentRepository(db)
    intent = repo.get_by_id_org(intent_id, org_id)
    if intent is None:
        raise HTTPException(status_code=404, detail="Payment intent not found")

    return PaymentIntentResponse(
        id=intent.id,
        org_id=intent.org_id,
        invoice_id=intent.invoice_id,
        provider=intent.provider,
        provider_intent_id=intent.provider_intent_id,
        method=intent.method,
        status=intent.status,
        amount_jpy=intent.amount_jpy,
        metadata=intent.metadata_,
    )


@router.post(
    "/intents/{intent_id}/konbini-voucher",
    response_model=KonbiniVoucherResponse,
)
async def issue_konbini_voucher(
    intent_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> KonbiniVoucherResponse:
    """Issue a konbini payment voucher for an existing intent.

    Intent must have method='konbini' and be in status 'pending' or 'processing'.
    """
    org_id = _get_org_id(request)
    repo = JpPaymentIntentRepository(db)
    intent = repo.get_by_id_org(intent_id, org_id)
    if intent is None:
        raise HTTPException(status_code=404, detail="Payment intent not found")

    if intent.method != "konbini":
        raise HTTPException(status_code=422, detail="Intent method is not konbini")

    if intent.status not in ("pending", "processing"):
        raise HTTPException(
            status_code=422,
            detail=f"Cannot issue voucher for intent in status '{intent.status}'",
        )

    try:
        adapter = await resolve_payment_adapter(org_id, db)
        voucher = await adapter.issue_konbini_voucher(intent.provider_intent_id or "")
    except Exception as exc:
        logger.error("issue_konbini_voucher failed for intent=%d: %s", intent_id, exc)
        raise HTTPException(status_code=502, detail="Payment provider error") from exc

    return KonbiniVoucherResponse(
        store_name=voucher.store_name,
        confirmation_number=voucher.confirmation_number,
        expiry_at=voucher.expiry_at,
        instructions_url=voucher.instructions_url or None,
    )
