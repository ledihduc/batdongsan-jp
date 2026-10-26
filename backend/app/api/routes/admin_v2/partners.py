"""Đối tác + cấu hình — hồ sơ Sale, liên kết Sale↔chủ, nhà thầu, lead, yêu cầu
dịch vụ, chính sách cọc, tỉnh quy hoạch, danh mục.

Thay các màn cũ (`/api/v2/admin/sale-applications`, `/api/construction/admin/*`,
`/api/admin/leads` — 500 dòng kèm SĐT thật, `/api/services/requests`,
`/api/planning/admin/*`, `/api/v2/admin/activity-policy/deposits`). Endpoint cũ
GIỮ NGUYÊN; logic đổi trạng thái dùng chung ở `services/admin_v2/partners_ops.py`.

SĐT/email luôn che; xem số thật để gọi lại đi qua `reveal-contact` (bắt buộc lý
do, mỗi lần xem là một dòng nhật ký). Giấy tờ (ảnh minh chứng, GCN ĐKDN) chỉ trả
đường dẫn kèm cờ `private` — module chứng từ sẽ cấp link xem có ký.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Literal, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import helpers, models
from app.database import get_db
from app.domain.service_request import Service, ServiceRequest
from app.services.admin_v2 import change_requests, partners_ops
from app.services.admin_v2.content_ops import OpsError
from app.services.admin_v2.core import (
    utcnow,
    AdminContext, CommandResult, PageParams, etag, fail, idempotency_key, if_match, iso, mask_email,
    mask_phone, one, page_params, paged, paginate, record_read, require_any_permission,
    require_permission, run_command, user_brief,
)

router = APIRouter(prefix="/api/v2/admin", tags=["admin-v2-partners"])


def _ops_fail(exc: OpsError):
    return fail(exc.status, exc.code if exc.code.startswith("ADMIN_") else f"ADMIN_{exc.code}", exc.message)


def _like(term: str) -> str:
    esc = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{esc.lower()}%"


def _id_term(term: str, *prefixes: str) -> Optional[int]:
    t = term.strip().upper()
    for p in prefixes:
        t = t.removeprefix(p)
    return int(t) if t.isdigit() else None


def _doc(path: Optional[str]) -> Optional[dict]:
    """Giấy tờ riêng tư: chỉ trả đường dẫn thô + cờ, FE KHÔNG nhúng trực tiếp."""
    if not path:
        return None
    return {"path": path, "private": True}


def _count(db: Session, model, *conds) -> int:
    return int(db.query(func.count()).select_from(model).filter(*conds).scalar() or 0)


# ══ Hồ sơ Sale ═══════════════════════════════════════════════════════════════

APP_OPEN = ("SUBMITTED", "IN_REVIEW")
APP_STATUSES = ("SUBMITTED", "IN_REVIEW", "REQUEST_CHANGES", "APPROVED", "REJECTED", "WITHDRAWN")


def _app_version(a: models.SaleApplication) -> str:
    return str(a.version)


def _app_row(db: Session, a: models.SaleApplication, cache: dict) -> dict:
    return {
        "id": a.id,
        "ref": f"SA-{a.id:05d}",
        "status": a.status,
        "full_name": a.full_name,
        "email_masked": mask_email(a.email),
        "phone_masked": mask_phone(a.phone),
        "applicant": user_brief(db, a.applicant_user_id, cache),
        "service_areas": a.service_areas or [],
        "evidence_count": len(a.evidence_urls or []),
        "submitted_at": iso(a.submitted_at),
        "reviewed_at": iso(a.reviewed_at),
        "reviewed_by": user_brief(db, a.reviewed_by, cache),
        "review_note": a.review_note,
        "rejection_code": a.rejection_code,
        "approved_sale_profile_id": a.approved_sale_profile_id,
        "version": _app_version(a),
    }


def _allowed_app_decisions(a: models.SaleApplication) -> list[str]:
    if a.status == "SUBMITTED":
        return ["start_review", "approve", "reject", "request_changes"]
    if a.status in ("IN_REVIEW", "REQUEST_CHANGES"):
        return ["approve", "reject", "request_changes"]
    return []


@router.get("/partners/sale-applications")
def list_sale_applications(
    status: str = Query("open", max_length=20),
    q: str = Query("", max_length=200),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("partners.read")),
    db: Session = Depends(get_db),
):
    A = models.SaleApplication
    query = db.query(A)
    st = status.upper()
    if st == "OPEN":
        query = query.filter(A.status.in_(APP_OPEN))
    elif st != "ALL":
        if st not in APP_STATUSES:
            raise fail(422, "ADMIN_BAD_FILTER", "Trạng thái hồ sơ không hợp lệ")
        query = query.filter(A.status == st)
    term = q.strip()
    if term:
        conds = [func.lower(A.full_name).like(_like(term), escape="\\"),
                 func.lower(A.email).like(_like(term), escape="\\"), A.phone.like(f"%{term}%")]
        rid = _id_term(term, "SA-")
        if rid is not None:
            conds += [A.id == rid, A.applicant_user_id == rid]
        query = query.filter(or_(*conds))
    order = (A.submitted_at.asc(), A.id.asc()) if st == "OPEN" else (A.submitted_at.desc(), A.id.desc())
    rows, total = paginate(query.order_by(*order), page)
    cache: dict = {}
    return paged([_app_row(db, a, cache) for a in rows], total=total, page=page)


def _load_app(db: Session, app_id: int) -> models.SaleApplication:
    a = db.get(models.SaleApplication, app_id)
    if a is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy hồ sơ Sale")
    return a


def _app_detail(db: Session, a: models.SaleApplication, cache: dict) -> dict:
    applicant = db.get(models.User, a.applicant_user_id)
    E = models.ActivityAuditEvent
    history = (
        db.query(E).filter(E.target_type == "sale_application", E.target_id == a.id)
        .order_by(E.created_at.desc(), E.id.desc()).limit(30).all()
    )
    return {
        **_app_row(db, a, cache),
        "bio": a.bio,
        "evidence": [_doc(u) for u in (a.evidence_urls or []) if u],
        "applicant_account": None if applicant is None else {
            "account_type": applicant.account_type or "customer",
            "is_active": bool(applicant.is_active),
            "joined_at": iso(applicant.created_at),
            "owns_buildings": _count(db, models.Building, models.Building.host_id == applicant.id),
            "has_sale_profile": db.query(models.SaleProfile.id).filter_by(user_id=applicant.id).first() is not None,
        },
        "previous_applications": _count(
            db, models.SaleApplication, models.SaleApplication.applicant_user_id == a.applicant_user_id,
            models.SaleApplication.id != a.id),
        "history": [{"action": e.action, "actor": user_brief(db, e.actor_user_id, cache), "payload": e.payload,
                     "at": iso(e.created_at)} for e in history],
        "allowed_decisions": _allowed_app_decisions(a),
    }


@router.get("/partners/sale-applications/{app_id}")
def get_sale_application(
    app_id: int,
    ctx: AdminContext = Depends(require_permission("partners.read")),
    db: Session = Depends(get_db),
):
    return one(_app_detail(db, _load_app(db, app_id), {}))


class SaleAppDecisionBody(BaseModel):
    decision: Literal["approve", "reject", "request_changes", "start_review"]
    reason: str = Field("", max_length=2000)
    rejection_code: Optional[str] = Field(None, max_length=80)


@router.post("/partners/sale-applications/{app_id}/decisions")
def decide_sale_application(
    app_id: int,
    body: SaleAppDecisionBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("partners.review")),
    db: Session = Depends(get_db),
):
    a = _load_app(db, app_id)

    def do() -> CommandResult:
        if body.decision not in _allowed_app_decisions(a):
            raise fail(409, "ADMIN_INVALID_TRANSITION", f"Hồ sơ đang ở trạng thái {a.status}")
        before = {"status": a.status, "version": a.version}
        try:
            if body.decision == "start_review":
                partners_ops.start_sale_application_review(a, admin_id=ctx.user_id)
            else:
                code = (body.rejection_code or "").strip()
                if body.decision != "approve" and not code:
                    code = "OTHER"  # luồng cũ bắt buộc mã; V2 bắt buộc lý do chữ
                partners_ops.review_sale_application(
                    db, a, admin_id=ctx.user_id, decision=body.decision.upper(),
                    reason_code=code or None, review_note=body.reason,
                )
        except OpsError as exc:
            raise _ops_fail(exc)
        # Giữ dòng nhật ký nghiệp vụ cũ để lịch sử hồ sơ (cả hai đường) ở một chỗ.
        partners_ops.add_activity_audit(
            db, actor_user_id=ctx.user_id,
            action="SALE_APPLICATION_START_REVIEW" if body.decision == "start_review" else "SALE_APPLICATION_REVIEW",
            idempotency_key=f"admin-v2:{key}", target_type="sale_application", target_id=a.id,
            payload={"decision": body.decision.upper(), "status": a.status, "via": "admin_v2"},
        )
        if body.decision != "start_review":
            title, text = {
                "approve": ("Hồ sơ Sale đã được duyệt", "Chúc mừng! Bạn đã được cấp quyền Sale."),
                "reject": ("Hồ sơ Sale chưa được duyệt", f"Lý do: {body.reason.strip()}"),
                "request_changes": ("Hồ sơ Sale cần bổ sung", f"Vui lòng bổ sung: {body.reason.strip()}"),
            }[body.decision]
            helpers.push_notification(db, a.applicant_user_id, f"sale_application_{body.decision}", title, text, a.id)
        db.flush()
        return CommandResult(data=_app_detail(db, a, {}), before=before,
                             after={"status": a.status, "version": a.version}, event_status=a.status)

    return run_command(
        db, ctx, action=f"sale_application.{body.decision}", permission="partners.review",
        entity_type="sale_application", entity_id=app_id, key=key, fn=do, reason=body.reason,
        reason_required=body.decision in ("reject", "request_changes"),
        expected_version=expected, current_version=lambda: _app_version(a),
        event_type="sale_application.decided",
    )


# ══ Sale + liên kết ══════════════════════════════════════════════════════════


@router.get("/partners/sales")
def list_sales(
    q: str = Query("", max_length=200),
    verified: Optional[bool] = None,
    trusted: Optional[bool] = None,
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("partners.read")),
    db: Session = Depends(get_db),
):
    S, U = models.SaleProfile, models.User
    query = db.query(S)
    if verified is not None:
        query = query.filter(S.verified == verified)
    if trusted is not None:
        query = query.filter(S.trusted == trusted)
    term = q.strip()
    if term:
        conds = [func.lower(S.display_name).like(_like(term), escape="\\"),
                 func.upper(S.sale_code) == term.upper(),
                 S.user_id.in_(db.query(U.id).filter(func.lower(U.name).like(_like(term), escape="\\")))]
        if term.isdigit():
            conds += [S.id == int(term), S.user_id == int(term)]
        query = query.filter(or_(*conds))
    rows, total = paginate(query.order_by(S.created_at.desc(), S.id.desc()), page)
    L = models.SaleOwnerLink
    uids = [s.user_id for s in rows]
    links = dict(
        db.query(L.sale_id, func.count(L.id)).filter(L.sale_id.in_(uids), L.status == "active")
        .group_by(L.sale_id).all()
    ) if uids else {}
    cache: dict = {}
    data = [{
        "id": s.id, "user": user_brief(db, s.user_id, cache), "sale_code": s.sale_code,
        "display_name": s.display_name, "verified": bool(s.verified), "trusted": bool(s.trusted),
        "service_areas": s.service_areas or [], "commission_percent": s.hoa_hong_phan_tram,
        "active_links": int(links.get(s.user_id, 0)), "created_at": iso(s.created_at),
    } for s in rows]
    return paged(data, total=total, page=page)


@router.get("/partners/sale-owner-links")
def list_sale_owner_links(
    status: str = Query("", pattern="^(|pending|active|transfer_pending|ended)$"),
    sale_id: Optional[int] = None,
    owner_id: Optional[int] = None,
    building_id: Optional[int] = None,
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("partners.read")),
    db: Session = Depends(get_db),
):
    L = models.SaleOwnerLink
    query = db.query(L)
    if status:
        query = query.filter(L.status == status)
    if sale_id is not None:
        query = query.filter(L.sale_id == sale_id)
    if owner_id is not None:
        query = query.filter(L.owner_id == owner_id)
    if building_id is not None:
        query = query.filter(L.building_id == building_id)
    rows, total = paginate(query.order_by(L.linked_at.desc(), L.id.desc()), page)
    bids = {r.building_id for r in rows if r.building_id}
    buildings = {b.id: b for b in db.query(models.Building).filter(models.Building.id.in_(bids)).all()} if bids else {}
    cache: dict = {}
    data = []
    for r in rows:
        b = buildings.get(r.building_id)
        data.append({
            "id": r.id, "status": r.status,
            "sale": user_brief(db, r.sale_id, cache), "owner": user_brief(db, r.owner_id, cache),
            "building": None if b is None else {"id": b.id, "name": b.name, "address": b.address},
            "linked_at": iso(r.linked_at), "ended_at": iso(r.ended_at), "end_reason": r.end_reason,
            "created_by": user_brief(db, r.created_by, cache),
        })
    return paged(data, total=total, page=page)


# ══ Lead gọi lại ═════════════════════════════════════════════════════════════

LEAD_STATUSES = ("new", "contacted", "converted", "spam", "closed")


def _lead_version(l: models.ContactLead) -> str:
    return etag(l.id, l.status)


def _lead_row(db: Session, l: models.ContactLead, cache: dict) -> dict:
    return {
        "id": l.id, "ref": f"LD-{l.id:05d}", "name": l.name, "phone_masked": mask_phone(l.phone),
        "source": l.source, "context": l.context, "world": l.world, "province_code": l.province_code,
        "status": l.status, "user": user_brief(db, l.user_id, cache), "created_at": iso(l.created_at),
        "version": _lead_version(l),
    }


@router.get("/partners/leads")
def list_leads(
    status: str = Query("", max_length=20),
    source: str = Query("", max_length=50),
    province: str = Query("", max_length=32),
    q: str = Query("", max_length=200),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("partners.read")),
    db: Session = Depends(get_db),
):
    L = models.ContactLead
    query = db.query(L)
    if status:
        query = query.filter(L.status == status)
    if source:
        query = query.filter(L.source == source)
    if province:
        query = query.filter(L.province_code == province)
    term = q.strip()
    if term:
        conds = [func.lower(L.name).like(_like(term), escape="\\"), L.phone.like(f"%{term}%")]
        rid = _id_term(term, "LD-")
        if rid is not None:
            conds.append(L.id == rid)
        query = query.filter(or_(*conds))
    rows, total = paginate(query.order_by(L.created_at.desc(), L.id.desc()), page)
    cache: dict = {}
    return paged([_lead_row(db, l, cache) for l in rows], total=total, page=page)


class LeadStatusBody(BaseModel):
    status: Literal["new", "contacted", "converted", "spam", "closed"]
    note: str = Field("", max_length=1000)


@router.post("/partners/leads/{lead_id}/status")
def set_lead_status(
    lead_id: int,
    body: LeadStatusBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("partners.review")),
    db: Session = Depends(get_db),
):
    l = db.get(models.ContactLead, lead_id)
    if l is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy lead")

    def do() -> CommandResult:
        if l.status == body.status:
            raise fail(409, "ADMIN_CONFLICT", "Lead đã ở trạng thái này")
        before = {"status": l.status}
        l.status = body.status
        # Bảng lead không có cột ghi chú: ghi chú nằm ở nhật ký quản trị (reason).
        return CommandResult(data=_lead_row(db, l, {}), before=before, after={"status": l.status},
                             event_status=l.status)

    return run_command(
        db, ctx, action="lead.status", permission="partners.review", entity_type="contact_lead",
        entity_id=lead_id, key=key, fn=do, reason=body.note, reason_required=body.status in ("spam", "closed"),
        expected_version=expected, current_version=lambda: _lead_version(l),
    )




# ══ Yêu cầu dịch vụ ══════════════════════════════════════════════════════════


def _sr_version(r: ServiceRequest) -> str:
    return etag(r.id, r.status, iso(r.scheduled_at), r.admin_note)


def _sr_row(r: ServiceRequest, names: dict) -> dict:
    return {
        "id": r.id, "ref": f"DV-{r.id:05d}", "service_slug": r.service_slug,
        "service_name": names.get(r.service_slug, r.service_slug), "name": r.name,
        "phone_masked": mask_phone(r.phone), "area": r.area, "budget": r.budget,
        "description": r.description, "province_code": r.province_code, "location_text": r.location_text,
        "status": r.status, "scheduled_at": iso(r.scheduled_at), "contacted_at": iso(r.contacted_at),
        "admin_note": r.admin_note, "source": r.source, "has_account": r.user_id is not None,
        "created_at": iso(r.created_at), "version": _sr_version(r),
    }


def _service_names(db: Session) -> dict:
    return {s.slug: s.name for s in db.query(Service).all()}


@router.get("/partners/service-requests")
def list_service_requests(
    status: str = Query("", max_length=20),
    service_slug: str = Query("", max_length=40),
    province: str = Query("", max_length=32),
    q: str = Query("", max_length=200),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("partners.read")),
    db: Session = Depends(get_db),
):
    query = db.query(ServiceRequest)
    if status:
        query = query.filter(ServiceRequest.status == status)
    if service_slug:
        query = query.filter(ServiceRequest.service_slug == service_slug)
    if province:
        query = query.filter(ServiceRequest.province_code == province)
    term = q.strip()
    if term:
        conds = [func.lower(ServiceRequest.name).like(_like(term), escape="\\"),
                 ServiceRequest.phone.like(f"%{term}%")]
        rid = _id_term(term, "DV-")
        if rid is not None:
            conds.append(ServiceRequest.id == rid)
        query = query.filter(or_(*conds))
    rows, total = paginate(query.order_by(ServiceRequest.created_at.desc(), ServiceRequest.id.desc()), page)
    names = _service_names(db)
    return paged([_sr_row(r, names) for r in rows], total=total, page=page)


class ServiceRequestUpdateBody(BaseModel):
    status: Optional[Literal["new", "contacted", "scheduled", "done", "cancelled", "spam"]] = None
    scheduled_at: Optional[datetime] = None
    admin_note: Optional[str] = Field(None, max_length=4000)
    reason: str = Field("", max_length=1000)


@router.post("/partners/service-requests/{req_id}/update")
def update_service_request(
    req_id: int,
    body: ServiceRequestUpdateBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("partners.review")),
    db: Session = Depends(get_db),
):
    r = db.get(ServiceRequest, req_id)
    if r is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy yêu cầu dịch vụ")
    if body.status is None and body.scheduled_at is None and body.admin_note is None:
        raise fail(422, "ADMIN_NOTHING_TO_UPDATE", "Không có thay đổi nào")

    def do() -> CommandResult:
        before = {"status": r.status, "scheduled_at": iso(r.scheduled_at)}
        partners_ops.update_service_request(
            r, status=body.status, scheduled_at=body.scheduled_at, admin_note=body.admin_note)
        return CommandResult(data=_sr_row(r, _service_names(db)), before=before,
                             after={"status": r.status, "scheduled_at": iso(r.scheduled_at)}, event_status=r.status)

    return run_command(
        db, ctx, action="service_request.update", permission="partners.review", entity_type="service_request",
        entity_id=req_id, key=key, fn=do, reason=body.reason or body.admin_note,
        reason_required=body.status in ("spam", "cancelled"),
        expected_version=expected, current_version=lambda: _sr_version(r),
    )


# ══ Xem liên hệ thật (có lý do + nhật ký) ════════════════════════════════════

_CONTACT_SOURCES = {
    "leads": (models.ContactLead, "contact_lead"),
    "service-requests": (ServiceRequest, "service_request"),
    "sale-applications": (models.SaleApplication, "sale_application"),
}


class RevealBody(BaseModel):
    reason: str = Field("", max_length=500)


@router.post("/partners/{kind}/{item_id}/reveal-contact")
def reveal_contact(
    kind: Literal["leads", "service-requests", "sale-applications"],
    item_id: int,
    body: RevealBody,
    ctx: AdminContext = Depends(require_permission("partners.review")),
    db: Session = Depends(get_db),
):
    reason = body.reason.strip()
    if len(reason) < 5:
        raise fail(422, "ADMIN_REASON_REQUIRED", "Cần nhập lý do (ít nhất 5 ký tự)")
    model, etype = _CONTACT_SOURCES[kind]
    row = db.get(model, item_id)
    if row is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy bản ghi")
    record_read(db, ctx, action="pii.reveal_contact", permission="partners.review",
                entity_type=etype, entity_id=item_id, reason=reason)
    return one({"id": item_id, "kind": kind, "name": getattr(row, "name", None) or getattr(row, "full_name", None),
                "phone": getattr(row, "phone", None) or None, "email": getattr(row, "email", None) or None})


# ══ Cấu hình: chính sách cọc ═════════════════════════════════════════════════


POLICY_KIND = "deposit_policy"


def _policy_requests(db: Session, ctx: AdminContext, statuses: tuple[str, ...], limit: int = 20) -> list[dict]:
    CR = models.AdminChangeRequest
    q = db.query(CR).filter(CR.kind == POLICY_KIND, CR.status.in_(statuses))
    # Bản nháp chỉ người lập thấy.
    rows = [r for r in q.order_by(CR.requested_at.desc()).limit(limit * 2).all()
            if r.status != "DRAFT" or r.requested_by == ctx.user_id][:limit]
    cache: dict = {}
    return [change_requests.to_dict(db, r, cache, detail=True) for r in rows]


def _policy_state(db: Session, ctx: Optional[AdminContext] = None) -> dict:
    V = models.ActivityPolicyVersion
    history = db.query(V).order_by(V.policy_version.desc()).limit(20).all()
    cache: dict = {}
    active = partners_ops.active_policy(db)
    out = {
        "active": partners_ops.policy_payload(active),
        "history": [{**partners_ops.policy_payload(v), "created_by": user_brief(db, v.created_by, cache),
                     "created_at": iso(v.created_at),
                     "state": ("active" if active is not None and v.id == active.id
                               else "scheduled" if v.effective_at > utcnow() else "archived")}
                    for v in history],
        "version": str(partners_ops.latest_policy_version(db)),
        "scope_note": "Chỉ áp dụng cho giao dịch tạo SAU thời điểm hiệu lực; giao dịch cũ giữ ảnh chụp chính sách của nó.",
    }
    if ctx is not None:
        out["open_requests"] = _policy_requests(db, ctx, ("DRAFT", "PENDING"))
        out["decided_requests"] = _policy_requests(db, ctx, ("APPROVED", "REJECTED", "CANCELLED"))
    return out


@router.get("/settings/deposit-policy")
def get_deposit_policy(
    ctx: AdminContext = Depends(require_permission("policies.manage")),
    db: Session = Depends(get_db),
):
    return one(_policy_state(db, ctx))


class DepositPolicyBody(BaseModel):
    short_stay_primary_deposit_percent: Decimal = Field(ge=0, le=100)
    long_term_platform_deposit_percent: Decimal = Field(ge=0, le=100)
    effective_at: Optional[datetime] = None
    reason: str = Field("", max_length=500)
    #: false = lưu bản nháp (người lập còn sửa); true = gửi ngay cho người duyệt.
    submit: bool = True


def _validate_policy(db: Session, payload: dict) -> dict:
    try:
        short = Decimal(str(payload.get("short_stay_primary_deposit_percent")))
        long_ = Decimal(str(payload.get("long_term_platform_deposit_percent")))
    except Exception:  # noqa: BLE001
        raise fail(422, "ADMIN_VALIDATION", "Tỷ lệ cọc không hợp lệ")
    if not (0 <= short <= 100 and 0 <= long_ <= 100):
        raise fail(422, "ADMIN_VALIDATION", "Tỷ lệ cọc phải trong khoảng 0–100%")
    eff = payload.get("effective_at")
    if eff:
        try:
            eff_dt = datetime.fromisoformat(str(eff).replace("Z", "+00:00"))
            # Có múi giờ → ĐỔI về UTC trước khi bỏ múi (cắt thẳng làm lệch 7 giờ).
            if eff_dt.tzinfo is not None:
                eff_dt = eff_dt.astimezone(timezone.utc)
            eff_dt = eff_dt.replace(tzinfo=None)
        except ValueError:
            raise fail(422, "ADMIN_VALIDATION", "Thời điểm áp dụng không hợp lệ")
        if eff_dt < utcnow() - timedelta(minutes=1):
            raise fail(422, "ADMIN_ACTIVITY_POLICY_EFFECTIVE_TIME_INVALID", "Thời điểm áp dụng không được ở quá khứ")
        eff = eff_dt.isoformat(timespec="seconds")
    return {"short_stay_primary_deposit_percent": str(short), "long_term_platform_deposit_percent": str(long_),
            "effective_at": eff or None}


def _preview_policy(db: Session, payload: dict) -> list:
    cur = partners_ops.policy_payload(partners_ops.active_policy(db))
    long_ = Decimal(str(payload.get("long_term_platform_deposit_percent") or 0))
    return [
        {"label": "Cọc giữ chỗ ngắn hạn", "hint": "% tổng tiền phòng khách đặt cọc khi đặt ngắn hạn",
         "before": f"{cur['short_stay_primary_deposit_percent']}%", "after": f"{payload.get('short_stay_primary_deposit_percent')}%"},
        {"label": "Cọc nền tảng (dài hạn)", "hint": "Phần cọc khách chuyển cho nền tảng",
         "before": f"{cur['long_term_platform_deposit_percent']}%", "after": f"{payload.get('long_term_platform_deposit_percent')}%"},
        {"label": "Cọc chủ nhà (dài hạn)", "hint": "Phần còn lại khách chuyển thẳng cho chủ nhà",
         "before": f"{cur['long_term_owner_deposit_percent']}%", "after": f"{format((Decimal(100) - long_).normalize(), 'f')}%"},
        {"label": "Phạm vi áp dụng", "hint": "Giao dịch đã tạo giữ chính sách cũ",
         "before": "Giao dịch mới", "after": "Giao dịch mới"},
        {"label": "Thời điểm áp dụng", "before": iso(datetime.fromisoformat(cur["effective_at"])) if cur.get("effective_at") else "Mặc định",
         "after": payload.get("effective_at") and (payload["effective_at"] + "Z") or "Ngay khi được duyệt"},
    ]


def _exec_policy(db: Session, approver: AdminContext, payload: dict) -> dict:
    eff = payload.get("effective_at")
    eff_dt = datetime.fromisoformat(eff) if eff else None
    # Duyệt muộn hơn giờ hẹn → áp dụng ngay lúc duyệt (không ghi lùi về quá khứ).
    if eff_dt is not None and eff_dt < utcnow():
        eff_dt = None
    try:
        item = partners_ops.create_deposit_policy_version(
            db, admin_id=int(payload.get("_requested_by") or approver.user_id),
            short_stay_percent=Decimal(payload["short_stay_primary_deposit_percent"]),
            long_term_platform_percent=Decimal(payload["long_term_platform_deposit_percent"]),
            effective_at=eff_dt, reason=str(payload.get("_reason") or "maker-checker"),
        )
    except OpsError as exc:
        raise _ops_fail(exc)
    return {"policy_version": item.policy_version, "effective_at": iso(item.effective_at), "approved_by": approver.user_id}


def _describe_policy(db: Session, payload: dict) -> str:
    return (f"Chính sách cọc v{partners_ops.latest_policy_version(db) + 1}: ngắn hạn "
            f"{payload.get('short_stay_primary_deposit_percent')}% · nền tảng dài hạn "
            f"{payload.get('long_term_platform_deposit_percent')}%")


change_requests.register(
    POLICY_KIND, permission="policies.manage", label="Thay đổi chính sách cọc",
    executor=_exec_policy, describe=_describe_policy, validate=_validate_policy, preview=_preview_policy,
    links=lambda db, p: [{"label": "Chính sách cọc", "ref": "Cấu hình", "href": "/admin/finance/policy"}],
)


@router.post("/settings/deposit-policy")
def create_deposit_policy(
    body: DepositPolicyBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(require_permission("policies.manage")),
    db: Session = Depends(get_db),
):
    """Đề xuất phiên bản chính sách mới — KHÔNG áp dụng ngay: một người có quyền
    policies.manage KHÁC phải duyệt (maker-checker), rồi mới tạo phiên bản."""

    def do() -> CommandResult:
        payload = {
            "short_stay_primary_deposit_percent": str(body.short_stay_primary_deposit_percent),
            "long_term_platform_deposit_percent": str(body.long_term_platform_deposit_percent),
            "effective_at": (body.effective_at.astimezone(timezone.utc) if body.effective_at.tzinfo else body.effective_at).replace(tzinfo=None).isoformat() if body.effective_at else None,
        }
        req = change_requests.create(db, ctx, kind=POLICY_KIND, payload=payload, reason=body.reason.strip(),
                                     status="PENDING" if body.submit else "DRAFT")
        return CommandResult(
            data={"pending_approval": body.submit, "change_request": change_requests.to_dict(db, req, detail=True)},
            after={"change_request_id": req.id, "status": req.status}, entity_id=req.id,
            event_status=req.status,
        )

    return run_command(
        db, ctx, action="deposit_policy.request", permission="policies.manage",
        entity_type="change_request", entity_id=None, key=key, fn=do, reason=body.reason,
        reason_required=body.submit, reauth=body.submit, event_type="admin.work_item.created",
    )


# ══ Cấu hình: danh mục (chỉ đọc) ═════════════════════════════════════════════


@router.get("/settings/catalog")
def get_catalog(
    ctx: AdminContext = Depends(require_any_permission("settings.manage", "listings.read", "partners.read")),
    db: Session = Depends(get_db),
):
    cats = db.query(models.Category).order_by(models.Category.sort_order.asc(), models.Category.id.asc()).all()
    ams = db.query(models.Amenity).order_by(models.Amenity.id.asc()).all()
    svcs = db.query(Service).order_by(Service.sort_order.asc(), Service.id.asc()).all()
    return one({
        "categories": [{"id": c.id, "name": c.name, "icon": c.icon, "group_key": c.group_key,
                        "sort_order": c.sort_order, "is_active": bool(c.is_active)} for c in cats],
        "amenities": [{"id": a.id, "name": a.name, "icon": a.icon} for a in ams],
        "services": [{"slug": s.slug, "name": s.name, "icon": s.icon, "is_active": bool(s.is_active)} for s in svcs],
    })
