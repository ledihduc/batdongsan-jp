"""Chứng từ riêng tư — ký URL xem ngắn hạn + tải về có nhật ký.

- `POST /api/v2/admin/documents/sign`     nhân viên (quyền tuỳ nguồn)
- `GET  /api/v2/admin/documents/download/{token}`
- `POST /api/v2/documents/sign`           người trong cuộc (JWT app) — `public_router`
- `GET  /api/v2/documents/download/{token}`

Client CHỈ gửi tham chiếu (nguồn, id, trường, vị trí); tệp được tìm từ hàng DB.
Logic ở `app/services/admin_v2/documents.py`.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app import auth, models
from app.database import get_db
from app.observability.context import request_id_var
from app.services.admin_v2 import documents as docs
from app.services.admin_v2 import rbac
from app.services.admin_v2.core import (
    AdminContext, _log_denied, admin_context, client_ip, fail, hash_ip, iso, one, record_read,
)

router = APIRouter(prefix="/api/v2/admin/documents", tags=["admin-v2-documents"])
public_router = APIRouter(prefix="/api/v2/documents", tags=["documents"])


class SignBody(BaseModel):
    source_type: str = Field(..., max_length=40)
    source_id: str = Field(..., min_length=1, max_length=64)
    field: str = Field(..., max_length=60)
    index: int = Field(0, ge=0, le=200)
    reason: str = Field("", max_length=500)


def _err(e: docs.DocumentError):
    return fail(e.status, e.code, e.message)


def _doc_dict(d: docs.ResolvedDoc) -> dict:
    ct, inline = docs.safe_content_type(d)
    return {
        "source_type": d.source_type, "source_id": d.source_id, "field": d.field, "index": d.index,
        "label": d.spec.label, "category": d.spec.category, "content_type": ct, "inline": inline,
    }


def _resolve_existing(db: Session, body: SignBody) -> docs.ResolvedDoc:
    try:
        d = docs.resolve(db, body.source_type, body.source_id, body.field, body.index)
    except docs.DocumentError as e:
        raise _err(e)
    if not docs.exists(d):
        raise fail(404, "ADMIN_DOC_FILE_MISSING", "Tệp chứng từ không còn trên máy chủ")
    return d


def _sign_response(d: docs.ResolvedDoc, token: str, exp, path_prefix: str) -> dict:
    return one({
        "url": f"{path_prefix}/download/{token}",
        "expires_at": iso(exp),
        "expires_in": docs.TOKEN_TTL_SECONDS,
        "document": _doc_dict(d),
    })


@router.post("/sign")
def sign_document(
    body: SignBody,
    request: Request,
    ctx: AdminContext = Depends(admin_context),
    db: Session = Depends(get_db),
):
    try:
        spec = docs.source_spec(body.source_type)
    except docs.DocumentError as e:
        raise _err(e)
    perm = next((p for p in spec.permissions if ctx.has(p)), None)
    if perm is None:
        _log_denied(db, ctx, "|".join(spec.permissions), request)
        raise fail(403, "ADMIN_PERMISSION_DENIED", "Bạn không có quyền mở chứng từ này",
                   {"permission": list(spec.permissions)})
    d = _resolve_existing(db, body)
    reason = body.reason.strip()
    if d.spec.reason_required and len(reason) < 5:
        raise fail(422, "ADMIN_REASON_REQUIRED", "Chứng từ nhạy cảm: cần nhập lý do (ít nhất 5 ký tự)")
    log = record_read(db, ctx, action="document.sign", permission=perm, entity_type=d.source_type,
                      entity_id=d.source_id, reason=reason or None, commit=False)
    log.after_json = {"field": d.field, "index": d.index, "category": d.spec.category}
    db.flush()
    token, exp = docs.sign_token(actor_id=ctx.user_id, audience="admin", doc=d, sign_log_id=log.id, permission=perm)
    db.commit()
    return _sign_response(d, token, exp, "/api/v2/admin/documents")


def _download(token: str, request: Request, db: Session):
    try:
        claims = docs.verify_doc_token(token)
        d = docs.resolve(db, str(claims.get("src")), str(claims.get("sid")), str(claims.get("fld")),
                         int(claims.get("idx") or 0))
    except docs.DocumentError as e:
        raise _err(e)
    try:
        actor_id = int(claims.get("sub"))
    except (TypeError, ValueError):
        raise fail(401, "ADMIN_DOC_TOKEN_INVALID", "Liên kết xem chứng từ không hợp lệ")
    actor = db.get(models.User, actor_id)
    if actor is None or not actor.is_active:
        raise fail(401, "ADMIN_DOC_TOKEN_INVALID", "Tài khoản đã bị khoá")
    # Quyền kiểm LẠI lúc mở: bị thu quyền trong 5 phút đó thì link chết ngay.
    aud = claims.get("aud")
    spec = docs.SOURCES[d.source_type]
    if aud == "admin":
        perms = rbac.permissions_of(db, actor_id)
        if not any(p in perms for p in spec.permissions):
            raise fail(403, "ADMIN_PERMISSION_DENIED", "Bạn không còn quyền mở chứng từ này")
    elif not docs.is_participant(db, d.source_type, d.row, actor_id):
        raise fail(403, "DOCUMENT_FORBIDDEN", "Bạn không còn quyền mở chứng từ này")

    sign_log = db.get(models.AdminActionLog, claims.get("lid")) if claims.get("lid") else None
    reason = sign_log.reason if sign_log is not None else None
    ip = client_ip(request)
    try:
        path, data = docs.read_bytes_or_path(db, d, actor_id=actor_id, reason=reason or "", ip=ip)
    except docs.DocumentError as e:
        db.rollback()
        raise _err(e)
    db.add(models.AdminActionLog(
        request_id=request_id_var.get(),
        actor_user_id=actor_id,
        action="document.open",
        permission=claims.get("prm") if aud == "admin" else "participant",
        entity_type=d.source_type,
        entity_id=d.source_id,
        reason=reason,
        after_json={"field": d.field, "index": d.index, "category": d.spec.category,
                    "sign_log_id": claims.get("lid"), "via": aud},
        result="success",
        ip_hash=hash_ip(ip),
        user_agent=(request.headers.get("user-agent") or "")[:300] or None,
    ))
    db.commit()

    ct, inline = docs.safe_content_type(d)
    disp = "inline" if inline else "attachment"
    headers = {
        "Cache-Control": "no-store, private",
        "Pragma": "no-cache",
        "X-Content-Type-Options": "nosniff",
        "Content-Disposition": f'{disp}; filename="{d.filename}"',
        "Referrer-Policy": "no-referrer",
    }
    if path is not None:
        return FileResponse(path, media_type=ct, headers=headers)
    return Response(content=data or b"", media_type=ct, headers=headers)


@router.get("/download/{token}")
def download_document(token: str, request: Request, db: Session = Depends(get_db)):
    """Không cần header Authorization: token ký chính là quyền (sống 300s)."""
    return _download(token, request, db)


# ── Người trong cuộc (app) ────────────────────────────────────────────────────


@public_router.post("/sign")
def sign_own_document(
    body: SignBody,
    request: Request,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
):
    """Chỉ người trong cuộc của hàng nguồn (khách/sale/chủ của hành trình, người
    nộp chứng từ, chủ hồ sơ) mới ký được chứng từ của CHÍNH hồ sơ đó."""
    uid = int(claims["sub"])
    try:
        spec, row = docs.load_source(db, body.source_type, body.source_id)
    except docs.DocumentError as e:
        if e.status == 404:
            raise fail(404, "DOCUMENT_NOT_FOUND", "Không tìm thấy chứng từ")
        raise _err(e)
    if not docs.is_participant(db, body.source_type, row, uid):
        # 404 thay vì 403: không xác nhận hồ sơ của người khác có tồn tại.
        raise fail(404, "DOCUMENT_NOT_FOUND", "Không tìm thấy chứng từ")
    d = _resolve_existing(db, body)
    ip = client_ip(request)
    log = models.AdminActionLog(
        request_id=request_id_var.get(), actor_user_id=uid, action="document.sign",
        permission="participant", entity_type=d.source_type, entity_id=d.source_id,
        reason=body.reason.strip() or None,
        after_json={"field": d.field, "index": d.index, "category": d.spec.category, "via": "app"},
        result="success", ip_hash=hash_ip(ip),
        user_agent=(request.headers.get("user-agent") or "")[:300] or None,
    )
    db.add(log)
    db.flush()
    token, exp = docs.sign_token(actor_id=uid, audience="app", doc=d, sign_log_id=log.id, permission=None)
    db.commit()
    return _sign_response(d, token, exp, "/api/v2/documents")


@public_router.get("/download/{token}")
def download_own_document(token: str, request: Request, db: Session = Depends(get_db)):
    return _download(token, request, db)
