"""Tổng quan vận hành, hộp việc, hoạt động gần đây, cảnh báo, tìm kiếm toàn cục.

Dashboard KHÔNG bao giờ biến lỗi thành số 0: mỗi nhóm có `status`
ok | stale | error kèm `updated_at`/`last_success_at`. Khi một truy vấn lỗi, trả
bản cũ gần nhất (đánh dấu stale) nếu có, không có thì value=null.
"""

from __future__ import annotations

import logging
from datetime import date, datetime, timedelta
from typing import Any, Callable, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.services.admin_v2 import work_items as wi
from app.services.admin_v2.core import (
    AdminContext, CommandResult, PageParams, admin_context, fail, idempotency_key, if_match, iso,
    mask_email, mask_phone, one, page_params, paged, require_permission, run_command, user_brief, utcnow,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v2/admin", tags=["admin-v2-overview"])

# Bản thành công gần nhất của từng nhóm — để trả "stale" thay vì 0 khi lỗi.
_LAST_GOOD: dict[str, dict] = {}


def _group(key: str, perm: str, ctx: AdminContext, db: Session, fn: Callable[[], dict]) -> Optional[dict]:
    if not ctx.has(perm):
        return None
    try:
        data = fn()
        out = {"status": "ok", "updated_at": iso(utcnow()), "last_success_at": iso(utcnow()), **data}
        _LAST_GOOD[key] = out
        return out
    except Exception as exc:  # noqa: BLE001
        db.rollback()
        logger.warning("dashboard group %s failed: %s", key, exc)
        prev = _LAST_GOOD.get(key)
        if prev:
            return {**prev, "status": "stale", "updated_at": iso(utcnow()), "error": "Không tải được số mới"}
        return {"status": "error", "value": None, "updated_at": iso(utcnow()), "last_success_at": None,
                "error": "Chưa tải được chỉ số"}


def _count(db: Session, q) -> int:
    return int(q.order_by(None).count())


def _ops(db: Session, day: date) -> dict:
    J = models.RentalJourney
    active = _count(db, db.query(J).filter(J.status.notin_(("COMPLETED", "CANCELLED", "CUSTOMER_DECLINED"))))
    V = models.ViewingAppointment
    viewings_today = _count(db, db.query(V).filter(V.booking_date == day.isoformat(), V.status.notin_(("cancelled", "rejected"))))
    res_pending = _count(db, db.query(models.Reservation).filter(models.Reservation.status == "pending"))
    contracts_active = _count(db, db.query(models.Contract).filter(models.Contract.status == "active"))
    return {
        "value": active, "label": "Hành trình cần theo dõi",
        "secondary": f"{viewings_today} lịch xem nhà ngày {day.strftime('%d/%m')}",
        "metrics": {"journeys_active": active, "viewings_today": viewings_today,
                    "reservations_pending": res_pending, "contracts_active": contracts_active},
        "link": "/admin/rentals/journeys",
    }


def _moderation(db: Session) -> dict:
    listings = _count(db, db.query(models.House).filter(models.House.status == "pending_review"))
    reports = _count(db, db.query(models.ContentReport).filter(
        models.ContentReport.status == "pending", models.ContentReport.kind == "violation"))
    verif = _count(db, db.query(models.VerificationRequest).filter(
        models.VerificationRequest.status.in_(("requested", "inspecting"))))
    return {
        "value": listings + verif, "label": "Nội dung chờ duyệt",
        "secondary": f"{reports} báo cáo cần xử lý",
        "metrics": {"listings_pending": listings, "reports_pending": reports,
                    "verification_open": verif},
        "link": "/admin/content/listings",
    }


def _allocation_mismatches(db: Session) -> int:
    P, A = models.PlatformPayment, models.PaymentAllocation
    alloc = (
        db.query(A.payment_id.label("pid"), func.coalesce(func.sum(A.amount), 0).label("s"))
        .group_by(A.payment_id).subquery()
    )
    return int(
        db.query(func.count(P.id))
        .outerjoin(alloc, alloc.c.pid == P.id)
        .filter(func.abs(P.amount - func.coalesce(alloc.c.s, 0)) >= 1)
        .scalar() or 0
    )


def _finance(db: Session) -> dict:
    deposits = _count(db, db.query(models.RentalJourneyPayment).filter(models.RentalJourneyPayment.status == "SUBMITTED"))
    mismatch = _allocation_mismatches(db)
    today = date.today().isoformat()
    overdue = _count(db, db.query(models.Invoice).filter(
        models.Invoice.status.notin_(("paid", "void", "cancelled", "draft")), models.Invoice.due_date < today))
    week = utcnow() - timedelta(days=7)
    refunds = _count(db, db.query(models.MoneyRefund).filter(models.MoneyRefund.created_at >= week))
    return {
        "value": deposits, "label": "Chứng từ cọc cần xác minh",
        "secondary": f"{mismatch} khoản chênh lệch" if mismatch else "Không có khoản chênh lệch",
        "warn": mismatch > 0,
        "metrics": {"deposits_submitted": deposits, "allocation_mismatches": mismatch,
                    "invoices_overdue": overdue, "refunds_7d": refunds},
        "link": "/admin/finance/deposits",
    }


def _system(db: Session) -> dict:
    from sqlalchemy import text

    db.execute(text("SELECT 1"))
    push_failed = _count(db, db.query(models.PushOutbox).filter(
        models.PushOutbox.gui_luc.is_(None), models.PushOutbox.so_lan_thu >= 3))
    push_queued = _count(db, db.query(models.PushOutbox).filter(models.PushOutbox.gui_luc.is_(None)))
    issues = push_failed
    return {
        "value": issues, "label": "Sự cố cần chú ý" if issues else "Hệ thống ổn định",
        "secondary": f"{push_failed} thông báo lỗi",
        "warn": issues > 0,
        "metrics": {"db": "ok", "push_failed": push_failed, "push_queued": push_queued},
        "link": "/admin/system/health",
    }


@router.get("/dashboard")
def dashboard(
    day: Optional[date] = Query(None, alias="date"),
    ctx: AdminContext = Depends(require_permission("dashboard.read")),
    db: Session = Depends(get_db),
):
    d = day or (utcnow() + timedelta(hours=7)).date()
    groups = {
        "operations": _group("operations", "rental_journeys.read", ctx, db, lambda: _ops(db, d)),
        "moderation": _group("moderation", "content.read", ctx, db, lambda: _moderation(db)),
        "finance": _group("finance", "payments.read", ctx, db, lambda: _finance(db)),
        "system": _group("system", "system.read", ctx, db, lambda: _system(db)),
    }
    # SLA: phần việc ĐANG MỞ còn trong hạn, theo module.
    sla: list[dict] = []
    if ctx.has("work_items.read"):
        try:
            items, _counts, _t = wi.collect(db, ctx)
            by_mod: dict[str, list[int]] = {s.module: [0, 0] for s in wi.visible_sources(ctx)}
            for it in items:
                acc = by_mod.setdefault(it["module"], [0, 0])
                acc[1] += 1
                if not it["overdue"]:
                    acc[0] += 1
            for mod, (ok, total) in by_mod.items():
                sla.append({"module": mod, "label": wi.MODULES[mod], "on_time": ok, "total": total,
                            "percent": round(ok * 100 / total) if total else 100})
            sla.sort(key=lambda x: list(wi.MODULES).index(x["module"]))
        except Exception as exc:  # noqa: BLE001
            db.rollback()
            logger.warning("dashboard sla failed: %s", exc)
            sla = []
    return one({"date": d.isoformat(), "groups": groups, "sla": sla})


# ── Hộp việc ──────────────────────────────────────────────────────────────────


@router.get("/work-items")
def list_work_items(
    type: str = Query("", max_length=200),
    module: str = Query("", max_length=20),
    priority: str = Query("", pattern="^(|high|urgent|normal|low|high_or_overdue)$"),
    assignee: str = Query("", max_length=20),  # me | unassigned | <user_id>
    overdue: str = Query("", pattern="^(|yes|no)$"),
    q: str = Query("", max_length=100),
    state: str = Query("", pattern="^(|done)$"),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("work_items.read")),
    db: Session = Depends(get_db),
):
    types = {t for t in type.split(",") if t} or None
    if state == "done":
        return _done_items(db, ctx, page, types, q)
    items, counts, truncated = wi.collect(db, ctx, types=types, module=module)
    mine = sum(1 for it in items if it["assignee"] and it["assignee"]["id"] == ctx.user_id)
    high = sum(1 for it in items if it["priority"] in ("high", "urgent") or it["overdue"])
    overdue_n = sum(1 for it in items if it["overdue"])
    if priority == "high_or_overdue":
        items = [it for it in items if it["priority"] in ("high", "urgent") or it["overdue"]]
    elif priority:
        items = [it for it in items if it["priority"] == priority]
    if assignee == "me":
        items = [it for it in items if it["assignee"] and it["assignee"]["id"] == ctx.user_id]
    elif assignee == "unassigned":
        items = [it for it in items if not it["assignee"]]
    elif assignee.isdigit():
        items = [it for it in items if it["assignee"] and it["assignee"]["id"] == int(assignee)]
    if overdue == "yes":
        items = [it for it in items if it["overdue"]]
    elif overdue == "no":
        items = [it for it in items if not it["overdue"]]
    if q.strip():
        s = q.strip().lower()
        items = [it for it in items if s in it["ref"].lower() or s in (it["title"] or "").lower()]
    items = wi.sort_items(items)
    total = len(items)
    data = items[page.offset: page.offset + page.limit]
    return paged(
        data, total=total, page=page, truncated=truncated,
        counts_by_type=counts,
        tabs={"all": total if not (priority or assignee or overdue or q.strip()) else None,
              "high": high, "mine": mine, "overdue": overdue_n,
              "approvals": _pending_approvals(db, ctx), "done_7d": _done_count(db, ctx)},
        types=[{"code": s.code, "label": s.label, "module": s.module} for s in wi.visible_sources(ctx)],
        partial_error=[k for k, v in counts.items() if v < 0],
    )


def _pending_approvals(db: Session, ctx: AdminContext) -> int:
    """Yêu cầu maker-checker đang chờ MÌNH duyệt (không tính yêu cầu của mình)."""
    from app.services.admin_v2 import change_requests

    allowed = [c for c, k in change_requests.kinds().items() if ctx.has(k.permission)]
    if not allowed:
        return 0
    CR = models.AdminChangeRequest
    return db.query(CR).filter(CR.status == "PENDING", CR.kind.in_(allowed), CR.requested_by != ctx.user_id).count()


def _done_query(db: Session, ctx: AdminContext, days: int):
    visible = [s.code for s in wi.visible_sources(ctx)]
    C = models.AdminCase
    return db.query(C).filter(
        C.status == "done", C.source_type.in_(visible or ["__none__"]),
        C.updated_at >= utcnow() - timedelta(days=days),
    )


def _done_count(db: Session, ctx: AdminContext) -> int:
    return _done_query(db, ctx, 7).count()


def _done_items(db: Session, ctx: AdminContext, page: PageParams, types, q: str) -> dict:
    """Việc đã xử lý xong (30 ngày) — chỉ việc có case (đã được nhận/đánh dấu)."""
    query = _done_query(db, ctx, 30)
    if types:
        query = query.filter(models.AdminCase.source_type.in_(list(types)))
    rows = query.order_by(models.AdminCase.updated_at.desc()).limit(500).all()
    now = utcnow()
    cache: dict = {}
    data = []
    for c in rows:
        src = wi.source(c.source_type)
        row = c if c.source_type == "manual" else (wi.load_row(db, src, c.source_id) if src else None)
        if src is None or row is None:
            continue
        it = wi.to_item(db, src, row, c, now, cache)
        it["done_at"] = iso(c.done_at or c.updated_at)
        if q.strip() and q.strip().lower() not in (it["ref"] + " " + (it["title"] or "")).lower():
            continue
        data.append(it)
    total = len(data)
    return paged(data[page.offset: page.offset + page.limit], total=total, page=page, state="done")


class CreateWorkBody(BaseModel):
    title: str = Field(..., min_length=3, max_length=200)
    description: Optional[str] = Field(None, max_length=4000)
    priority: str = Field("normal", pattern="^(low|normal|high|urgent)$")
    assignee_user_id: Optional[int] = None
    sla_due_at: Optional[datetime] = None
    #: Liên kết tuỳ chọn tới đối tượng nghiệp vụ (vd /admin/users/12) — chỉ đường nội bộ.
    link: Optional[str] = Field(None, max_length=300)


@router.post("/work-items")
def create_work_item(
    body: CreateWorkBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(require_permission("work_items.assign")),
    db: Session = Depends(get_db),
):
    """Công việc tạo tay (việc không đến từ hàng đợi nào: gọi lại khách, kiểm tra
    hiện trường…). Đi chung hộp việc, SLA, phân công như mọi việc khác."""
    from app.services.admin_v2 import rbac

    if body.assignee_user_id is not None and not rbac.permissions_of(db, body.assignee_user_id):
        raise fail(422, "ADMIN_ASSIGNEE_NOT_STAFF", "Người được giao không phải nhân viên quản trị")
    if body.link and not body.link.startswith("/admin/"):
        raise fail(422, "ADMIN_VALIDATION", "Liên kết phải là đường dẫn nội bộ /admin/…")
    src = wi.source("manual")

    def do() -> CommandResult:
        now = utcnow()
        c = models.AdminCase(
            source_type="manual", source_id="pending", title=body.title.strip(),
            description=((body.description or "").strip() + (f"\n\nLiên kết: {body.link}" if body.link else "")).strip() or None,
            priority=body.priority, status="open", assignee_user_id=body.assignee_user_id,
            sla_due_at=body.sla_due_at.replace(tzinfo=None) if body.sla_due_at else now + timedelta(hours=src.sla_hours),
            created_by=ctx.user_id, version=1, created_at=now, updated_at=now,
        )
        db.add(c)
        db.flush()
        c.source_id = str(c.id)  # việc tạo tay: case CHÍNH LÀ bản ghi nguồn
        db.add(models.AdminCaseEvent(case_id=c.id, actor_user_id=ctx.user_id, kind="create",
                                     payload={"title": c.title, "priority": c.priority}))
        db.flush()
        item = wi.to_item(db, src, c, c, now, {})
        item["version"] = str(c.version)
        return CommandResult(data=item, entity_id=c.id, after={"title": c.title, "priority": c.priority},
                             event_status="open")

    return run_command(
        db, ctx, action="work_item.create", permission="work_items.assign", entity_type="manual",
        entity_id=None, key=key, fn=do, event_type="admin.work_item.created",
    )


def _src_row(db: Session, ctx: AdminContext, type_code: str, source_id: str):
    src = wi.source(type_code)
    if src is None or not ctx.has(src.permission):
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy công việc")
    row = wi.load_row(db, src, source_id)
    if row is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy công việc")
    return src, row


def _case(db: Session, src_code: str, source_id: str) -> Optional[models.AdminCase]:
    return db.query(models.AdminCase).filter_by(source_type=src_code, source_id=str(source_id)).first()


@router.get("/work-items/{type_code}/{source_id}")
def get_work_item(
    type_code: str,
    source_id: str,
    ctx: AdminContext = Depends(require_permission("work_items.read")),
    db: Session = Depends(get_db),
):
    src, row = _src_row(db, ctx, type_code, source_id)
    case = _case(db, src.code, source_id)
    item = wi.to_item(db, src, row, case, utcnow(), {})
    events = []
    if case is not None:
        cache: dict = {}
        for e in (
            db.query(models.AdminCaseEvent).filter_by(case_id=case.id)
            .order_by(models.AdminCaseEvent.id.desc()).limit(50).all()
        ):
            events.append({"id": e.id, "kind": e.kind, "payload": e.payload,
                           "actor": user_brief(db, e.actor_user_id, cache), "created_at": iso(e.created_at)})
    item["events"] = events
    item["version"] = str(case.version) if case else "0"
    return one(item)


class AssignBody(BaseModel):
    assignee_user_id: Optional[int] = None
    unassign: bool = False
    priority: Optional[str] = Field(None, pattern="^(low|normal|high|urgent)$")
    status: Optional[str] = Field(None, pattern="^(open|in_progress|waiting|done)$")
    note: Optional[str] = Field(None, max_length=2000)
    sla_due_at: Optional[datetime] = None
    legal_hold: Optional[bool] = None


@router.post("/work-items/{type_code}/{source_id}/assign")
def assign_work_item(
    type_code: str,
    source_id: str,
    body: AssignBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("work_items.assign")),
    db: Session = Depends(get_db),
):
    src, row = _src_row(db, ctx, type_code, source_id)
    if body.assignee_user_id is not None:
        from app.services.admin_v2 import rbac

        if not rbac.permissions_of(db, body.assignee_user_id):
            raise fail(422, "ADMIN_ASSIGNEE_NOT_STAFF", "Người được giao không phải nhân viên quản trị")
    if body.legal_hold is not None and not ctx.has("retention.manage"):
        raise fail(403, "ADMIN_PERMISSION_DENIED", "Đặt legal hold cần quyền retention.manage")

    def current() -> str:
        c = _case(db, src.code, source_id)
        return str(c.version) if c else "0"

    def do() -> CommandResult:
        case = _case(db, src.code, source_id)
        if case is None:
            case = models.AdminCase(source_type=src.code, source_id=str(source_id), priority=src.default_priority,
                                    status="open", version=0)
            db.add(case)
            db.flush()
        before = {"assignee": case.assignee_user_id, "priority": case.priority, "status": case.status,
                  "note": case.internal_note}
        changes: dict[str, Any] = {}
        if body.unassign:
            case.assignee_user_id = None
            changes["assignee"] = None
        elif body.assignee_user_id is not None:
            case.assignee_user_id = body.assignee_user_id
            changes["assignee"] = body.assignee_user_id
        if body.priority:
            case.priority = body.priority
            changes["priority"] = body.priority
        if body.status:
            case.status = body.status
            case.done_at = utcnow() if body.status == "done" else None
            changes["status"] = body.status
        if body.note is not None:
            case.internal_note = body.note.strip() or None
            changes["note"] = case.internal_note
        if body.sla_due_at is not None:
            case.sla_due_at = body.sla_due_at.replace(tzinfo=None)
            changes["sla_due_at"] = iso(case.sla_due_at)
        if body.legal_hold is not None:
            case.legal_hold = body.legal_hold
            changes["legal_hold"] = body.legal_hold
        if not changes:
            raise fail(422, "ADMIN_NOTHING_TO_CHANGE", "Không có thay đổi nào")
        case.version = (case.version or 0) + 1
        case.updated_at = utcnow()
        db.add(models.AdminCaseEvent(case_id=case.id, actor_user_id=ctx.user_id,
                                     kind="update", payload=changes))
        db.flush()
        item = wi.to_item(db, src, row, case, utcnow(), {})
        item["version"] = str(case.version)
        return CommandResult(data=item, before=before, after=changes, event_status=case.status)

    return run_command(
        db, ctx, action="work_item.update", permission="work_items.assign", entity_type=src.code,
        entity_id=source_id, key=key, fn=do, expected_version=expected, current_version=current,
        event_type="admin.work_item.updated",
    )


@router.get("/staff-directory")
def staff_directory(ctx: AdminContext = Depends(require_permission("work_items.assign")), db: Session = Depends(get_db)):
    """Danh sách nhân viên tối giản để chọn người phụ trách."""
    from app.services.admin_v2 import rbac

    ids = [r[0] for r in db.query(models.AdminUserRole.user_id).filter(models.AdminUserRole.revoked_at.is_(None)).distinct()]
    users = db.query(models.User).filter(models.User.id.in_(ids), models.User.is_active == True).all()  # noqa: E712
    return one([{"id": u.id, "name": u.name, "roles": rbac.active_roles(db, u.id)} for u in users])


# ── Hoạt động gần đây / cảnh báo ──────────────────────────────────────────────

_ACTION_LABELS = {
    "listing.approve": "đã duyệt tin đăng", "listing.reject": "đã từ chối tin đăng",
    "listing.unpublish": "đã gỡ tin đăng", "listing.trusted": "đã cập nhật nhãn tin cậy",
    "content_report.decide": "đã xử lý báo cáo",
    "verification.complete": "đã thẩm định sao", "verification.reject": "đã từ chối thẩm định",
    "sale_application.review": "đã xét hồ sơ Sale", "user.suspend": "đã khoá tài khoản",
    "user.reinstate": "đã mở khoá tài khoản", "user.revoke_sessions": "đã thu hồi phiên",
    "work_item.update": "đã cập nhật công việc", "deposit.verify": "đã xác minh chứng từ cọc",
    "payment.record": "đã ghi nhận thanh toán", "refund.record": "đã ghi nhận hoàn tiền",
    "kyc.approve": "đã duyệt KYC", "kyc.reject": "đã từ chối KYC",
    "staff.role_grant": "đã cấp vai quản trị", "staff.role_revoke": "đã thu hồi vai quản trị",
    "policy.deposit_create": "đã tạo chính sách cọc mới",
}

_HIDDEN_ACTIONS = ("permission.denied", "admin.login", "admin.logout", "admin.reauth", "admin.login_denied",
                   "admin.reauth_failed", "pii.reveal", "document.open")


@router.get("/activity")
def recent_activity(
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("dashboard.read")),
    db: Session = Depends(get_db),
):
    L = models.AdminActionLog
    q = db.query(L).filter(L.result == "success", L.action.notin_(_HIDDEN_ACTIONS)).order_by(L.id.desc())
    total = q.order_by(None).count()
    rows = q.offset(page.offset).limit(page.limit).all()
    cache: dict = {}
    data = []
    for r in rows:
        label = _ACTION_LABELS.get(r.action) or next(
            (v for k, v in _ACTION_LABELS.items() if r.action.startswith(k.split(".")[0] + ".")), r.action)
        data.append({
            "id": r.id, "action": r.action, "label": label, "actor": user_brief(db, r.actor_user_id, cache),
            "entity_type": r.entity_type, "entity_id": r.entity_id, "reason": r.reason,
            "created_at": iso(r.created_at),
        })
    return paged(data, total=total, page=page)


@router.get("/alerts")
def alerts(ctx: AdminContext = Depends(admin_context), db: Session = Depends(get_db)):
    out: list[dict] = []

    def add(level: str, title: str, detail: str, link: str):
        out.append({"level": level, "title": title, "detail": detail, "link": link})

    try:
        if ctx.has("payments.read"):
            n = _allocation_mismatches(db)
            if n:
                add("warning", f"{n} khoản tiền chênh lệch phân bổ", "Cần kiểm tra và đối soát thủ công", "/admin/finance/reconciliation")
        if ctx.has("system.read"):
            n = db.query(models.PushOutbox).filter(models.PushOutbox.gui_luc.is_(None), models.PushOutbox.so_lan_thu >= 3).count()
            if n:
                add("error", f"{n} thông báo gửi thất bại", "Không gửi được push đến người dùng", "/admin/system/notifications")
        if ctx.has("work_items.read"):
            items, counts, _t = wi.collect(db, ctx)
            od = sum(1 for it in items if it["overdue"])
            if od:
                add("warning", f"{od} việc quá hạn SLA", "Ưu tiên xử lý hoặc phân công lại", "/admin/work?overdue=yes")
            broken = [k for k, v in counts.items() if v < 0]
            if broken:
                add("error", "Một số hàng đợi không tải được", ", ".join(broken), "/admin/work")
        pending_cr = db.query(models.AdminChangeRequest).filter_by(status="PENDING").all()
        mine = [r for r in pending_cr if r.requested_by != ctx.user_id]
        if mine and (ctx.has("users.manage_admin_roles") or ctx.has("payments.refund")):
            add("info", f"{len(mine)} yêu cầu chờ phê duyệt (maker-checker)", "Cần một người khác duyệt", "/admin/approvals")
    except Exception as exc:  # noqa: BLE001
        db.rollback()
        logger.warning("alerts failed: %s", exc)
        add("error", "Không tải đủ cảnh báo", "Một phần dữ liệu cảnh báo lỗi", "/admin/system/health")
    return one(out)


@router.get("/badges")
def badges(ctx: AdminContext = Depends(admin_context), db: Session = Depends(get_db)):
    """Số việc mở theo module — badge trên sidebar."""
    if not ctx.has("work_items.read"):
        return one({})
    _items, counts, _t = wi.collect(db, ctx)
    by_mod: dict[str, int] = {}
    for s in wi.visible_sources(ctx):
        n = counts.get(s.code, 0)
        if n > 0:
            by_mod[s.module] = by_mod.get(s.module, 0) + n
    by_mod["total"] = sum(v for k, v in by_mod.items())
    return one({"modules": by_mod, "types": counts})


# ── Tìm kiếm toàn cục ─────────────────────────────────────────────────────────


@router.get("/search")
def global_search(
    q: str = Query(..., min_length=1, max_length=100),
    ctx: AdminContext = Depends(admin_context),
    db: Session = Depends(get_db),
):
    """Tìm theo mã (TIN-00123, HT-00045, BK-…), ID, tên, email, SĐT."""
    term = q.strip()
    upper = term.upper()
    results: list[dict] = []
    num: Optional[int] = None
    prefix = ""
    if "-" in upper:
        prefix, _, rest = upper.partition("-")
        if rest.isdigit():
            num = int(rest)
    elif term.isdigit():
        num = int(term)

    def add(kind: str, id_: Any, title: str, subtitle: str, link: str):
        results.append({"kind": kind, "id": str(id_), "title": title, "subtitle": subtitle, "link": link})

    if ctx.has("users.read"):
        like = f"%{term.lower()}%"
        conds = [func.lower(models.User.name).like(like), func.lower(models.User.email).like(like),
                 models.User.phone.like(f"%{term}%")]
        if num is not None and prefix in ("", "US"):
            conds.append(models.User.id == num)
        for u in db.query(models.User).filter(or_(*conds)).limit(5).all():
            add("user", u.id, u.name or "—", f"{mask_email(u.email) or ''} {mask_phone(u.phone) or ''}".strip(),
                f"/admin/users/{u.id}")
    if ctx.has("listings.read"):
        hq = db.query(models.House)
        if num is not None and prefix in ("", "TIN"):
            hq = hq.filter(models.House.id == num)
        else:
            hq = hq.filter(func.lower(models.House.title).like(f"%{term.lower()}%"))
        for h in hq.limit(5).all():
            add("listing", h.id, h.title or "Tin", f"TIN-{h.id:05d} · {h.status}", f"/admin/content/listings/{h.id}")
    if ctx.has("rental_journeys.read") and num is not None:
        if prefix in ("", "HT"):
            j = db.get(models.RentalJourney, num)
            if j:
                add("journey", j.id, f"Hành trình HT-{j.id:05d}", j.status, f"/admin/rentals/journeys/{j.id}")
        if prefix in ("", "BK"):
            r = db.get(models.Reservation, num)
            if r:
                add("reservation", r.id, f"Booking BK-{r.id:05d}", f"{r.status} · {r.check_in_date}",
                    f"/admin/rentals/reservations/{r.id}")
    if ctx.has("rental_journeys.read") and prefix not in ("", "HT", "BK", "TIN", "US"):
        r = db.query(models.Reservation).filter(models.Reservation.booking_code == term).first()
        if r:
            add("reservation", r.id, f"Booking {r.booking_code}", r.status, f"/admin/rentals/reservations/{r.id}")
    return one(results)
