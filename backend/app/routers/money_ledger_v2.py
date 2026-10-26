"""P09 record-only ledger and reconciliation API.

This router records evidence and accounting allocations.  It never calls a
bank/gateway and never changes a legacy Invoice/Reservation payment status.
"""

from datetime import datetime
from typing import Literal, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import auth, models
from app.config import settings
from app.database import get_db
from app.services.evidence_policy import validate_urls

router = APIRouter(prefix="/api/v2/money-ledger", tags=["money-ledger-v2"])


class AllocationIn(BaseModel):
    allocation_type: Literal["OWNER_NET", "PLATFORM_FEE", "SALE_COMMISSION", "TAX", "OTHER"]
    beneficiary_user_id: Optional[int] = None
    amount: float = Field(ge=0)
    rule_version: Optional[str] = None


class PaymentRecordIn(BaseModel):
    source_type: Literal["INVOICE", "RESERVATION", "RENTAL_DEPOSIT", "BUY_SELL_DEPOSIT"]
    source_id: int = Field(gt=0)
    payer_user_id: Optional[int] = None
    amount: float = Field(gt=0)
    method: Literal["MANUAL_PROOF", "CASH", "BANK_TRANSFER"] = "MANUAL_PROOF"
    external_reference: str = Field(min_length=3, max_length=120)
    evidence_urls: list[str] = Field(default_factory=list, max_length=10)
    paid_at: datetime
    allocations: list[AllocationIn] = Field(min_length=1)


class RefundIn(BaseModel):
    amount: float = Field(gt=0)
    reason_code: Literal["CUSTOMER_CANCELLED", "OWNER_CANCELLED", "OVERPAYMENT", "SERVICE_FAILURE", "OTHER"]
    note: str = Field(default="", max_length=2000)


def _enabled() -> None:
    if not settings.money_ledger_v2_enabled:
        raise HTTPException(404, "Money ledger v2 chưa được bật")


def _admin(claims: dict) -> int:
    if claims.get("role") != "admin":
        raise HTTPException(403, "Chỉ Admin đối soát được sổ tiền")
    return claims["sub"]


def _key(value: Optional[str]) -> str:
    value = (value or "").strip()
    if not 8 <= len(value) <= 128: raise HTTPException(400, "Idempotency-Key phải có từ 8 đến 128 ký tự")
    return value


def _payment_dict(db: Session, item: models.PlatformPayment) -> dict:
    allocations = db.query(models.PaymentAllocation).filter(models.PaymentAllocation.payment_id == item.id).all()
    refunds = db.query(models.MoneyRefund).filter(models.MoneyRefund.payment_id == item.id).all()
    allocated = sum(x.amount for x in allocations); refunded = sum(x.amount for x in refunds)
    return {"id": item.id, "source_type": item.source_type, "source_id": item.source_id, "payer_user_id": item.payer_user_id, "amount": item.amount, "currency": item.currency, "status": item.status, "method": item.method, "external_reference": item.external_reference, "evidence_urls": item.evidence_urls, "paid_at": item.paid_at.isoformat(), "allocated_amount": allocated, "refunded_amount": refunded, "balance": item.amount - refunded, "balanced": abs(item.amount - allocated) < 0.01, "allocations": [{"id": x.id, "type": x.allocation_type, "beneficiary_user_id": x.beneficiary_user_id, "amount": x.amount, "rule_version": x.rule_version} for x in allocations]}


@router.post("/payments", status_code=201)
def record_payment(body: PaymentRecordIn, idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"), claims: dict = Depends(auth.require_user), db: Session = Depends(get_db)):
    _enabled(); uid = _admin(claims); key = _key(idempotency_key)
    replay = db.query(models.ActivityAuditEvent).filter(models.ActivityAuditEvent.actor_user_id == uid, models.ActivityAuditEvent.action == "MONEY_PAYMENT_RECORD", models.ActivityAuditEvent.idempotency_key == key).first()
    if replay: return {**_payment_dict(db, db.get(models.PlatformPayment, replay.target_id)), "idempotent_replay": True}
    if abs(sum(x.amount for x in body.allocations) - body.amount) >= .01:
        raise HTTPException(422, "Tổng allocation phải bằng payment amount")
    existing = db.query(models.PlatformPayment).filter(models.PlatformPayment.source_type == body.source_type, models.PlatformPayment.source_id == body.source_id, models.PlatformPayment.external_reference == body.external_reference).first()
    if existing: raise HTTPException(409, "Mã chứng từ đã tồn tại cho nguồn tiền này")
    item = models.PlatformPayment(source_type=body.source_type, source_id=body.source_id, payer_user_id=body.payer_user_id, amount=body.amount, method=body.method, external_reference=body.external_reference, evidence_urls=validate_urls(body.evidence_urls), recorded_by_user_id=uid, paid_at=body.paid_at.replace(tzinfo=None))
    db.add(item); db.flush()
    for allocation in body.allocations: db.add(models.PaymentAllocation(payment_id=item.id, allocation_type=allocation.allocation_type, beneficiary_user_id=allocation.beneficiary_user_id, amount=allocation.amount, rule_version=allocation.rule_version))
    db.add(models.ActivityAuditEvent(actor_user_id=uid, action="MONEY_PAYMENT_RECORD", idempotency_key=key, target_type="platform_payment", target_id=item.id, payload={"amount": body.amount, "source_type": body.source_type, "source_id": body.source_id, "record_only": True}))
    db.commit(); return _payment_dict(db, item)


@router.post("/payments/{payment_id}/refunds", status_code=201)
def record_refund(payment_id: int, body: RefundIn, idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"), claims: dict = Depends(auth.require_user), db: Session = Depends(get_db)):
    _enabled(); uid = _admin(claims); key = _key(idempotency_key)
    item = db.get(models.PlatformPayment, payment_id)
    if item is None: raise HTTPException(404, "Không tìm thấy payment")
    replay = db.query(models.ActivityAuditEvent).filter(models.ActivityAuditEvent.actor_user_id == uid, models.ActivityAuditEvent.action == "MONEY_REFUND_RECORD", models.ActivityAuditEvent.idempotency_key == key).first()
    if replay: return {**_payment_dict(db, item), "idempotent_replay": True}
    refunded = db.query(func.coalesce(func.sum(models.MoneyRefund.amount), 0)).filter(models.MoneyRefund.payment_id == item.id).scalar()
    if float(refunded or 0) + body.amount > item.amount + .009: raise HTTPException(422, "Tổng hoàn tiền không thể vượt payment gốc")
    refund = models.MoneyRefund(payment_id=item.id, amount=body.amount, reason_code=body.reason_code, note=body.note, recorded_by_user_id=uid)
    db.add(refund); db.flush(); db.add(models.ActivityAuditEvent(actor_user_id=uid, action="MONEY_REFUND_RECORD", idempotency_key=key, target_type="money_refund", target_id=refund.id, payload={"payment_id": item.id, "amount": body.amount}))
    db.commit(); return _payment_dict(db, item)


@router.get("/payments")
def payments(source_type: Optional[str] = None, source_id: Optional[int] = None, limit: int = Query(default=50, ge=1, le=100), offset: int = Query(default=0, ge=0), claims: dict = Depends(auth.require_user), db: Session = Depends(get_db)):
    _enabled(); _admin(claims); query = db.query(models.PlatformPayment)
    if source_type: query = query.filter(models.PlatformPayment.source_type == source_type)
    if source_id: query = query.filter(models.PlatformPayment.source_id == source_id)
    total = query.count(); rows = query.order_by(models.PlatformPayment.paid_at.desc(), models.PlatformPayment.id.desc()).offset(offset).limit(limit).all()
    return {"items": [_payment_dict(db, x) for x in rows], "total": total, "limit": limit, "offset": offset, "mode": "RECORD_ONLY_NO_AUTO_TRANSFER"}


@router.get("/legacy-adapter")
def legacy_adapter(claims: dict = Depends(auth.require_user), db: Session = Depends(get_db)):
    """Read-only proof that legacy money remains visible before backfill."""
    _enabled(); _admin(claims)
    invoice_total = db.query(func.coalesce(func.sum(models.Payment.amount), 0)).scalar()
    reservation_total = db.query(func.coalesce(func.sum(models.ReservationThanhToan.so_tien), 0)).scalar()
    return {"invoice_payment_total": float(invoice_total or 0), "reservation_payment_total": float(reservation_total or 0), "mutated_legacy_rows": 0, "adapter_only": True}


@router.get("/reconciliation")
def reconciliation(claims: dict = Depends(auth.require_user), db: Session = Depends(get_db)):
    _enabled(); _admin(claims)
    payment = float(db.query(func.coalesce(func.sum(models.PlatformPayment.amount), 0)).scalar() or 0)
    allocation = float(db.query(func.coalesce(func.sum(models.PaymentAllocation.amount), 0)).scalar() or 0)
    refund = float(db.query(func.coalesce(func.sum(models.MoneyRefund.amount), 0)).scalar() or 0)
    return {"payment_total": payment, "allocation_total": allocation, "refund_total": refund, "net_total": payment - refund, "allocation_difference": payment - allocation, "balanced": abs(payment - allocation) < .01, "transfer_execution": "DISABLED"}
