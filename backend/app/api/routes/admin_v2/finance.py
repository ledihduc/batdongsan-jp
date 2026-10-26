"""Admin V2 — Tài chính: GHI NHẬN và ĐỐI SOÁT (không chuyển tiền).

- Cọc hành trình thuê: danh sách + xác minh chứng từ (record-only, xem
  `verify_deposit`).
- Sổ tiền: ghi nhận thanh toán, ghi nhận hoàn tiền (≥ ngưỡng → maker-checker),
  đánh dấu đã đối soát, bảng đối soát.
- Hoá đơn, hoàn tiền, hoa hồng, quyết toán chủ nhà: chỉ đọc.
- Chính sách cọc: xem / tạo phiên bản mới (`policies.manage`).

Khác sổ tiền cũ (`/api/v2/money-ledger/*`): KHÔNG phụ thuộc cờ
`MONEY_LEDGER_V2_ENABLED` — đây là công cụ nội bộ có RBAC + nhật ký riêng, cờ
đó chỉ để mở/đóng API cũ cho JWT admin kiểu cũ.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Literal, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import String, cast, func, or_
from sqlalchemy.orm import Session

from app import models
from app.config import settings
from app.database import get_db
from app.routers.money_ledger_v2 import AllocationIn, PaymentRecordIn, RefundIn
from app.services import rental_journey_policy as policy
from app.services import rental_journey_service as rjs
from app.services.admin_v2 import change_requests
from app.services.admin_v2 import finance_ops as fo
from app.services.admin_v2 import rentals_ops as ro
from app.services.admin_v2.core import (
    AdminContext, CommandResult, PageParams, fail, idempotency_key, if_match, iso, one, page_params, paged,
    paginate, require_permission, run_command, user_brief, utcnow,
)
from app.services.admin_v2.permissions import REFUND_DUAL_APPROVAL_THRESHOLD

router = APIRouter(prefix="/api/v2/admin", tags=["admin-v2-finance"])

READ = "payments.read"
RECORD = "payments.record"
REFUND = "payments.refund"
RECONCILE = "payments.reconcile"
POLICY = "policies.manage"


# ── Tổng quan ─────────────────────────────────────────────────────────────────


@router.get("/finance/overview")
def finance_overview(
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    I = models.Invoice
    reconciled = db.query(models.AdminCase.source_id).filter(
        models.AdminCase.source_type == fo.RECONCILE_CASE, models.AdminCase.status == "done")
    settlements = fo.grouped(db, models.OwnerSettlement.status, models.OwnerSettlement.net_amount)
    return one({
        "totals": fo.ledger_summary(db),
        "counts": {
            "deposits_awaiting_verification": fo.deposit_unverified_query(db).order_by(None).count(),
            "invoices_overdue": db.query(func.count(I.id)).filter(*fo.invoice_overdue_filter()).scalar() or 0,
            "allocation_mismatches": fo.mismatch_query(db).order_by(None).count(),
            "payments_unreconciled": db.query(func.count(models.PlatformPayment.id)).filter(
                cast(models.PlatformPayment.id, String).notin_(reconciled)).scalar() or 0,
            "refunds_pending_approval": db.query(func.count(models.AdminChangeRequest.id)).filter(
                models.AdminChangeRequest.kind == fo.REFUND_KIND,
                models.AdminChangeRequest.status == "PENDING").scalar() or 0,
        },
        "commissions_by_status": fo.grouped(db, models.SaleCommission.status, models.SaleCommission.amount),
        "payouts_by_status": fo.grouped(db, models.CommissionPayout.status, models.CommissionPayout.amount),
        "settlements_by_status": settlements,
        "settlements_pending_manual": settlements.get("PENDING_MANUAL", {"count": 0, "amount": 0}),
        "refund_dual_approval_threshold": REFUND_DUAL_APPROVAL_THRESHOLD,
        "transfer_execution": fo.TRANSFER_EXECUTION,
        "note": fo.RECORD_ONLY_NOTE,
        "legacy_money_ledger_api_enabled": bool(settings.money_ledger_v2_enabled),
    })


# ── Cọc hành trình thuê ───────────────────────────────────────────────────────


class VerifyDepositBody(BaseModel):
    decision: Literal["verified", "rejected"]
    reason: str = Field("", max_length=500)
    #: Chỉ với OWNER_DEPOSIT: ghi luôn "đã nhận cọc" thay chủ nhà qua đường
    #: admin của policy miền (khi chủ nhà xác nhận ngoài app, vd. qua điện thoại).
    #: Mặc định KHÔNG — tài chính xem được ảnh chứ không biết tiền đã vào tài
    #: khoản chủ nhà hay chưa.
    acknowledge_owner_deposit: bool = False


def _deposit(db: Session, deposit_id: int) -> models.RentalJourneyPayment:
    p = db.get(models.RentalJourneyPayment, deposit_id)
    if p is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy khoản cọc")
    return p


@router.get("/finance/deposits")
def list_deposits(
    status: str = Query("", pattern="^(|PENDING|SUBMITTED|ACKNOWLEDGED)$"),
    kind: str = Query("", pattern="^(|APP_DEPOSIT|OWNER_DEPOSIT)$"),
    verification: str = Query("", pattern="^(|unverified|verified|rejected)$"),
    journey_id: Optional[int] = None,
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    RP, C = models.RentalJourneyPayment, models.AdminCase
    query = db.query(RP)
    if status:
        query = query.filter(RP.status == status)
    if kind:
        query = query.filter(RP.kind == kind)
    if journey_id:
        query = query.filter(RP.journey_id == journey_id)
    if verification:
        def ids_with(case_status):
            return db.query(C.source_id).filter(C.source_type == ro.DEPOSIT_CASE, C.status == case_status)

        if verification == "verified":
            query = query.filter(cast(RP.id, String).in_(ids_with("done")))
        elif verification == "rejected":
            query = query.filter(cast(RP.id, String).in_(ids_with("waiting")))
        else:
            query = query.filter(cast(RP.id, String).notin_(
                db.query(C.source_id).filter(C.source_type == ro.DEPOSIT_CASE, C.status.in_(("done", "waiting")))))
    rows, total = paginate(query.order_by(RP.submitted_at.is_(None), RP.submitted_at.desc(), RP.id.desc()), page)
    ids = [p.id for p in rows]
    journeys = {j.id: j for j in db.query(models.RentalJourney).filter(
        models.RentalJourney.id.in_({p.journey_id for p in rows}))} if rows else {}
    verify = ro.verifications(db, ids)
    cases = ro.deposit_cases(db, ids)
    cache: dict = {}
    return paged(
        [ro.deposit_row(db, p, journeys.get(p.journey_id), verify.get(p.id), cases.get(p.id), cache) for p in rows],
        total=total, page=page,
    )


def _deposit_detail(db: Session, ctx: AdminContext, p: models.RentalJourneyPayment) -> dict:
    j = db.get(models.RentalJourney, p.journey_id)
    cache: dict = {}
    allow_docs = ctx.has("rental_documents.read")
    case = ro.deposit_cases(db, [p.id]).get(p.id)
    others = ro.payments_of(db, [p.journey_id]).get(p.journey_id, {})
    return {
        **ro.deposit_row(db, p, j, ro.verifications(db, [p.id]).get(p.id), case, cache),
        "proofs": ro.docs(p.proof_urls, allow_docs),
        "documents_redacted": not allow_docs,
        "journey": None if j is None else {
            "id": j.id, "ref": ro.ref("HT", j.id), "status": j.status,
            "status_label": ro.JOURNEY_STATUS_LABELS.get(j.status, j.status),
            "total_deposit": ro.vnd(j.total_deposit), "sale": user_brief(db, j.sale_id, cache),
            "title": ro.place(db, j.house_id, j.room_id)["title"],
        },
        "sibling_deposits": [
            {"id": o.id, "kind": o.kind, "amount": ro.vnd(o.amount), "status": o.status}
            for k, o in sorted(others.items()) if o.id != p.id
        ],
        "ledger_payments": [
            {"id": x.id, "ref": ro.ref("TT", x.id), "amount": ro.vnd(x.amount), "paid_at": iso(x.paid_at)}
            for x in db.query(models.PlatformPayment).filter(
                models.PlatformPayment.source_type == "RENTAL_DEPOSIT",
                models.PlatformPayment.source_id == p.id).limit(20)
        ],
        "can_acknowledge_owner_deposit": _admin_can_ack(db, p, j),
    }


def _admin_can_ack(db: Session, p: models.RentalJourneyPayment, j: Optional[models.RentalJourney]) -> bool:
    if j is None or p.kind != "OWNER_DEPOSIT":
        return False
    pays = ro.payments_of(db, [j.id]).get(j.id, {})
    own = pays.get("OWNER_DEPOSIT")
    return policy.ACKNOWLEDGE_OWNER_DEPOSIT in policy.available_actions(
        actor="admin", status=j.status, has_contract=bool(j.contract_urls),
        has_app_proof=ro.has_proof(pays.get("APP_DEPOSIT")), has_owner_proof=ro.has_proof(own),
        owner_proof_acknowledged=bool(own and own.acknowledged_at),
    )


@router.get("/finance/deposits/{deposit_id}")
def get_deposit(
    deposit_id: int,
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    return one(_deposit_detail(db, ctx, _deposit(db, deposit_id)))


@router.post("/finance/deposits/{deposit_id}/verify")
def verify_deposit(
    deposit_id: int,
    body: VerifyDepositBody,
    ctx: AdminContext = Depends(require_permission(RECONCILE)),
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    db: Session = Depends(get_db),
):
    """Tài chính kết luận chứng từ cọc — RECORD-ONLY.

    Miền không có bước "nền tảng xác nhận cọc nền tảng" (APP_DEPOSIT): chỉ chủ
    nhà (hoặc admin thay chủ nhà) xác nhận OWNER_DEPOSIT. Nên kết luận ở đây
    KHÔNG đổi trạng thái hồ sơ hay khoản cọc; nó sống ở `admin_cases`
    (deposit_review: done = đã xác minh, waiting = từ chối chờ nộp lại) + nhật
    ký quản trị. Ngoại lệ có chủ đích: `acknowledge_owner_deposit=true` gọi
    đúng đường admin của policy miền.
    """
    p = _deposit(db, deposit_id)
    if not ro.has_proof(p):
        raise fail(409, "ADMIN_DEPOSIT_NO_PROOF", "Khoản cọc chưa có minh chứng để xác minh")
    if body.acknowledge_owner_deposit and (body.decision != "verified" or p.kind != "OWNER_DEPOSIT"):
        raise fail(422, "ADMIN_VALIDATION", "Chỉ xác nhận thay chủ nhà khi xác minh ĐẠT khoản cọc chủ nhà")
    state: dict = {}

    def do() -> CommandResult:
        j = db.get(models.RentalJourney, p.journey_id)
        acked = False
        if body.acknowledge_owner_deposit:
            if p.acknowledged_at is not None:
                raise fail(409, "ADMIN_CONFLICT", "Chủ nhà đã xác nhận nhận cọc")
            ro.domain(rjs.acknowledge_owner_deposit_staged, db, ctx.legacy_claims(), journey_id=p.journey_id)
            acked = True
            state["ack"] = True
        case = fo.get_or_create_case(db, ro.DEPOSIT_CASE, p.id, priority="high")
        reason = body.reason.strip()
        label = "Đã xác minh chứng từ cọc" if body.decision == "verified" else "Chứng từ cọc không đạt"
        fo.touch_case(
            db, case, actor=ctx.user_id, kind="deposit_verification",
            status="done" if body.decision == "verified" else "waiting",
            note=f"{label}" + (f": {reason}" if reason else ""),
            payload={"decision": body.decision, "reason": reason or None, "domain_acknowledged": acked,
                     "submitted_at": iso(p.submitted_at)},
        )
        db.flush()
        cache: dict = {}
        data = _deposit_detail(db, ctx, p)
        # Nhật ký của lệnh này chỉ được ghi SAU fn → tự dựng kết luận vừa ra.
        data["admin_verification"] = {
            "decision": body.decision, "by": user_brief(db, ctx.user_id, cache), "at": iso(utcnow()),
            "reason": reason or None, "domain_acknowledged": acked, "stale": False,
        }
        return CommandResult(
            data=data, before={"status": p.status},
            after={"decision": body.decision, "domain_acknowledged": acked, "status": p.status,
                   "journey_status": j.status if j else None},
            event_status=body.decision,
        )

    out = run_command(
        db, ctx, action=ro.DEPOSIT_VERIFY_ACTION, permission=RECONCILE, entity_type=ro.DEPOSIT_ENTITY,
        entity_id=deposit_id, key=key, fn=do, reason=body.reason, reason_required=body.decision == "rejected",
        expected_version=expected,
        current_version=lambda: ro.deposit_version(p, ro.deposit_cases(db, [p.id]).get(p.id)),
        event_type="admin.finance.deposit_verified",
    )
    if state.get("ack"):
        j = db.get(models.RentalJourney, p.journey_id)
        ro.publish_safely(rjs.publish_journey_status, j, from_status=j.status, actor_id=ctx.user_id,
                          action="OWNER_DEPOSIT_ACKNOWLEDGED")
    return out


# ── Sổ tiền: thanh toán ───────────────────────────────────────────────────────


class AllocationBody(BaseModel):
    allocation_type: AllocationIn.model_fields["allocation_type"].annotation  # type: ignore[valid-type]
    beneficiary_user_id: Optional[int] = None
    amount: int = Field(ge=0)
    rule_version: Optional[str] = Field(None, max_length=50)


class PaymentBody(BaseModel):
    source_type: PaymentRecordIn.model_fields["source_type"].annotation  # type: ignore[valid-type]
    source_id: int = Field(gt=0)
    payer_user_id: Optional[int] = None
    amount: int = Field(gt=0)
    method: PaymentRecordIn.model_fields["method"].annotation = "MANUAL_PROOF"  # type: ignore[valid-type]
    external_reference: str = Field(min_length=3, max_length=120)
    evidence_urls: list[str] = Field(default_factory=list, max_length=10)
    paid_at: datetime
    allocations: list[AllocationBody] = Field(min_length=1, max_length=10)
    #: Ghi chú nội bộ → cột lý do của nhật ký quản trị.
    note: str = Field("", max_length=500)


class RefundBody(BaseModel):
    amount: int = Field(gt=0)
    reason_code: RefundIn.model_fields["reason_code"].annotation  # type: ignore[valid-type]
    note: str = Field("", max_length=2000)
    reason: str = Field("", max_length=500)


class ReconcileBody(BaseModel):
    note: str = Field("", max_length=500)


def _payment(db: Session, payment_id: int) -> models.PlatformPayment:
    p = db.get(models.PlatformPayment, payment_id)
    if p is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy khoản thanh toán")
    return p


def _payment_version(db: Session, p: models.PlatformPayment) -> str:
    return fo.payment_rows(db, [p])[0]["version"]


@router.get("/finance/payments")
def list_payments(
    source_type: str = Query("", max_length=30),
    source_id: Optional[int] = None,
    status: str = Query("", max_length=20),
    method: str = Query("", max_length=30),
    payer_user_id: Optional[int] = None,
    mismatch: Optional[bool] = None,
    refunded: Optional[bool] = None,
    reconciled: Optional[bool] = None,
    paid_from: Optional[str] = Query(None, max_length=25),
    paid_to: Optional[str] = Query(None, max_length=25),
    q: str = Query("", max_length=120),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    P = models.PlatformPayment
    a, r = fo.alloc_sums(db), fo.refund_sums(db)
    query = db.query(P).outerjoin(a, a.c.pid == P.id).outerjoin(r, r.c.pid == P.id)
    if source_type:
        if source_type not in fo.SOURCE_TYPES:
            raise fail(422, "ADMIN_BAD_FILTER", "Loại nguồn tiền không hợp lệ")
        query = query.filter(P.source_type == source_type)
    if source_id:
        query = query.filter(P.source_id == source_id)
    if status:
        query = query.filter(P.status == status)
    if method:
        query = query.filter(P.method == method)
    if payer_user_id:
        query = query.filter(P.payer_user_id == payer_user_id)
    diff = func.abs(P.amount - func.coalesce(a.c.s, 0))
    if mismatch is True:
        query = query.filter(diff >= 1)
    elif mismatch is False:
        query = query.filter(diff < 1)
    if refunded is True:
        query = query.filter(func.coalesce(r.c.s, 0) > 0)
    elif refunded is False:
        query = query.filter(func.coalesce(r.c.s, 0) == 0)
    done = db.query(models.AdminCase.source_id).filter(
        models.AdminCase.source_type == fo.RECONCILE_CASE, models.AdminCase.status == "done")
    if reconciled is True:
        query = query.filter(cast(P.id, String).in_(done))
    elif reconciled is False:
        query = query.filter(cast(P.id, String).notin_(done))
    d1, d2 = fo.parse_dt(paid_from, "paid_from"), fo.parse_dt(paid_to, "paid_to")
    if d1:
        query = query.filter(P.paid_at >= d1.replace(tzinfo=None))
    if d2:
        query = query.filter(P.paid_at <= d2.replace(tzinfo=None))
    term = q.strip()
    if term:
        conds = [func.lower(P.external_reference).like(f"%{term.lower()}%")]
        t = term.upper().removeprefix("TT-")
        if t.isdigit():
            conds.append(P.id == int(t))
        query = query.filter(or_(*conds))
    rows, total = paginate(query.order_by(P.paid_at.desc(), P.id.desc()), page)
    return paged(fo.payment_rows(db, rows), total=total, page=page)


@router.get("/finance/payments/{payment_id}")
def get_payment(
    payment_id: int,
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    return one(fo.payment_detail(db, ctx, _payment(db, payment_id)))


@router.post("/finance/payments")
def record_payment(
    body: PaymentBody,
    ctx: AdminContext = Depends(require_permission(RECORD)),
    key: str = Depends(idempotency_key),
    db: Session = Depends(get_db),
):
    """Ghi nhận thanh toán — tiền ĐÃ đổi tay ở ngoài; hệ thống chỉ lưu chứng từ."""

    def do() -> CommandResult:
        item = fo.record_payment(db, ctx, body)
        return CommandResult(
            data=fo.payment_detail(db, ctx, item), entity_id=item.id,
            after={"amount": body.amount, "source_type": body.source_type, "source_id": body.source_id,
                   "external_reference": body.external_reference, "record_only": True},
            event_status=item.status,
        )

    return run_command(
        db, ctx, action="payment.record", permission=RECORD, entity_type="platform_payment", entity_id=None,
        key=key, fn=do, reason=body.note, event_type="admin.finance.payment_recorded",
    )


@router.post("/finance/payments/{payment_id}/refund-records")
def record_refund(
    payment_id: int,
    body: RefundBody,
    ctx: AdminContext = Depends(require_permission(REFUND)),
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    db: Session = Depends(get_db),
):
    """Ghi nhận hoàn tiền. Từ ngưỡng `REFUND_DUAL_APPROVAL_THRESHOLD` trở lên chỉ
    tạo yêu cầu — một người KHÁC có `payments.refund` duyệt thì mới ghi sổ."""
    p = _payment(db, payment_id)

    def do() -> CommandResult:
        fo.ensure_refundable(db, p, body.amount, include_pending=True)
        if body.amount >= REFUND_DUAL_APPROVAL_THRESHOLD:
            cr = change_requests.create(
                db, ctx, kind=fo.REFUND_KIND, reason=body.reason.strip(),
                payload={"payment_id": p.id, "amount": body.amount, "reason_code": body.reason_code,
                         "note": body.note.strip(), "requested_by": ctx.user_id},
            )
            return CommandResult(
                data={"pending_approval": True, "change_request": change_requests.to_dict(db, cr),
                      "refund": None, "payment": fo.payment_detail(db, ctx, p)},
                after={"change_request_id": cr.id, "amount": body.amount}, event_status="PENDING",
            )
        r = fo.add_refund(db, p, amount=body.amount, reason_code=body.reason_code, note=body.note.strip(),
                          recorded_by=ctx.user_id)
        return CommandResult(
            data={"pending_approval": False, "change_request": None, "refund": fo.refund_dto(db, r, {}),
                  "payment": fo.payment_detail(db, ctx, p)},
            after={"refund_id": r.id, "amount": body.amount, "reason_code": body.reason_code},
            event_status="RECORDED",
        )

    return run_command(
        db, ctx, action="payment.refund_record", permission=REFUND, entity_type="platform_payment",
        entity_id=payment_id, key=key, fn=do, reason=body.reason, reason_required=True,
        expected_version=expected, current_version=lambda: _payment_version(db, p),
        event_type="admin.finance.refund_recorded",
    )


@router.post("/finance/payments/{payment_id}/reconcile")
def reconcile_payment(
    payment_id: int,
    body: ReconcileBody,
    ctx: AdminContext = Depends(require_permission(RECONCILE)),
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    db: Session = Depends(get_db),
):
    """Đánh dấu đã đối soát. Sổ tiền không có cột cho việc này (bảng bất biến),
    nên dấu nằm ở `admin_cases` (payment_reconcile = done) + nhật ký quản trị."""
    p = _payment(db, payment_id)

    def do() -> CommandResult:
        row = fo.payment_rows(db, [p])[0]
        if row["reconciled"] is not None:
            raise fail(409, "ADMIN_CONFLICT", "Khoản này đã được đánh dấu đối soát")
        if row["mismatch"]:
            raise fail(409, "ADMIN_LEDGER_UNBALANCED", "Phân bổ chưa cân với số tiền — chưa thể đánh dấu đã đối soát",
                       {"allocation_difference": row["allocation_difference"]})
        case = fo.get_or_create_case(db, fo.RECONCILE_CASE, p.id)
        note = body.note.strip()
        fo.touch_case(db, case, actor=ctx.user_id, kind="reconciled", status="done",
                      note="Đã đối soát" + (f": {note}" if note else ""),
                      payload={"note": note or None, "amount": row["amount"], "refunded": row["refunded_amount"]})
        db.flush()
        return CommandResult(data=fo.payment_detail(db, ctx, p), after={"reconciled": True}, event_status="reconciled")

    return run_command(
        db, ctx, action="payment.reconcile", permission=RECONCILE, entity_type="platform_payment",
        entity_id=payment_id, key=key, fn=do, reason=body.note, expected_version=expected,
        current_version=lambda: _payment_version(db, p), event_type="admin.finance.payment_reconciled",
    )


@router.get("/finance/reconciliation")
def reconciliation(
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    """Cân đối toàn sổ (meta.summary) + danh sách khoản lệch phân bổ (data)."""
    P = models.PlatformPayment
    rows, total = paginate(fo.mismatch_query(db).order_by(P.paid_at.desc(), P.id.desc()), page)
    return paged(fo.payment_rows(db, rows), total=total, page=page, summary=fo.ledger_summary(db),
                 note=fo.RECORD_ONLY_NOTE)


# ── Chỉ đọc: hoá đơn, hoàn tiền, hoa hồng, quyết toán ─────────────────────────


@router.get("/finance/invoices")
def list_invoices(
    status: str = Query("", pattern="^(|draft|sent|paid|overdue|cancelled|void)$"),
    overdue: Optional[bool] = None,
    host_id: Optional[int] = None,
    contract_id: Optional[int] = None,
    period: str = Query("", pattern=r"^(|\d{4}-\d{2})$"),
    q: str = Query("", max_length=60),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    I = models.Invoice
    query = db.query(I)
    if status:
        query = query.filter(I.status == status)
    if overdue is True:
        query = query.filter(*fo.invoice_overdue_filter())
    elif overdue is False:
        query = query.filter(~(I.status.notin_(ro.INVOICE_OPEN_EXCLUDED) & (I.due_date < fo.today_iso())))
    if host_id:
        query = query.filter(I.host_id == host_id)
    if contract_id:
        query = query.filter(I.contract_id == contract_id)
    if period:
        query = query.filter(I.period_start.like(f"{period}%"))
    if q.strip():
        query = query.filter(func.lower(I.invoice_number).like(f"%{q.strip().lower()}%"))
    rows, total = paginate(query.order_by(I.due_date.desc(), I.id.desc()), page)
    contracts = {c.id: c for c in db.query(models.Contract).filter(
        models.Contract.id.in_({i.contract_id for i in rows}))} if rows else {}
    today = fo.today_iso()
    cache: dict = {}
    data = []
    for i in rows:
        c = contracts.get(i.contract_id)
        pl = ro.place(db, None, c.room_id) if c else {"room": None, "building": None}
        data.append({**ro.invoice_brief(i, today), "host": user_brief(db, i.host_id, cache),
                     "contract_id": i.contract_id, "room": pl["room"], "building": pl["building"]})
    return paged(data, total=total, page=page)


@router.get("/finance/refunds")
def list_refunds(
    payment_id: Optional[int] = None,
    reason_code: str = Query("", max_length=40),
    date_from: Optional[str] = Query(None, max_length=25),
    date_to: Optional[str] = Query(None, max_length=25),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    M = models.MoneyRefund
    query = db.query(M)
    if payment_id:
        query = query.filter(M.payment_id == payment_id)
    if reason_code:
        query = query.filter(M.reason_code == reason_code)
    d1, d2 = fo.parse_dt(date_from, "date_from"), fo.parse_dt(date_to, "date_to")
    if d1:
        query = query.filter(M.created_at >= d1.replace(tzinfo=None))
    if d2:
        query = query.filter(M.created_at <= d2.replace(tzinfo=None))
    rows, total = paginate(query.order_by(M.id.desc()), page)
    pays = {p.id: p for p in db.query(models.PlatformPayment).filter(
        models.PlatformPayment.id.in_({r.payment_id for r in rows}))} if rows else {}
    cache: dict = {}
    data = []
    for r in rows:
        p = pays.get(r.payment_id)
        data.append({**fo.refund_dto(db, r, cache), "payment": None if p is None else {
            "id": p.id, "ref": ro.ref("TT", p.id), "source_type": p.source_type, "source_id": p.source_id,
            "amount": ro.vnd(p.amount), "payer": user_brief(db, p.payer_user_id, cache)}})
    pending = db.query(func.count(models.AdminChangeRequest.id)).filter(
        models.AdminChangeRequest.kind == fo.REFUND_KIND, models.AdminChangeRequest.status == "PENDING").scalar() or 0
    return paged(data, total=total, page=page, pending_approval=int(pending))


@router.get("/finance/commissions")
def list_commissions(
    status: str = Query("", max_length=24),
    sale_user_id: Optional[int] = None,
    source_type: str = Query("", max_length=30),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    S = models.SaleCommission
    query = db.query(S)
    if status:
        query = query.filter(S.status == status)
    if sale_user_id:
        query = query.filter(S.sale_user_id == sale_user_id)
    if source_type:
        query = query.filter(S.source_type == source_type)
    rows, total = paginate(query.order_by(S.recognized_at.desc(), S.id.desc()), page)
    payouts: dict[int, list] = {}
    if rows:
        for po in (db.query(models.CommissionPayout).filter(
                models.CommissionPayout.commission_id.in_([s.id for s in rows]))
                .order_by(models.CommissionPayout.id.asc()).limit(500)):
            payouts.setdefault(po.commission_id, []).append(po)
    cache: dict = {}
    data = [{
        "id": s.id, "ref": ro.ref("HH", s.id), "sale": user_brief(db, s.sale_user_id, cache),
        "source_type": s.source_type, "source_id": s.source_id, "amount": ro.vnd(s.amount), "status": s.status,
        "recognized_at": iso(s.recognized_at), "rule_snapshot": s.rule_snapshot or {},
        "payouts": [{"id": po.id, "amount": ro.vnd(po.amount), "status": po.status,
                     "external_reference": po.external_reference, "created_at": iso(po.created_at),
                     "paid_at": iso(po.paid_at)} for po in payouts.get(s.id, [])],
        "paid_out_amount": sum(ro.vnd(po.amount) or 0 for po in payouts.get(s.id, []) if po.paid_at),
    } for s in rows]
    return paged(data, total=total, page=page,
                 totals_by_status=fo.grouped(db, models.SaleCommission.status, models.SaleCommission.amount))


@router.get("/finance/settlements")
def list_settlements(
    status: str = Query("", max_length=20),
    owner_user_id: Optional[int] = None,
    period: str = Query("", pattern=r"^(|\d{4}-\d{2})$"),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    O = models.OwnerSettlement
    query = db.query(O)
    if status:
        query = query.filter(O.status == status)
    if owner_user_id:
        query = query.filter(O.owner_user_id == owner_user_id)
    if period:
        query = query.filter(O.period == period)
    rows, total = paginate(query.order_by(O.period.desc(), O.id.desc()), page)
    cache: dict = {}
    data = [{
        "id": o.id, "ref": ro.ref("QT", o.id), "owner": user_brief(db, o.owner_user_id, cache), "period": o.period,
        "gross_amount": ro.vnd(o.gross_amount), "net_amount": ro.vnd(o.net_amount), "status": o.status,
        "snapshot": o.snapshot or {}, "created_at": iso(o.created_at), "settled_at": iso(o.settled_at),
    } for o in rows]
    return paged(data, total=total, page=page,
                 totals_by_status=fo.grouped(db, models.OwnerSettlement.status, models.OwnerSettlement.net_amount))


# Chính sách cọc: MỘT đường ghi duy nhất ở partners.py (/settings/deposit-policy,
# dùng chung partners_ops với endpoint cũ) — không nhân bản logic ở đây.
