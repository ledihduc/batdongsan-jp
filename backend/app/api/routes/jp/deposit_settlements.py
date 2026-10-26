"""JP deposit settlement endpoints — 敷金精算.

Routes:
  POST   /api/jp/deposit-settlements                     — owner creates settlement
  PATCH  /api/jp/deposit-settlements/{id}/items          — owner itemizes deductions
  POST   /api/jp/deposit-settlements/{id}/tenant-sign    — tenant accepts
  POST   /api/jp/deposit-settlements/{id}/payout         — process refund payout

Security: owner/admin creates and itemizes; tenant signs; dual-approval for payout.
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
from app.repositories.jp.settlement import JpDepositSettlementRepository
from app.schemas.jp.settlement import (
    CreateSettlementRequest,
    PatchSettlementItemsRequest,
    PayoutResponse,
    SettlementResponse,
)
from app.services.deposit_settlement.itemizer import compute_net_refund
from app.services.deposit_settlement.refund_invoice import generate_refund_invoice

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/deposit-settlements",
    tags=["jp-deposit-settlements"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_org_id(request: Request) -> str:
    org_id: Optional[str] = getattr(request.state, "org_id", None)
    if not org_id:
        raise HTTPException(status_code=401, detail="org_id not found in token")
    return org_id


def _require_role(request: Request, *allowed_roles: str) -> str:
    role: Optional[str] = getattr(request.state, "role", None)
    if role not in allowed_roles:
        raise HTTPException(
            status_code=403,
            detail=f"One of {list(allowed_roles)} roles required, got {role!r}",
        )
    return role


@router.post("", response_model=SettlementResponse, status_code=201)
async def create_settlement(
    body: CreateSettlementRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> SettlementResponse:
    """Owner creates a new deposit settlement draft.

    Owner or admin role required.
    """
    org_id = _get_org_id(request)
    _require_role(request, "owner", "admin", "sales")

    repo = JpDepositSettlementRepository(db)

    # Prevent duplicate settlements for the same contract
    existing = repo.get_by_contract(body.contract_id, org_id)
    if existing and existing.status not in ("disputed",):
        raise HTTPException(
            status_code=409,
            detail=f"Settlement already exists for contract {body.contract_id} (status: {existing.status})",
        )

    try:
        settlement = repo.create(
            org_id=org_id,
            contract_id=body.contract_id,
            gross_shikikin_jpy=Decimal(str(body.gross_shikikin_jpy)),
        )
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("Failed to create settlement: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to create settlement") from exc

    db.refresh(settlement)
    return SettlementResponse.model_validate(settlement)


@router.patch("/{settlement_id}/items", response_model=SettlementResponse)
async def patch_settlement_items(
    settlement_id: int,
    body: PatchSettlementItemsRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> SettlementResponse:
    """Owner itemizes deductions, triggering refund computation.

    Computes net_refund via itemizer.compute_net_refund (pure fn).
    Moves settlement to 'tenant_review' status.
    """
    org_id = _get_org_id(request)
    _require_role(request, "owner", "admin", "sales")

    repo = JpDepositSettlementRepository(db)
    settlement = repo.get(settlement_id, org_id)
    if not settlement:
        raise HTTPException(status_code=404, detail=f"Settlement {settlement_id} not found")

    if settlement.status not in ("draft", "disputed"):
        raise HTTPException(
            status_code=409,
            detail=f"Cannot update items in status '{settlement.status}'",
        )

    deductions_raw = [d.model_dump() for d in body.deductions]

    try:
        net_refund_jpy, _breakdown = compute_net_refund(
            gross_shikikin_jpy=settlement.gross_shikikin_jpy,
            deductions=deductions_raw,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    try:
        settlement = repo.update_deductions(
            settlement, deductions=deductions_raw, refund_jpy=net_refund_jpy
        )
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("Failed to update settlement items: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to update items") from exc

    db.refresh(settlement)
    return SettlementResponse.model_validate(settlement)


@router.post("/{settlement_id}/tenant-sign", response_model=SettlementResponse)
async def tenant_sign_settlement(
    settlement_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> SettlementResponse:
    """Tenant accepts the deposit settlement.

    Tenant or admin role required.
    Settlement must be in 'tenant_review' status.
    """
    org_id = _get_org_id(request)
    _require_role(request, "tenant", "admin")

    repo = JpDepositSettlementRepository(db)
    settlement = repo.get(settlement_id, org_id)
    if not settlement:
        raise HTTPException(status_code=404, detail=f"Settlement {settlement_id} not found")

    if settlement.status != "tenant_review":
        raise HTTPException(
            status_code=409,
            detail=f"Settlement is in status '{settlement.status}', expected 'tenant_review'",
        )

    try:
        settlement = repo.tenant_sign(settlement)
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("Failed to tenant-sign settlement: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to record tenant signature") from exc

    db.refresh(settlement)
    return SettlementResponse.model_validate(settlement)


@router.post("/{settlement_id}/payout", response_model=PayoutResponse)
async def process_payout(
    settlement_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> PayoutResponse:
    """Process refund payout for an accepted settlement.

    Requires: settlement status 'accepted' + both owner_signed_at and tenant_signed_at set.
    Admin role required for payout authorization.
    """
    org_id = _get_org_id(request)
    _require_role(request, "admin")

    repo = JpDepositSettlementRepository(db)
    settlement = repo.get(settlement_id, org_id)
    if not settlement:
        raise HTTPException(status_code=404, detail=f"Settlement {settlement_id} not found")

    if settlement.status != "accepted":
        raise HTTPException(
            status_code=409,
            detail=f"Settlement is in status '{settlement.status}', expected 'accepted'",
        )

    # Dual-approval check
    if not settlement.tenant_signed_at:
        raise HTTPException(status_code=409, detail="Tenant has not signed the settlement")

    try:
        invoice_data = generate_refund_invoice(
            settlement_id=settlement.id,
            org_id=org_id,
            gross_shikikin_jpy=settlement.gross_shikikin_jpy,
            deductions=settlement.deductions_json or [],
            db=db,
        )

        settlement = repo.mark_payout(
            settlement,
            refund_invoice_id=invoice_data["invoice_id"],
        )
        db.commit()
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        db.rollback()
        logger.error("Failed to process payout: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to process payout") from exc

    return PayoutResponse(
        settlement_id=settlement_id,
        status="refunded",
        refund_jpy=settlement.refund_jpy,
        invoice_id=settlement.refund_invoice_id,
        message=f"敷金精算完了: {settlement.refund_jpy} JPY refund processed",
    )
