"""Đăng nhập backoffice — phiên riêng, thu hồi được, có xác thực lại."""


from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app import auth, models
from app.database import get_db
from app.middleware.rate_limit import limiter
from app.services import dinh_danh
from app.services.admin_v2 import rbac, sessions
from app.services.admin_v2.core import (
    AdminContext, admin_context, client_ip, fail, hash_ip, iso, mask_email, one, utcnow,
)
from app.services.admin_v2.permissions import REAUTH_WINDOW_SECONDS, ROLES
from app.observability.context import request_id_var

router = APIRouter(prefix="/api/v2/admin/auth", tags=["admin-v2-auth"])


class LoginBody(BaseModel):
    identifier: str = Field(..., max_length=200)
    password: str = Field(..., max_length=200)


class PasswordBody(BaseModel):
    password: str = Field(..., max_length=200)


def me_payload(ctx: AdminContext) -> dict:
    s = ctx.session
    reauth_valid_until = None
    if s is not None and s.reauth_at is not None:
        from datetime import timedelta

        reauth_valid_until = iso(s.reauth_at + timedelta(seconds=REAUTH_WINDOW_SECONDS))
    return {
        "user": {
            "id": ctx.user.id,
            "name": ctx.user.name,
            "email_masked": mask_email(ctx.user.email),
        },
        "roles": [{"code": r, "name": ROLES[r][0]} for r in ctx.roles if r in ROLES],
        "permissions": sorted(ctx.permissions),
        "session": {
            "id": s.id if s else None,
            "kind": ctx.token_kind,
            "expires_at": iso(s.expires_at) if s else None,
            "reauth_valid_until": reauth_valid_until,
        },
    }


def _log(db: Session, *, user_id: int, action: str, session_id: str | None, ip_hash, ua, result="success") -> None:
    db.add(models.AdminActionLog(
        request_id=request_id_var.get(), actor_user_id=user_id, admin_session_id=session_id,
        action=action, entity_type="admin_session", entity_id=session_id,
        result=result, ip_hash=ip_hash, user_agent=ua,
    ))


@router.post("/login")
@limiter.limit("10/minute")
def login(request: Request, body: LoginBody, db: Session = Depends(get_db)):
    email, sdt = dinh_danh.tach(body.identifier.strip())
    user = None
    if email or sdt:
        user = (
            db.query(models.User)
            .filter(
                models.User.is_active == True,  # noqa: E712
                or_(
                    and_(models.User.email == email, models.User.email != ""),
                    and_(models.User.phone == sdt, models.User.phone != ""),
                ),
            )
            .first()
        )
    if user is None or not auth.verify_password(body.password, user.password_hash):
        raise fail(401, "ADMIN_BAD_CREDENTIALS", "Email/SĐT hoặc mật khẩu không đúng")
    ip_h = hash_ip(client_ip(request))
    ua = (request.headers.get("user-agent") or "")[:300] or None
    if not rbac.permissions_of(db, user.id):
        # Mật khẩu đúng nhưng không phải nhân viên: ghi lại (dấu hiệu dò quyền).
        _log(db, user_id=user.id, action="admin.login_denied", session_id=None, ip_hash=ip_h, ua=ua, result="denied")
        db.commit()
        raise fail(403, "ADMIN_NOT_STAFF", "Tài khoản không có quyền quản trị")
    s = sessions.open_session(db, user_id=user.id, ip_hash=ip_h, user_agent=ua)
    _log(db, user_id=user.id, action="admin.login", session_id=s.id, ip_hash=ip_h, ua=ua)
    db.commit()
    token = sessions.sign_admin_token(user.id, s.id, s.expires_at)
    ctx = AdminContext(
        user=user, roles=rbac.active_roles(db, user.id), permissions=rbac.permissions_of(db, user.id),
        session=s, ip_hash=ip_h, user_agent=ua,
    )
    return one({"token": token, **me_payload(ctx)})


@router.get("/me")
def me(ctx: AdminContext = Depends(admin_context)):
    return one(me_payload(ctx))


@router.post("/logout")
def logout(ctx: AdminContext = Depends(admin_context), db: Session = Depends(get_db)):
    if ctx.session is not None and ctx.session.revoked_at is None:
        ctx.session.revoked_at = utcnow()
        ctx.session.revoked_by = ctx.user_id
        ctx.session.revoke_reason = "logout"
        _log(db, user_id=ctx.user_id, action="admin.logout", session_id=ctx.session.id, ip_hash=ctx.ip_hash, ua=ctx.user_agent)
        db.commit()
    return one({"ok": True})


@router.post("/reauth")
@limiter.limit("10/minute")
def reauth(request: Request, body: PasswordBody, ctx: AdminContext = Depends(admin_context), db: Session = Depends(get_db)):
    if ctx.session is None:
        raise fail(403, "ADMIN_SESSION_REQUIRED", "Cần đăng nhập bằng phiên quản trị")
    if not auth.verify_password(body.password, ctx.user.password_hash):
        _log(db, user_id=ctx.user_id, action="admin.reauth_failed", session_id=ctx.session.id, ip_hash=ctx.ip_hash, ua=ctx.user_agent, result="denied")
        db.commit()
        raise fail(401, "ADMIN_BAD_CREDENTIALS", "Mật khẩu không đúng")
    ctx.session.reauth_at = utcnow()
    _log(db, user_id=ctx.user_id, action="admin.reauth", session_id=ctx.session.id, ip_hash=ctx.ip_hash, ua=ctx.user_agent)
    db.commit()
    return one(me_payload(ctx))


@router.get("/sessions")
def my_sessions(ctx: AdminContext = Depends(admin_context), db: Session = Depends(get_db)):
    rows = (
        db.query(models.AdminSession)
        .filter(models.AdminSession.user_id == ctx.user_id)
        .order_by(models.AdminSession.created_at.desc())
        .limit(20)
        .all()
    )
    cur = ctx.session.id if ctx.session else None
    return one([sessions.session_dict(s, cur) for s in rows])
