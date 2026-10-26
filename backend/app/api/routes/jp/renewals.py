"""JP contract renewal endpoints.

Routes:
  POST /api/jp/renewals/{id}/invoice   — generate 更新料 invoice for a renewal
  POST /api/jp/renewals/{id}/confirm   — tenant confirms renewal

All routes guarded by require_region('jp').
Admin/sales role required for invoice generation.
Tenant role for confirm.
"""

from __future__ import annotations

import logging
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.renewal import JpContractRenewalRepository
from app.schemas.jp.renewal import RenewalConfirmResponse, RenewalInvoiceResponse
from app.services.renewal.invoice_builder import compute_renewal_lines

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/renewals",
    tags=["jp-renewals"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_org_id(request: Request) -> str:
    org_id: Optional[str] = getattr(request.state, "org_id", None)
    if not org_id:
        raise HTTPException(status_code=401, detail="org_id not found in token")
    return org_id


def _get_user_id(request: Request) -> int:
    user_id: Optional[int] = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=401, detail="user_id not found in token")
    return user_id


@router.post("/{renewal_id}/invoice", response_model=RenewalInvoiceResponse)
async def generate_renewal_invoice(
    renewal_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> RenewalInvoiceResponse:
    """Generate 更新料 invoice for a contract renewal.

    Fetches monthly_rent from the contract and computes renewal lines.
    Updates renewal status to 'invoiced'.
    Admin or sales role required.
    """
    org_id = _get_org_id(request)

    # Role check — admin or sales only
    actual_role: Optional[str] = getattr(request.state, "role", None)
    if actual_role not in ("admin", "sales", "owner"):
        raise HTTPException(
            status_code=403, detail="admin, sales, or owner role required"
        )

    repo = JpContractRenewalRepository(db)
    renewal = repo.get(renewal_id, org_id)
    if not renewal:
        raise HTTPException(status_code=404, detail=f"Renewal {renewal_id} not found")

    if renewal.status not in ("pending",):
        raise HTTPException(
            status_code=409,
            detail=f"Renewal is in status '{renewal.status}', cannot generate invoice (expected: pending)",
        )

    # Fetch monthly_rent from contract (cross-domain raw query)
    from sqlalchemy import text

    result = db.execute(
        text("SELECT monthly_rent FROM contracts WHERE id = :cid"),
        {"cid": renewal.contract_id},
    )
    contract_row = result.fetchone()
    if not contract_row or contract_row[0] is None:
        raise HTTPException(
            status_code=422, detail=f"Contract {renewal.contract_id} not found or has no monthly_rent"
        )

    monthly_rent = Decimal(str(contract_row[0]))

    try:
        lines = compute_renewal_lines(monthly_rent_jpy=monthly_rent)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    renewal_fee = sum(line.amount_jpy for line in lines)

    # Update renewal status
    try:
        repo.update_status(
            renewal,
            "invoiced",
            renewal_fee_jpy=renewal_fee,
        )
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("Failed to update renewal status: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to generate invoice") from exc

    return RenewalInvoiceResponse(
        renewal_id=renewal_id,
        status="invoiced",
        invoice_lines=[
            {
                "label": line.label,
                "line_type": line.line_type,
                "amount_jpy": str(line.amount_jpy),
                "tax_treatment": line.tax_treatment,
                "tax_amount_jpy": str(line.tax_amount_jpy),
            }
            for line in lines
        ],
        renewal_fee_jpy=renewal_fee,
        message=f"更新料 invoice generated: {renewal_fee} JPY",
    )


@router.post("/{renewal_id}/confirm", response_model=RenewalConfirmResponse)
async def confirm_renewal(
    renewal_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> RenewalConfirmResponse:
    """Tenant confirms contract renewal.

    Updates renewal status to 'confirmed'.
    Tenant role (or admin) required.
    """
    org_id = _get_org_id(request)

    # Role check — tenant, admin, or sales can confirm
    actual_role: Optional[str] = getattr(request.state, "role", None)
    if actual_role not in ("tenant", "admin", "sales"):
        raise HTTPException(status_code=403, detail="tenant or admin role required")

    repo = JpContractRenewalRepository(db)
    renewal = repo.get(renewal_id, org_id)
    if not renewal:
        raise HTTPException(status_code=404, detail=f"Renewal {renewal_id} not found")

    if renewal.status != "invoiced":
        raise HTTPException(
            status_code=409,
            detail=f"Renewal is in status '{renewal.status}', cannot confirm (expected: invoiced)",
        )

    try:
        repo.update_status(renewal, "confirmed")
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("Failed to confirm renewal: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to confirm renewal") from exc

    return RenewalConfirmResponse(
        renewal_id=renewal_id,
        status="confirmed",
        message="契約更新が確認されました (Renewal confirmed)",
    )
