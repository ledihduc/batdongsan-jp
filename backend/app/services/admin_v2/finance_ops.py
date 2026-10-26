"""Tài chính Admin V2 — GHI NHẬN và ĐỐI SOÁT, không bao giờ chuyển tiền.

Sổ tiền (`platform_payments` / `payment_allocations` / `money_refunds`) là sổ
chứng từ: ghi lại khoản tiền ĐÃ đổi tay ở ngoài (chuyển khoản, tiền mặt) kèm
bằng chứng, phân bổ cho ai, đã ghi nhận hoàn bao nhiêu. Không có dòng nào ở
đây gọi ngân hàng/cổng thanh toán — `transfer_execution` luôn là DISABLED.

Kiểm tra dùng CHUNG nguồn với sổ tiền cũ (`app/routers/money_ledger_v2.py`):
bộ giá trị hợp lệ (loại nguồn, loại phân bổ, phương thức, mã hoàn) đọc thẳng
từ schema của nó, và luật "phân bổ phải cân", "hoàn không vượt khoản gốc",
"chứng từ chỉ nội bộ/HTTPS" giữ y nguyên. Khác biệt duy nhất: tiền là số
nguyên VND (cột Float cũ không cho số lẻ lọt vào).

Hàm ở đây KHÔNG commit — `run_command` commit một lần cùng nhật ký.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any, Optional, get_args

from fastapi import HTTPException
from sqlalchemy import String, cast, func
from sqlalchemy.orm import Session

from app import models
from app.routers.money_ledger_v2 import AllocationIn, PaymentRecordIn, RefundIn
from app.services import evidence_policy
from app.services.admin_v2 import change_requests
from app.services.admin_v2.core import AdminContext, etag, fail, iso, user_brief, utcnow
from app.services.admin_v2.permissions import REFUND_DUAL_APPROVAL_THRESHOLD
from app.services.admin_v2.rentals_ops import DEPOSIT_CASE, ref, vnd

# Một nguồn sự thật: đọc từ schema sổ tiền cũ, không chép lại danh sách.
SOURCE_TYPES: tuple[str, ...] = get_args(PaymentRecordIn.model_fields["source_type"].annotation)
METHODS: tuple[str, ...] = get_args(PaymentRecordIn.model_fields["method"].annotation)
ALLOCATION_TYPES: tuple[str, ...] = get_args(AllocationIn.model_fields["allocation_type"].annotation)
REFUND_REASONS: tuple[str, ...] = get_args(RefundIn.model_fields["reason_code"].annotation)

SOURCE_LABELS = {
    "INVOICE": "Hoá đơn thuê tháng",
    "RESERVATION": "Đơn đặt phòng ngắn hạn",
    "RENTAL_DEPOSIT": "Khoản cọc hành trình thuê",
    "BUY_SELL_DEPOSIT": "Cọc giao dịch mua bán",
}
ALLOCATION_LABELS = {
    "OWNER_NET": "Chủ nhà thực nhận",
    "PLATFORM_FEE": "Phí nền tảng",
    "SALE_COMMISSION": "Hoa hồng sale",
    "TAX": "Thuế",
    "OTHER": "Khác",
}
REFUND_REASON_LABELS = {
    "CUSTOMER_CANCELLED": "Khách huỷ",
    "OWNER_CANCELLED": "Chủ nhà huỷ",
    "OVERPAYMENT": "Thu thừa",
    "SERVICE_FAILURE": "Dịch vụ không đạt",
    "OTHER": "Khác",
}
TRANSFER_EXECUTION = "DISABLED"
RECORD_ONLY_NOTE = (
    "Hệ thống chỉ ghi nhận và đối soát chứng từ. Không có thao tác nào ở đây "
    "chuyển tiền hay gọi ngân hàng/cổng thanh toán."
)

RECONCILE_CASE = "payment_reconcile"
REFUND_KIND = "refund_record"


def _translate(exc: HTTPException) -> HTTPException:
    if isinstance(exc.detail, dict):
        return exc
    return fail(exc.status_code, "ADMIN_VALIDATION" if exc.status_code == 422 else "ADMIN_CONFLICT", str(exc.detail))


# ── Tổng hợp theo khoản ───────────────────────────────────────────────────────


def alloc_sums(db: Session):
    A = models.PaymentAllocation
    return (db.query(A.payment_id.label("pid"), func.coalesce(func.sum(A.amount), 0).label("s"))
            .group_by(A.payment_id).subquery())


def refund_sums(db: Session):
    M = models.MoneyRefund
    return (db.query(M.payment_id.label("pid"), func.coalesce(func.sum(M.amount), 0).label("s"))
            .group_by(M.payment_id).subquery())


def cases_for(db: Session, source_type: str, ids: list[int]) -> dict[int, models.AdminCase]:
    if not ids:
        return {}
    rows = db.query(models.AdminCase).filter(
        models.AdminCase.source_type == source_type, models.AdminCase.source_id.in_([str(i) for i in ids])).all()
    return {int(c.source_id): c for c in rows}


def case_events(db: Session, case_ids: list[int], kind: str) -> dict[int, models.AdminCaseEvent]:
    """Sự kiện MỚI NHẤT loại `kind` của mỗi case."""
    if not case_ids:
        return {}
    E = models.AdminCaseEvent
    rows = db.query(E).filter(E.case_id.in_(case_ids), E.kind == kind).order_by(E.id.asc()).all()
    return {e.case_id: e for e in rows}


def get_or_create_case(db: Session, source_type: str, source_id: int, *, priority: str = "normal") -> models.AdminCase:
    c = db.query(models.AdminCase).filter_by(source_type=source_type, source_id=str(source_id)).first()
    if c is None:
        c = models.AdminCase(source_type=source_type, source_id=str(source_id), priority=priority,
                             status="open", version=0)
        db.add(c)
        db.flush()
    return c


def touch_case(db: Session, c: models.AdminCase, *, actor: int, kind: str, status: str, note: str,
               payload: dict) -> None:
    c.status = status
    c.internal_note = note[:2000] if note else c.internal_note
    c.version = (c.version or 0) + 1
    c.updated_at = utcnow()
    db.add(models.AdminCaseEvent(case_id=c.id, actor_user_id=actor, kind=kind, payload=payload))


def reconciled_dto(db: Session, c: Optional[models.AdminCase], ev: Optional[models.AdminCaseEvent],
                   cache: dict) -> Optional[dict]:
    if c is None or c.status != "done" or ev is None:
        return None
    return {"by": user_brief(db, ev.actor_user_id, cache), "at": iso(ev.created_at),
            "note": (ev.payload or {}).get("note")}


def payment_version(p: models.PlatformPayment, allocated: int, refunded: int, case: Optional[models.AdminCase]) -> str:
    return etag(p.id, p.status, vnd(p.amount), allocated, refunded, case.version if case else 0)


def payment_row(db: Session, p: models.PlatformPayment, allocated: Any, refunded: Any,
                case: Optional[models.AdminCase], ev: Optional[models.AdminCaseEvent], cache: dict) -> dict:
    amount, alloc, refd = vnd(p.amount) or 0, vnd(allocated) or 0, vnd(refunded) or 0
    return {
        "id": p.id,
        "ref": ref("TT", p.id),
        "source_type": p.source_type,
        "source_label": SOURCE_LABELS.get(p.source_type, p.source_type),
        "source_id": p.source_id,
        "source_link": source_link(p.source_type, p.source_id),
        "payer": user_brief(db, p.payer_user_id, cache),
        "amount": amount,
        "currency": p.currency,
        "status": p.status,
        "method": p.method,
        "external_reference": p.external_reference,
        "paid_at": iso(p.paid_at),
        "recorded_by": user_brief(db, p.recorded_by_user_id, cache),
        "created_at": iso(p.created_at),
        "allocated_amount": alloc,
        "refunded_amount": refd,
        "net_amount": amount - refd,
        "allocation_difference": amount - alloc,
        "mismatch": abs(amount - alloc) >= 1,
        "evidence_count": len(p.evidence_urls or []),
        "reconciled": reconciled_dto(db, case, ev, cache),
        "version": payment_version(p, alloc, refd, case),
    }


def source_link(source_type: str, source_id: int) -> Optional[str]:
    if source_type == "RESERVATION":
        return f"/admin/rentals/reservations/{source_id}"
    if source_type == "INVOICE":
        return f"/admin/finance/invoices?focus={source_id}"
    if source_type == "RENTAL_DEPOSIT":
        return f"/admin/finance/deposits?focus={source_id}"
    return None


def payment_rows(db: Session, rows: list[models.PlatformPayment]) -> list[dict]:
    ids = [p.id for p in rows]
    if not ids:
        return []
    A, M = models.PaymentAllocation, models.MoneyRefund
    allocs = dict(db.query(A.payment_id, func.sum(A.amount)).filter(A.payment_id.in_(ids)).group_by(A.payment_id).all())
    refs = dict(db.query(M.payment_id, func.sum(M.amount)).filter(M.payment_id.in_(ids)).group_by(M.payment_id).all())
    cases = cases_for(db, RECONCILE_CASE, ids)
    evs = case_events(db, [c.id for c in cases.values()], "reconciled")
    cache: dict = {}
    return [
        payment_row(db, p, allocs.get(p.id, 0), refs.get(p.id, 0), cases.get(p.id),
                    evs.get(cases[p.id].id) if p.id in cases else None, cache)
        for p in rows
    ]


def payment_detail(db: Session, ctx: AdminContext, p: models.PlatformPayment) -> dict:
    cache: dict = {}
    allocs = db.query(models.PaymentAllocation).filter_by(payment_id=p.id).order_by(models.PaymentAllocation.id).all()
    refunds = db.query(models.MoneyRefund).filter_by(payment_id=p.id).order_by(models.MoneyRefund.id).all()
    row = payment_rows(db, [p])[0]
    pending = pending_refund_requests(db, p.id)
    return {
        **row,
        "evidence": [{"path": u, "private": True} for u in (p.evidence_urls or [])],
        "allocations": [
            {"id": a.id, "type": a.allocation_type, "type_label": ALLOCATION_LABELS.get(a.allocation_type, a.allocation_type),
             "beneficiary": user_brief(db, a.beneficiary_user_id, cache), "amount": vnd(a.amount),
             "rule_version": a.rule_version} for a in allocs
        ],
        "refunds": [refund_dto(db, r, cache) for r in refunds],
        "pending_refund_requests": [change_requests.to_dict(db, r, cache) for r in pending],
        "refundable_amount": max(0, (vnd(p.amount) or 0) - row["refunded_amount"]
                                 - sum(int((r.payload or {}).get("amount") or 0) for r in pending)),
        "refund_dual_approval_threshold": REFUND_DUAL_APPROVAL_THRESHOLD,
        "transfer_execution": TRANSFER_EXECUTION,
    }


def refund_dto(db: Session, r: models.MoneyRefund, cache: dict) -> dict:
    return {
        "id": r.id, "ref": ref("HTN", r.id), "payment_id": r.payment_id, "amount": vnd(r.amount),
        "reason_code": r.reason_code, "reason_label": REFUND_REASON_LABELS.get(r.reason_code, r.reason_code),
        "note": r.note, "status": r.status, "recorded_by": user_brief(db, r.recorded_by_user_id, cache),
        "created_at": iso(r.created_at),
    }


# ── Ghi nhận thanh toán ───────────────────────────────────────────────────────


def check_source(db: Session, source_type: str, source_id: int) -> None:
    """Nguồn tiền phải tồn tại — gõ nhầm id là một khoản tiền treo không ai đối soát được.

    RENTAL_DEPOSIT = id của `rental_journey_payments` (một hành trình có HAI khoản
    cọc, nên id hành trình không đủ chỉ đích danh khoản nào).
    """
    model = {
        "INVOICE": models.Invoice,
        "RESERVATION": models.Reservation,
        "RENTAL_DEPOSIT": models.RentalJourneyPayment,
        "BUY_SELL_DEPOSIT": models.SaleTransaction,
    }.get(source_type)
    if model is None or db.get(model, source_id) is None:
        raise fail(422, "ADMIN_SOURCE_NOT_FOUND", "Không tìm thấy nguồn tiền (loại + mã) đã nhập")


def record_payment(db: Session, ctx: AdminContext, body: Any) -> models.PlatformPayment:
    if sum(a.amount for a in body.allocations) != body.amount:
        raise fail(422, "ADMIN_ALLOCATION_UNBALANCED", "Tổng phân bổ phải bằng số tiền ghi nhận")
    buckets = {(a.allocation_type, a.beneficiary_user_id) for a in body.allocations}
    if len(buckets) != len(body.allocations):
        raise fail(422, "ADMIN_ALLOCATION_DUPLICATE", "Mỗi loại phân bổ chỉ một dòng cho mỗi người nhận")
    paid_at = body.paid_at.replace(tzinfo=None)
    if paid_at > utcnow() + timedelta(minutes=10):
        raise fail(422, "ADMIN_PAID_AT_FUTURE", "Thời điểm thanh toán không được ở tương lai")
    check_source(db, body.source_type, body.source_id)
    for uid in {body.payer_user_id, *(a.beneficiary_user_id for a in body.allocations)} - {None}:
        if db.get(models.User, uid) is None:
            raise fail(422, "ADMIN_USER_NOT_FOUND", f"Không tìm thấy người dùng #{uid}")
    try:
        evidence = evidence_policy.validate_urls(body.evidence_urls)
    except HTTPException as exc:
        raise _translate(exc) from exc
    P = models.PlatformPayment
    dup = db.query(P.id).filter(P.source_type == body.source_type, P.source_id == body.source_id,
                                P.external_reference == body.external_reference).first()
    if dup is not None:
        raise fail(409, "ADMIN_DUPLICATE_REFERENCE", "Mã chứng từ đã được ghi nhận cho nguồn tiền này",
                   {"payment_id": dup[0]})
    item = P(source_type=body.source_type, source_id=body.source_id, payer_user_id=body.payer_user_id,
             amount=body.amount, method=body.method, external_reference=body.external_reference.strip(),
             evidence_urls=evidence, recorded_by_user_id=ctx.user_id, paid_at=paid_at)
    db.add(item)
    db.flush()
    for a in body.allocations:
        db.add(models.PaymentAllocation(payment_id=item.id, allocation_type=a.allocation_type,
                                        beneficiary_user_id=a.beneficiary_user_id, amount=a.amount,
                                        rule_version=a.rule_version))
    db.flush()
    return item


# ── Ghi nhận hoàn tiền (+ maker-checker trên ngưỡng) ──────────────────────────


def pending_refund_requests(db: Session, payment_id: int) -> list[models.AdminChangeRequest]:
    rows = (
        db.query(models.AdminChangeRequest)
        .filter(models.AdminChangeRequest.kind == REFUND_KIND, models.AdminChangeRequest.status == "PENDING")
        .order_by(models.AdminChangeRequest.id.asc()).limit(500).all()
    )
    return [r for r in rows if int((r.payload or {}).get("payment_id") or 0) == payment_id]


def refunded_total(db: Session, payment_id: int) -> int:
    v = db.query(func.coalesce(func.sum(models.MoneyRefund.amount), 0)).filter(
        models.MoneyRefund.payment_id == payment_id).scalar()
    return vnd(v) or 0


def ensure_refundable(db: Session, p: models.PlatformPayment, amount: int, *, include_pending: bool) -> None:
    taken = refunded_total(db, p.id)
    if include_pending:
        taken += sum(int((r.payload or {}).get("amount") or 0) for r in pending_refund_requests(db, p.id))
    if taken + amount > (vnd(p.amount) or 0):
        raise fail(422, "ADMIN_REFUND_EXCEEDS_PAYMENT",
                   "Tổng hoàn tiền (kể cả yêu cầu đang chờ duyệt) không được vượt khoản đã ghi nhận",
                   {"refundable_amount": max(0, (vnd(p.amount) or 0) - taken)})


def add_refund(db: Session, p: models.PlatformPayment, *, amount: int, reason_code: str, note: str,
               recorded_by: int) -> models.MoneyRefund:
    r = models.MoneyRefund(payment_id=p.id, amount=amount, reason_code=reason_code, note=note or "",
                           recorded_by_user_id=recorded_by)
    db.add(r)
    db.flush()
    return r


def _exec_refund(db: Session, approver: AdminContext, payload: dict) -> dict:
    p = db.get(models.PlatformPayment, int(payload["payment_id"]))
    if p is None:
        raise fail(409, "ADMIN_CONFLICT", "Khoản thanh toán không còn tồn tại")
    amount = int(payload["amount"])
    # Lúc duyệt chỉ tính hoàn ĐÃ ghi — yêu cầu đang duyệt chính là yêu cầu này.
    ensure_refundable(db, p, amount, include_pending=False)
    r = add_refund(db, p, amount=amount, reason_code=str(payload["reason_code"]), note=str(payload.get("note") or ""),
                   recorded_by=int(payload["requested_by"]))
    return {"refund_id": r.id, "payment_id": p.id, "amount": amount, "approved_by": approver.user_id,
            "refunded_total": refunded_total(db, p.id)}


def _describe_refund(db: Session, payload: dict) -> str:
    amount = int(payload.get("amount") or 0)
    return (f"Ghi nhận hoàn {amount:,}".replace(",", ".") + f" ₫ cho khoản TT-{int(payload.get('payment_id') or 0):05d}"
            f" ({REFUND_REASON_LABELS.get(payload.get('reason_code'), payload.get('reason_code'))})")


def _preview_refund(db: Session, payload: dict) -> list:
    p = db.get(models.PlatformPayment, int(payload.get("payment_id") or 0))
    if p is None:
        return []
    amount = int(payload.get("amount") or 0)
    done = refunded_total(db, p.id)
    total = vnd(p.amount) or 0
    return [
        {"label": "Hoàn tiền đã ghi nhận", "before": done, "after": done + amount, "delta": amount, "unit": "vnd"},
        {"label": "Số tiền còn có thể hoàn", "before": total - done, "after": total - done - amount,
         "delta": -amount, "unit": "vnd"},
    ]


def _links_refund(db: Session, payload: dict) -> list:
    p = db.get(models.PlatformPayment, int(payload.get("payment_id") or 0))
    if p is None:
        return []
    out = [{"label": "Liên quan thanh toán", "ref": ref("TT", p.id), "href": f"/admin/finance/payments/{p.id}",
            "detail": f"{SOURCE_LABELS.get(p.source_type, p.source_type)} · {vnd(p.amount) or 0:,} ₫".replace(",", "."),
            "amount": vnd(p.amount) or 0}]
    if p.source_type == "RENTAL_DEPOSIT":
        dep = db.get(models.RentalJourneyPayment, p.source_id)
        if dep is not None:
            out.append({"label": "Liên quan hành trình", "ref": ref("HT", dep.journey_id),
                        "href": f"/admin/rentals/journeys/{dep.journey_id}", "detail": "Cọc thuê dài hạn"})
    return out


change_requests.register(
    REFUND_KIND, permission="payments.refund", label="Ghi nhận hoàn tiền vượt ngưỡng",
    executor=_exec_refund, describe=_describe_refund, preview=_preview_refund, links=_links_refund,
)


# ── Tổng quan + đối soát ──────────────────────────────────────────────────────


def ledger_summary(db: Session) -> dict:
    pay = vnd(db.query(func.coalesce(func.sum(models.PlatformPayment.amount), 0)).scalar()) or 0
    alloc = vnd(db.query(func.coalesce(func.sum(models.PaymentAllocation.amount), 0)).scalar()) or 0
    refund = vnd(db.query(func.coalesce(func.sum(models.MoneyRefund.amount), 0)).scalar()) or 0
    return {
        "payment_total": pay, "allocation_total": alloc, "refund_total": refund, "net_total": pay - refund,
        "allocation_difference": pay - alloc, "balanced": abs(pay - alloc) < 1,
        "payments_count": db.query(func.count(models.PlatformPayment.id)).scalar() or 0,
        "transfer_execution": TRANSFER_EXECUTION,
    }


def mismatch_query(db: Session):
    P = models.PlatformPayment
    a = alloc_sums(db)
    return db.query(P).outerjoin(a, a.c.pid == P.id).filter(func.abs(P.amount - func.coalesce(a.c.s, 0)) >= 1)


def deposit_unverified_query(db: Session):
    """Cọc đã nộp minh chứng (SUBMITTED) mà tài chính chưa kết luận xong."""
    RP, C = models.RentalJourneyPayment, models.AdminCase
    done = db.query(C.source_id).filter(C.source_type == DEPOSIT_CASE, C.status == "done")
    return db.query(RP).filter(RP.status == "SUBMITTED", cast(RP.id, String).notin_(done))


def grouped(db: Session, status_col, amount_col) -> dict:
    rows = db.query(status_col, func.count(), func.coalesce(func.sum(amount_col), 0)).group_by(status_col).all()
    return {s: {"count": int(n), "amount": vnd(a) or 0} for s, n, a in rows}


def today_iso() -> str:
    return date.today().isoformat()


def invoice_overdue_filter():
    from app.services.admin_v2.rentals_ops import INVOICE_OPEN_EXCLUDED

    I = models.Invoice
    return (I.status.notin_(INVOICE_OPEN_EXCLUDED), I.due_date < today_iso())


def parse_dt(value: Optional[str], field: str) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        raise fail(422, "ADMIN_BAD_FILTER", f"Ngày không hợp lệ ({field})")
