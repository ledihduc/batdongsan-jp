"""JP invoice detail endpoints.

Routes:
  GET /api/jp/invoices/{invoice_id} — invoice with lines + totals

All routes guarded by require_region('jp').
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.invoice_line import JpInvoiceLineRepository
from app.schemas.jp.payment import (
    InvoiceDetailResponse,
    InvoiceLineResponse,
    InvoiceTotalsResponse,
)
from app.services.jp.invoice.line_generator import compute_totals

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/invoices",
    tags=["jp-invoices"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_org_id(request: Request) -> str:
    org_id: Optional[str] = getattr(request.state, "org_id", None)
    if not org_id:
        raise HTTPException(status_code=401, detail="org_id not found in token")
    return org_id


@router.get("/{invoice_id}", response_model=InvoiceDetailResponse)
async def get_invoice_detail(
    invoice_id: str,
    request: Request,
    db: Session = Depends(get_db),
) -> InvoiceDetailResponse:
    """Return invoice detail with all lines and computed totals."""
    org_id = _get_org_id(request)
    repo = JpInvoiceLineRepository(db)
    lines = repo.list_by_invoice(invoice_id=invoice_id, org_id=org_id)

    if not lines:
        raise HTTPException(status_code=404, detail="Invoice not found")

    totals = compute_totals(lines)

    line_responses = [
        InvoiceLineResponse(
            id=ln.id,
            line_type=ln.line_type,
            amount_jpy=ln.amount_jpy,
            tax_treatment=ln.tax_treatment,
            tax_amount_jpy=ln.tax_amount_jpy,
            description=ln.description,
        )
        for ln in lines
    ]

    return InvoiceDetailResponse(
        invoice_id=invoice_id,
        org_id=org_id,
        lines=line_responses,
        totals=InvoiceTotalsResponse(
            subtotal_jpy=totals.subtotal_jpy,
            tax_amount_jpy=totals.tax_amount_jpy,
            total_jpy=totals.total_jpy,
        ),
    )
