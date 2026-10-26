"""Hạ tầng dùng chung cho mọi endpoint `/api/v2/admin/*`.

- `admin_context` / `require_permission(...)`: xác thực + đọc quyền TỪ DB mỗi
  request (không tin claim), kiểm tài khoản còn hoạt động, phiên admin chưa bị
  thu hồi. Bị từ chối cũng ghi nhật ký (moderator thử URL tài chính là tín hiệu).
- `run_command(...)`: khuôn cho MỌI lệnh ghi — Idempotency-Key, lý do bắt buộc,
  kiểm phiên bản (If-Match), xác thực lại, ghi nhật ký + sự kiện trong CÙNG
  transaction, trả trạng thái sau thao tác.
- Envelope `{data, meta}` và lỗi `{error:{code,message,request_id}}`.
"""

from __future__ import annotations

import hashlib
import json
import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any, Callable, Optional

from fastapi import Depends, Header, HTTPException, Query, Request
from fastapi.encoders import jsonable_encoder
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import auth, models
from app.config import settings
from app.database import get_db
from app.observability.context import request_id_var
from app.services.admin_v2 import rbac
from app.services.admin_v2.permissions import REAUTH_WINDOW_SECONDS

logger = logging.getLogger(__name__)


# ── Thời gian / lỗi / envelope ────────────────────────────────────────────────


def utcnow() -> datetime:
    return datetime.utcnow()


def iso(value: Optional[datetime]) -> Optional[str]:
    """Giờ lưu trong DB là UTC không múi; gắn 'Z' để FE đổi đúng sang giờ VN."""
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if value.tzinfo is not None:
        return value.isoformat()
    return value.isoformat(timespec="seconds") + "Z"


def fail(status: int, code: str, message: str, details: Any = None) -> HTTPException:
    detail: dict = {"code": code, "message": message}
    if details is not None:
        detail["details"] = details
    return HTTPException(status_code=status, detail=detail)


def meta(**extra) -> dict:
    out = {"generated_at": iso(utcnow()), "request_id": request_id_var.get()}
    out.update(extra)
    return out


def one(data: Any, **extra) -> dict:
    return {"data": jsonable_encoder(data), "meta": meta(**extra)}


@dataclass
class PageParams:
    limit: int
    offset: int


def page_params(
    limit: int = Query(25, ge=1, le=100),
    cursor: Optional[str] = Query(None, max_length=20),
) -> PageParams:
    offset = 0
    if cursor:
        try:
            offset = max(0, int(cursor))
        except ValueError:
            raise fail(422, "ADMIN_BAD_CURSOR", "Cursor không hợp lệ")
    return PageParams(limit=limit, offset=offset)


def paged(data: list, *, total: int, page: PageParams, **extra) -> dict:
    nxt = page.offset + page.limit
    return {
        "data": jsonable_encoder(data),
        "meta": meta(
            total=total,
            limit=page.limit,
            cursor=str(page.offset) if page.offset else None,
            next_cursor=str(nxt) if nxt < total else None,
            **extra,
        ),
    }


def paginate(query, page: PageParams):
    """Đếm + cắt trang ở SERVER. Không có đường nào tải cả bảng."""
    total = query.order_by(None).count()
    rows = query.offset(page.offset).limit(page.limit).all()
    return rows, total


# ── Che PII ───────────────────────────────────────────────────────────────────


def mask_email(value: Optional[str]) -> Optional[str]:
    if not value:
        return value or None
    if "@" not in value:
        return value[:1] + "***"
    local, domain = value.split("@", 1)
    keep = local[:2] if len(local) > 2 else local[:1]
    return f"{keep}***@{domain}"


def mask_phone(value: Optional[str]) -> Optional[str]:
    if not value:
        return value or None
    digits = value.strip()
    if len(digits) <= 4:
        return "*" * len(digits)
    return digits[:3] + "*" * (len(digits) - 6) + digits[-3:]


def mask_id_number(value: Optional[str]) -> Optional[str]:
    if not value:
        return value or None
    v = value.strip()
    return "*" * max(0, len(v) - 3) + v[-3:]


def hash_ip(ip: Optional[str]) -> Optional[str]:
    if not ip:
        return None
    return hashlib.sha256(f"{settings.log_hash_salt}:{ip}".encode()).hexdigest()[:24]


def client_ip(request: Request) -> Optional[str]:
    fwd = request.headers.get("x-forwarded-for") or ""
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else None


def etag(*parts: Any) -> str:
    """Phiên bản lạc quan cho bản ghi KHÔNG có cột version: băm các trường
    quyết định trạng thái. Đổi bất kỳ trường nào → etag đổi → lệnh cũ bị 409."""
    raw = json.dumps(jsonable_encoder(parts), sort_keys=True, ensure_ascii=False)
    return hashlib.sha1(raw.encode()).hexdigest()[:16]


# ── Ngữ cảnh + phân quyền ─────────────────────────────────────────────────────


@dataclass
class AdminContext:
    user: models.User
    roles: list[str]
    permissions: set[str]
    session: Optional[models.AdminSession]
    ip_hash: Optional[str]
    user_agent: Optional[str]
    token_kind: str = "admin"  # admin | app (JWT app của SUPER_ADMIN cũ)
    extras: dict = field(default_factory=dict)

    @property
    def user_id(self) -> int:
        return int(self.user.id)

    def has(self, perm: str) -> bool:
        return perm in self.permissions

    def legacy_claims(self) -> dict:
        """Claims giả lập để gọi lại service/route CŨ (vốn nhận dict claims).
        Chỉ dùng SAU khi đã kiểm quyền mới ở tầng V2."""
        return {"sub": self.user_id, "role": "admin"}


def _bearer(request: Request) -> Optional[str]:
    raw = request.headers.get("authorization", "")
    if raw.lower().startswith("bearer "):
        return raw.split(" ", 1)[1].strip()
    return None


def admin_context(request: Request, db: Session = Depends(get_db)) -> AdminContext:
    token = _bearer(request)
    if not token:
        raise fail(401, "ADMIN_UNAUTHENTICATED", "Chưa đăng nhập quản trị")

    session = None
    kind = "admin"
    claims = auth.verify_token(token, purpose="admin")
    if claims:
        session = db.get(models.AdminSession, str(claims.get("sid") or ""))
        now = utcnow()
        if (
            session is None
            or session.revoked_at is not None
            or session.expires_at <= now
            or int(session.user_id) != int(claims.get("sub") or 0)
        ):
            raise fail(401, "ADMIN_SESSION_ENDED", "Phiên quản trị đã kết thúc. Vui lòng đăng nhập lại.")
        if session.last_seen_at is None or now - session.last_seen_at > timedelta(seconds=60):
            session.last_seen_at = now
            db.commit()
    else:
        # JWT app thường: chỉ để lối tắt Flutter của SUPER_ADMIN cũ dùng tiếp
        # các endpoint V2 đã thay chỗ endpoint cũ. Quyền vẫn đọc từ DB.
        claims = auth.verify_token(token)
        if not claims or auth._token_da_bi_vo_hieu(db, claims):
            raise fail(401, "ADMIN_UNAUTHENTICATED", "Token không hợp lệ hoặc đã hết hạn")
        kind = "app"

    user = db.get(models.User, int(claims.get("sub") or 0))
    if user is None or not user.is_active:
        raise fail(401, "ADMIN_ACCOUNT_DISABLED", "Tài khoản đã bị khoá hoặc không tồn tại")
    perms = rbac.permissions_of(db, user.id)
    if not perms:
        raise fail(403, "ADMIN_NOT_STAFF", "Tài khoản không phải nhân viên quản trị")
    return AdminContext(
        user=user,
        roles=rbac.active_roles(db, user.id),
        permissions=perms,
        session=session,
        ip_hash=hash_ip(client_ip(request)),
        user_agent=(request.headers.get("user-agent") or "")[:300] or None,
        token_kind=kind,
    )


def _log_denied(db: Session, ctx: AdminContext, perm: str, request: Request) -> None:
    try:
        db.add(models.AdminActionLog(
            request_id=request_id_var.get(),
            actor_user_id=ctx.user_id,
            admin_session_id=ctx.session.id if ctx.session else None,
            action="permission.denied",
            permission=perm,
            entity_type="route",
            entity_id=f"{request.method} {request.url.path}"[:64],
            result="denied",
            ip_hash=ctx.ip_hash,
            user_agent=ctx.user_agent,
        ))
        db.commit()
    except Exception as exc:  # noqa: BLE001 — ghi nhật ký từ chối không được làm hỏng 403
        db.rollback()
        logger.warning("admin denied-log failed: %s", exc)


def require_permission(perm: str) -> Callable[..., AdminContext]:
    def dep(
        request: Request,
        ctx: AdminContext = Depends(admin_context),
        db: Session = Depends(get_db),
    ) -> AdminContext:
        if not ctx.has(perm):
            _log_denied(db, ctx, perm, request)
            raise fail(403, "ADMIN_PERMISSION_DENIED", "Bạn không có quyền thực hiện thao tác này", {"permission": perm})
        return ctx

    dep.__name__ = f"require_{perm.replace('.', '_')}"
    return dep


def require_any_permission(*perms: str) -> Callable[..., AdminContext]:
    def dep(
        request: Request,
        ctx: AdminContext = Depends(admin_context),
        db: Session = Depends(get_db),
    ) -> AdminContext:
        if not any(ctx.has(p) for p in perms):
            _log_denied(db, ctx, "|".join(perms), request)
            raise fail(403, "ADMIN_PERMISSION_DENIED", "Bạn không có quyền xem mục này", {"permission": list(perms)})
        return ctx

    return dep


def idempotency_key(value: Optional[str] = Header(None, alias="Idempotency-Key")) -> str:
    """Chỉ ĐỌC header. Kiểm hợp lệ nằm trong run_command — chạy SAU kiểm quyền,
    nên người thiếu quyền luôn nhận 403 bất kể thứ tự tham số của endpoint."""
    return (value or "").strip()


def _check_key(key: str) -> None:
    if not (8 <= len(key or "") <= 128):
        raise fail(428, "ADMIN_IDEMPOTENCY_KEY_REQUIRED", "Thiếu Idempotency-Key cho lệnh ghi")


def if_match(value: Optional[str] = Header(None, alias="If-Match")) -> Optional[str]:
    return (value or "").strip().strip('"') or None


# ── Lệnh ghi ──────────────────────────────────────────────────────────────────


@dataclass
class CommandResult:
    data: Any
    before: Optional[dict] = None
    after: Optional[dict] = None
    entity_id: Optional[str] = None
    event_status: Optional[str] = None


def emit(db: Session, event_type: str, entity_type: Optional[str], entity_id: Any, status: Optional[str] = None) -> None:
    db.add(models.AdminEvent(
        event_type=event_type[:60],
        entity_type=entity_type,
        entity_id=str(entity_id) if entity_id is not None else None,
        status=status,
    ))


def _replay(log: models.AdminActionLog) -> dict:
    body = dict(log.response_json or {"data": None})
    body["meta"] = meta(action_log_id=log.id, idempotent_replay=True)
    return body


def check_reauth(ctx: AdminContext) -> None:
    s = ctx.session
    if s is None or s.reauth_at is None or utcnow() - s.reauth_at > timedelta(seconds=REAUTH_WINDOW_SECONDS):
        raise fail(403, "ADMIN_REAUTH_REQUIRED", "Thao tác này cần nhập lại mật khẩu quản trị")


def run_command(
    db: Session,
    ctx: AdminContext,
    *,
    action: str,
    permission: str,
    entity_type: Optional[str],
    entity_id: Any,
    key: str,
    fn: Callable[[], CommandResult],
    reason: Optional[str] = None,
    reason_required: bool = False,
    expected_version: Optional[str] = None,
    current_version: Optional[Callable[[], Optional[str]]] = None,
    reauth: bool = False,
    event_type: Optional[str] = None,
) -> dict:
    """Chạy một lệnh ghi theo đúng luật backoffice. Commit Ở ĐÂY (một lần)."""
    _check_key(key)
    existing = (
        db.query(models.AdminActionLog)
        .filter_by(actor_user_id=ctx.user_id, action=action, idempotency_key=key)
        .first()
    )
    if existing is not None:
        return _replay(existing)

    reason = (reason or "").strip() or None
    if reason_required and (reason is None or len(reason) < 5):
        raise fail(422, "ADMIN_REASON_REQUIRED", "Cần nhập lý do (ít nhất 5 ký tự)")
    if reauth:
        check_reauth(ctx)
    if current_version is not None:
        if not expected_version:
            raise fail(428, "ADMIN_PRECONDITION_REQUIRED", "Thiếu phiên bản bản ghi (If-Match)")
        now_v = current_version()
        if now_v != expected_version:
            raise fail(
                409, "ADMIN_CONFLICT",
                "Bản ghi vừa được người khác thay đổi. Tải lại để xem trạng thái mới.",
                {"current_version": now_v},
            )

    result = fn()
    eid = result.entity_id if result.entity_id is not None else entity_id
    data = jsonable_encoder(result.data)
    log = models.AdminActionLog(
        request_id=request_id_var.get(),
        actor_user_id=ctx.user_id,
        admin_session_id=ctx.session.id if ctx.session else None,
        action=action,
        permission=permission,
        entity_type=entity_type,
        entity_id=str(eid) if eid is not None else None,
        reason=reason,
        before_json=jsonable_encoder(result.before) if result.before is not None else None,
        after_json=jsonable_encoder(result.after) if result.after is not None else None,
        response_json={"data": data},
        idempotency_key=key,
        result="success",
        ip_hash=ctx.ip_hash,
        user_agent=ctx.user_agent,
    )
    db.add(log)
    emit(db, event_type or action, entity_type, eid, result.event_status)
    try:
        db.commit()
    except IntegrityError:
        # Hai request cùng khoá chạy song song: bên thua trả kết quả bên thắng.
        db.rollback()
        existing = (
            db.query(models.AdminActionLog)
            .filter_by(actor_user_id=ctx.user_id, action=action, idempotency_key=key)
            .first()
        )
        if existing is not None:
            return _replay(existing)
        raise
    return {"data": data, "meta": meta(action_log_id=log.id, idempotent_replay=False)}


def record_read(
    db: Session,
    ctx: AdminContext,
    *,
    action: str,
    permission: str,
    entity_type: str,
    entity_id: Any,
    reason: Optional[str],
    commit: bool = True,
) -> models.AdminActionLog:
    """Nhật ký cho thao tác ĐỌC nhạy cảm (xem PII, mở chứng từ)."""
    log = models.AdminActionLog(
        request_id=request_id_var.get(),
        actor_user_id=ctx.user_id,
        admin_session_id=ctx.session.id if ctx.session else None,
        action=action,
        permission=permission,
        entity_type=entity_type,
        entity_id=str(entity_id),
        reason=reason,
        result="success",
        ip_hash=ctx.ip_hash,
        user_agent=ctx.user_agent,
    )
    db.add(log)
    if commit:
        db.commit()
    return log


def user_brief(db: Session, user_id: Optional[int], cache: Optional[dict] = None) -> Optional[dict]:
    """Thẻ người dùng tối thiểu (PII đã che) để gắn vào mọi DTO."""
    if not user_id:
        return None
    if cache is not None and user_id in cache:
        return cache[user_id]
    u = db.get(models.User, int(user_id))
    out = None
    if u is not None:
        out = {
            "id": u.id,
            "name": u.name or "—",
            "email_masked": mask_email(u.email),
            "phone_masked": mask_phone(u.phone),
            "is_active": bool(u.is_active),
        }
    if cache is not None:
        cache[user_id] = out
    return out
