"""Nhân viên quản trị, vai và yêu cầu maker-checker.

Luật:
  - Không ai tự đổi vai của chính mình (kể cả SUPER_ADMIN).
  - Cấp SUPER_ADMIN KHÔNG chạy ngay: tạo yêu cầu, một SUPER_ADMIN KHÁC duyệt.
  - Không thu hồi được SUPER_ADMIN cuối cùng (khoá cửa nhốt cả đội ở ngoài).
  - Mọi lệnh cần phiên admin vừa xác thực lại.
"""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.services.admin_v2 import change_requests, rbac, sessions
from app.services.admin_v2.core import (
    AdminContext, CommandResult, PageParams, admin_context, fail, idempotency_key, if_match, iso,
    mask_email, mask_phone, one, page_params, paged, paginate, require_permission, run_command,
    user_brief, utcnow,
)
from app.services.admin_v2.permissions import MAKER_CHECKER_ROLES, PERMISSIONS, ROLES

router = APIRouter(prefix="/api/v2/admin", tags=["admin-v2-staff"])
PERM = "users.manage_admin_roles"


class RoleBody(BaseModel):
    role_code: str = Field(..., max_length=40)
    reason: str = Field("", max_length=500)
    #: "Đổi vai": thu luôn vai cũ này CÙNG LÚC cấp vai mới (với maker-checker:
    #: chỉ khi được duyệt — không có khoảng trống quyền hay chồng quyền tạm).
    replace_role: Optional[str] = Field(None, max_length=40)


class ReasonBody(BaseModel):
    reason: str = Field("", max_length=500)


class DecisionBody(BaseModel):
    note: str = Field("", max_length=500)


# ── Danh mục ──────────────────────────────────────────────────────────────────


@router.get("/roles")
def list_roles(ctx: AdminContext = Depends(admin_context), db: Session = Depends(get_db)):
    # Số nhân viên ĐANG HOẠT ĐỘNG giữ từng vai — thẻ "Tổng quan vai trò".
    UR = models.AdminUserRole
    counts = dict(
        db.query(UR.role_code, func.count(func.distinct(UR.user_id)))
        .join(models.User, models.User.id == UR.user_id)
        .filter(UR.revoked_at.is_(None), models.User.is_active == True)  # noqa: E712
        .group_by(UR.role_code).all()
    )
    return one({
        "roles": [
            {"code": c, "name": n, "description": d, "permissions": list(p), "maker_checker": c in MAKER_CHECKER_ROLES,
             "member_count": int(counts.get(c, 0))}
            for c, (n, d, p) in ROLES.items()
        ],
        "permissions": [
            {"code": c, "module": m, "description": d} for c, (m, d) in PERMISSIONS.items()
        ],
    })


# ── Nhân viên ─────────────────────────────────────────────────────────────────


def _staff_dict(db: Session, user: models.User, cache: dict) -> dict:
    grants = (
        db.query(models.AdminUserRole)
        .filter(models.AdminUserRole.user_id == user.id)
        .order_by(models.AdminUserRole.granted_at.desc())
        .all()
    )
    last = (
        db.query(func.max(models.AdminSession.last_seen_at))
        .filter(models.AdminSession.user_id == user.id)
        .scalar()
    )
    active_sessions = (
        db.query(models.AdminSession)
        .filter(
            models.AdminSession.user_id == user.id,
            models.AdminSession.revoked_at.is_(None),
            models.AdminSession.expires_at > utcnow(),
        )
        .count()
    )
    return {
        "id": user.id,
        "name": user.name,
        "email_masked": mask_email(user.email),
        "phone_masked": mask_phone(user.phone),
        "is_active": bool(user.is_active),
        "roles": [
            {
                "grant_id": g.id,
                "code": g.role_code,
                "name": ROLES.get(g.role_code, (g.role_code,))[0],
                "granted_at": iso(g.granted_at),
                "granted_by": user_brief(db, g.granted_by, cache),
                "grant_reason": g.grant_reason,
                "revoked_at": iso(g.revoked_at),
                "revoked_by": user_brief(db, g.revoked_by, cache),
                "revoke_reason": g.revoke_reason,
                "active": g.revoked_at is None,
            }
            for g in grants
        ],
        "last_seen_at": iso(last),
        "active_sessions": active_sessions,
    }


@router.get("/staff")
def list_staff(
    q: str = Query("", max_length=100),
    role: str = Query("", max_length=40),
    include_revoked: bool = False,
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(PERM)),
    db: Session = Depends(get_db),
):
    sub = db.query(models.AdminUserRole.user_id)
    if not include_revoked:
        sub = sub.filter(models.AdminUserRole.revoked_at.is_(None))
    if role:
        sub = sub.filter(models.AdminUserRole.role_code == role)
    query = db.query(models.User).filter(models.User.id.in_(sub.distinct()))
    if q.strip():
        like = f"%{q.strip().lower()}%"
        query = query.filter(or_(func.lower(models.User.name).like(like), func.lower(models.User.email).like(like)))
    rows, total = paginate(query.order_by(models.User.id.asc()), page)
    cache: dict = {}
    return paged([_staff_dict(db, u, cache) for u in rows], total=total, page=page)


@router.get("/staff/{user_id}")
def get_staff(user_id: int, ctx: AdminContext = Depends(require_permission(PERM)), db: Session = Depends(get_db)):
    u = db.get(models.User, user_id)
    if u is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy người dùng")
    out = _staff_dict(db, u, {})
    rows = (
        db.query(models.AdminSession)
        .filter(models.AdminSession.user_id == user_id)
        .order_by(models.AdminSession.created_at.desc())
        .limit(20)
        .all()
    )
    out["sessions"] = [sessions.session_dict(s) for s in rows]
    return one(out)


def _target(db: Session, ctx: AdminContext, user_id: int) -> models.User:
    if user_id == ctx.user_id:
        raise fail(403, "ADMIN_SELF_ROLE_CHANGE", "Không thể tự thay đổi vai quản trị của chính mình")
    u = db.get(models.User, user_id)
    if u is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy người dùng")
    return u


@router.post("/staff/{user_id}/roles")
def grant_role(
    user_id: int,
    body: RoleBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(require_permission(PERM)),
    db: Session = Depends(get_db),
):
    if body.role_code not in ROLES or (body.replace_role and body.replace_role not in ROLES):
        raise fail(422, "ADMIN_UNKNOWN_ROLE", "Vai không tồn tại")
    if body.replace_role == body.role_code:
        raise fail(422, "ADMIN_VALIDATION", "Vai mới trùng vai hiện tại")
    target = _target(db, ctx, user_id)
    if body.replace_role and body.replace_role not in rbac.active_roles(db, user_id):
        raise fail(409, "ADMIN_ROLE_NOT_ACTIVE", "Người này không có vai cần thay")
    if not target.is_active:
        raise fail(409, "ADMIN_TARGET_LOCKED", "Tài khoản đang bị khoá — mở khoá trước khi cấp vai")

    if body.role_code in MAKER_CHECKER_ROLES:
        def create_request() -> CommandResult:
            req = change_requests.create(
                db, ctx, kind="grant_admin_role",
                payload={"user_id": user_id, "role_code": body.role_code, "replace_role": body.replace_role},
                reason=body.reason.strip(),
            )
            return CommandResult(
                data={"pending_approval": True, "change_request": change_requests.to_dict(db, req)},
                after={"change_request_id": req.id}, event_status="PENDING",
            )

        return run_command(
            db, ctx, action="staff.role_grant_requested", permission=PERM, entity_type="user",
            entity_id=user_id, key=key, fn=create_request, reason=body.reason, reason_required=True,
            reauth=True, event_type="admin.work_item.created",
        )

    def do() -> CommandResult:
        before = rbac.active_roles(db, user_id)
        rbac.grant_role(db, user_id=user_id, role_code=body.role_code, granted_by=ctx.user_id, reason=body.reason.strip())
        if body.replace_role:
            rbac.revoke_role(db, user_id=user_id, role_code=body.replace_role, revoked_by=ctx.user_id,
                             reason=f"đổi sang {body.role_code}: {body.reason.strip()}")
        return CommandResult(
            data={"pending_approval": False, "staff": _staff_dict(db, target, {})},
            before={"roles": before}, after={"roles": rbac.active_roles(db, user_id)},
        )

    return run_command(
        db, ctx, action="staff.role_grant", permission=PERM, entity_type="user", entity_id=user_id,
        key=key, fn=do, reason=body.reason, reason_required=True, reauth=True,
    )


@router.post("/staff/{user_id}/roles/{role_code}/revoke")
def revoke_role(
    user_id: int,
    role_code: str,
    body: ReasonBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(require_permission(PERM)),
    db: Session = Depends(get_db),
):
    target = _target(db, ctx, user_id)
    if role_code == "SUPER_ADMIN":
        supers = (
            db.query(models.AdminUserRole.user_id)
            .join(models.User, models.User.id == models.AdminUserRole.user_id)
            .filter(
                models.AdminUserRole.role_code == "SUPER_ADMIN",
                models.AdminUserRole.revoked_at.is_(None),
                models.User.is_active == True,  # noqa: E712
            )
            .distinct()
            .count()
        )
        if supers <= 1:
            raise fail(409, "ADMIN_LAST_SUPER_ADMIN", "Không thể thu hồi SUPER_ADMIN cuối cùng")

    def do() -> CommandResult:
        before = rbac.active_roles(db, user_id)
        if not rbac.revoke_role(db, user_id=user_id, role_code=role_code, revoked_by=ctx.user_id, reason=body.reason.strip()):
            raise fail(404, "ADMIN_ROLE_NOT_ACTIVE", "Người này không có vai đó")
        after = rbac.active_roles(db, user_id)
        if not after:
            # Hết vai = hết là nhân viên: phiên admin còn sống phải chết ngay.
            sessions.revoke_sessions(db, user_id=user_id, by=ctx.user_id, reason="mất toàn bộ vai quản trị")
        return CommandResult(
            data={"staff": _staff_dict(db, target, {})}, before={"roles": before}, after={"roles": after},
        )

    return run_command(
        db, ctx, action="staff.role_revoke", permission=PERM, entity_type="user", entity_id=user_id,
        key=key, fn=do, reason=body.reason, reason_required=True, reauth=True,
    )


@router.post("/staff/{user_id}/sessions/revoke")
def revoke_staff_sessions(
    user_id: int,
    body: ReasonBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(require_permission(PERM)),
    db: Session = Depends(get_db),
):
    if db.get(models.User, user_id) is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy người dùng")

    def do() -> CommandResult:
        n = sessions.revoke_sessions(
            db, user_id=user_id, by=ctx.user_id, reason=body.reason.strip(),
            except_id=ctx.session.id if (ctx.session and user_id == ctx.user_id) else None,
        )
        return CommandResult(data={"revoked": n}, after={"revoked": n})

    return run_command(
        db, ctx, action="staff.sessions_revoke", permission=PERM, entity_type="user", entity_id=user_id,
        key=key, fn=do, reason=body.reason, reason_required=True,
    )


# ── Maker-checker ─────────────────────────────────────────────────────────────


def _visible_requests(db: Session, ctx: AdminContext):
    """Yêu cầu thuộc mảng mình có quyền duyệt + yêu cầu do chính mình lập.
    Bản nháp chỉ người lập thấy. Lọc ở SQL để phân trang/đếm đúng."""
    from sqlalchemy import and_

    CR = models.AdminChangeRequest
    allowed = [code for code, k in change_requests.kinds().items() if ctx.has(k.permission)]
    return db.query(CR).filter(or_(
        CR.requested_by == ctx.user_id,
        and_(CR.kind.in_(allowed or ["__none__"]), CR.status != "DRAFT"),
    ))


def _with_flags(d: dict, r: models.AdminChangeRequest, ctx: AdminContext) -> dict:
    perm = d.get("required_permission")
    mine = r.requested_by == ctx.user_id
    d["is_mine"] = mine
    d["can_decide"] = bool(perm and ctx.has(perm) and not mine and r.status == "PENDING"
                           and (r.payload or {}).get("user_id") != ctx.user_id)
    d["can_withdraw"] = mine and r.status in ("DRAFT", "PENDING")
    d["can_edit"] = mine and r.status == "DRAFT"
    return d


@router.get("/change-requests")
def list_change_requests(
    status: str = Query("PENDING", max_length=20),
    kind: str = Query("", max_length=40),
    mine: bool = False,
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(admin_context),
    db: Session = Depends(get_db),
):
    CR = models.AdminChangeRequest
    query = _visible_requests(db, ctx)
    if status and status != "all":
        query = query.filter(CR.status == status)
    if kind:
        query = query.filter(CR.kind == kind)
    if mine:
        query = query.filter(CR.requested_by == ctx.user_id)
    rows, total = paginate(query.order_by(CR.requested_at.desc()), page)
    cache: dict = {}
    counts = {s: _visible_requests(db, ctx).filter(CR.status == s).count() for s in ("DRAFT", "PENDING")}
    return paged([_with_flags(change_requests.to_dict(db, r, cache), r, ctx) for r in rows],
                 total=total, page=page, counts=counts)


def _load_visible(db: Session, ctx: AdminContext, req_id: int) -> models.AdminChangeRequest:
    r = _visible_requests(db, ctx).filter(models.AdminChangeRequest.id == req_id).first()
    if r is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy yêu cầu")
    return r


@router.get("/change-requests/{req_id}")
def get_change_request(req_id: int, ctx: AdminContext = Depends(admin_context), db: Session = Depends(get_db)):
    r = _load_visible(db, ctx, req_id)
    cache: dict = {}
    d = _with_flags(change_requests.to_dict(db, r, cache, detail=True), r, ctx)
    L = models.AdminActionLog
    d["history"] = [
        {"id": x.id, "action": x.action, "actor": user_brief(db, x.actor_user_id, cache), "reason": x.reason,
         "result": x.result, "created_at": iso(x.created_at)}
        for x in db.query(L).filter(L.entity_type == "change_request", L.entity_id == str(r.id))
        .order_by(L.id.asc()).limit(50).all()
    ]
    return one(d)


class DraftBody(BaseModel):
    payload: dict
    reason: str = Field("", max_length=1000)


@router.post("/change-requests/{req_id}/draft")
def update_draft(
    req_id: int,
    body: DraftBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(admin_context),
    db: Session = Depends(get_db),
):
    r = _load_visible(db, ctx, req_id)
    if r.requested_by != ctx.user_id:
        raise fail(403, "ADMIN_PERMISSION_DENIED", "Chỉ người lập được sửa bản nháp")
    kind = change_requests.kind_of(r.kind)

    def do() -> CommandResult:
        if r.status != "DRAFT":
            raise fail(409, "ADMIN_CONFLICT", "Chỉ sửa được bản nháp")
        before = {"payload": r.payload, "reason": r.reason}
        payload = kind.validate(db, body.payload) if kind.validate else body.payload
        # Không cho đổi "đối tượng" của yêu cầu qua đường sửa nháp.
        for k_ in ("user_id", "payment_id", "delegation_id"):
            if k_ in (r.payload or {}) and payload.get(k_) != r.payload.get(k_):
                raise fail(422, "ADMIN_VALIDATION", "Không đổi được đối tượng của yêu cầu")
        r.payload = payload
        r.reason = body.reason.strip() or r.reason
        return CommandResult(data=_with_flags(change_requests.to_dict(db, r, detail=True), r, ctx),
                             before=before, after={"payload": r.payload, "reason": r.reason})

    return run_command(
        db, ctx, action=f"change_request.draft.{r.kind}", permission=kind.permission,
        entity_type="change_request", entity_id=req_id, key=key, fn=do,
        expected_version=expected, current_version=lambda: change_requests.version_of(r),
    )


@router.post("/change-requests/{req_id}/submit")
def submit_draft(
    req_id: int,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(admin_context),
    db: Session = Depends(get_db),
):
    r = _load_visible(db, ctx, req_id)
    if r.requested_by != ctx.user_id:
        raise fail(403, "ADMIN_PERMISSION_DENIED", "Chỉ người lập được gửi yêu cầu")
    kind = change_requests.kind_of(r.kind)

    def do() -> CommandResult:
        if r.status != "DRAFT":
            raise fail(409, "ADMIN_CONFLICT", "Yêu cầu đã được gửi")
        if not (r.reason or "").strip() or len(r.reason.strip()) < 5:
            raise fail(422, "ADMIN_REASON_REQUIRED", "Bản nháp cần lý do (ít nhất 5 ký tự) trước khi gửi")
        if kind.validate:
            r.payload = kind.validate(db, r.payload or {})
        r.status = "PENDING"
        r.requested_at = utcnow()
        return CommandResult(data=_with_flags(change_requests.to_dict(db, r, detail=True), r, ctx),
                             after={"status": "PENDING"}, event_status="PENDING")

    return run_command(
        db, ctx, action=f"change_request.submit.{r.kind}", permission=kind.permission,
        entity_type="change_request", entity_id=req_id, key=key, fn=do, reauth=True,
        expected_version=expected, current_version=lambda: change_requests.version_of(r),
        event_type="admin.work_item.created",
    )


def _load_pending(db: Session, req_id: int) -> models.AdminChangeRequest:
    r = db.get(models.AdminChangeRequest, req_id)
    if r is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy yêu cầu")
    if r.status != "PENDING":
        raise fail(409, "ADMIN_CONFLICT", "Yêu cầu đã được xử lý")
    return r


@router.post("/change-requests/{req_id}/approve")
def approve_change_request(
    req_id: int,
    body: DecisionBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(admin_context),
    db: Session = Depends(get_db),
):
    r = db.get(models.AdminChangeRequest, req_id)
    if r is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy yêu cầu")
    kind = change_requests.kind_of(r.kind)
    if not ctx.has(kind.permission):
        raise fail(403, "ADMIN_PERMISSION_DENIED", "Bạn không có quyền duyệt yêu cầu này", {"permission": kind.permission})
    if r.requested_by == ctx.user_id:
        raise fail(403, "ADMIN_MAKER_CHECKER", "Người tạo yêu cầu không được tự duyệt")
    if (r.payload or {}).get("user_id") == ctx.user_id:
        raise fail(403, "ADMIN_SELF_ROLE_CHANGE", "Không thể duyệt yêu cầu cấp quyền cho chính mình")

    def do() -> CommandResult:
        req = _load_pending(db, req_id)
        # Executor nhận kèm bối cảnh yêu cầu gốc (người lập, lý do) dưới khoá `_…`.
        result = kind.executor(db, ctx, {**(req.payload or {}), "_request_id": req.id,
                                         "_requested_by": req.requested_by, "_reason": req.reason})
        req.status = "APPROVED"
        req.decided_by = ctx.user_id
        req.decided_at = utcnow()
        req.decision_note = body.note.strip() or None
        req.result_json = result
        return CommandResult(data=_with_flags(change_requests.to_dict(db, req, detail=True), req, ctx),
                             after={"status": "APPROVED", "result": result}, event_status="APPROVED")

    return run_command(
        db, ctx, action=f"change_request.approve.{r.kind}", permission=kind.permission,
        entity_type="change_request", entity_id=req_id, key=key, fn=do, reauth=True,
        event_type="admin.work_item.updated",
    )


@router.post("/change-requests/{req_id}/reject")
def reject_change_request(
    req_id: int,
    body: DecisionBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(admin_context),
    db: Session = Depends(get_db),
):
    """Người duyệt TỪ CHỐI, hoặc người lập THU HỒI (cả bản nháp lẫn đang chờ)."""
    r = db.get(models.AdminChangeRequest, req_id)
    if r is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy yêu cầu")
    kind = change_requests.kind_of(r.kind)
    is_owner = r.requested_by == ctx.user_id
    if not (ctx.has(kind.permission) or is_owner):
        raise fail(403, "ADMIN_PERMISSION_DENIED", "Bạn không có quyền với yêu cầu này")

    def do() -> CommandResult:
        req = db.get(models.AdminChangeRequest, req_id)
        if req.status not in (("DRAFT", "PENDING") if is_owner else ("PENDING",)):
            raise fail(409, "ADMIN_CONFLICT", "Yêu cầu đã được xử lý")
        req.status = "CANCELLED" if is_owner else "REJECTED"
        req.decided_by = ctx.user_id
        req.decided_at = utcnow()
        req.decision_note = body.note.strip() or None
        return CommandResult(data=_with_flags(change_requests.to_dict(db, req, detail=True), req, ctx),
                             after={"status": req.status}, event_status=req.status)

    return run_command(
        db, ctx, action=f"change_request.reject.{r.kind}", permission=kind.permission,
        entity_type="change_request", entity_id=req_id, key=key, fn=do,
        reason=body.note, reason_required=not is_owner, event_type="admin.work_item.updated",
    )


# ── Executor: cấp vai qua maker-checker ───────────────────────────────────────


def _exec_grant(db: Session, approver: AdminContext, payload: dict) -> dict:
    user_id = int(payload["user_id"])
    role_code = str(payload["role_code"])
    target = db.get(models.User, user_id)
    if target is None or not target.is_active:
        raise fail(409, "ADMIN_TARGET_LOCKED", "Tài khoản đích không còn hoạt động")
    rbac.grant_role(db, user_id=user_id, role_code=role_code, granted_by=approver.user_id, reason="maker-checker")
    replace = payload.get("replace_role")
    if replace and replace != role_code:
        rbac.revoke_role(db, user_id=user_id, role_code=str(replace), revoked_by=approver.user_id,
                         reason=f"maker-checker: đổi sang {role_code}")
    return {"user_id": user_id, "roles": rbac.active_roles(db, user_id)}


def _describe_grant(db: Session, payload: dict) -> str:
    u = db.get(models.User, int(payload.get("user_id") or 0))
    name = u.name if u else f"#{payload.get('user_id')}"
    new = ROLES.get(str(payload.get("role_code")), (payload.get("role_code"),))[0]
    if payload.get("replace_role"):
        old_ = ROLES.get(str(payload["replace_role"]), (payload["replace_role"],))[0]
        return f"Đổi vai của {name}: {old_} → {new}"
    return f"Cấp vai {new} cho {name}"


def _preview_grant(db: Session, payload: dict) -> list:
    from app.services.admin_v2.permissions import permissions_for_roles

    uid = int(payload.get("user_id") or 0)
    before = rbac.active_roles(db, uid)
    after = sorted((set(before) | {str(payload.get("role_code"))}) - {payload.get("replace_role")})
    pb, pa = permissions_for_roles(before), permissions_for_roles(after)
    name = lambda codes: ", ".join(ROLES.get(c, (c,))[0] for c in codes) or "Không có"  # noqa: E731
    return [
        {"label": "Vai quản trị", "before": name(before), "after": name(after)},
        {"label": "Số quyền", "before": len(pb), "after": len(pa), "delta": len(pa) - len(pb)},
        {"label": "Quyền thêm mới", "before": "—", "after": ", ".join(sorted(pa - pb)) or "—"},
        {"label": "Quyền bị bỏ", "before": "—", "after": ", ".join(sorted(pb - pa)) or "—"},
    ]


def _links_grant(db: Session, payload: dict) -> list:
    uid = int(payload.get("user_id") or 0)
    u = db.get(models.User, uid)
    return [{"label": "Nhân viên", "ref": f"US-{uid:05d}", "href": f"/admin/users/{uid}",
             "detail": u.name if u else ""}]


change_requests.register(
    "grant_admin_role", permission=PERM, label="Cấp vai quản trị cấp cao",
    executor=_exec_grant, describe=_describe_grant, preview=_preview_grant, links=_links_grant,
)


def staff_ids(db: Session) -> Optional[list[int]]:
    return [r[0] for r in db.query(models.AdminUserRole.user_id).filter(models.AdminUserRole.revoked_at.is_(None)).distinct()]
