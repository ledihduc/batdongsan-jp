"""`/api/ai/actions/{token}` — xem trước + xác nhận action ghi AI (plan 20261027-1102 Phase 09).

GET xem trước không ghi gì. POST xác nhận bắt buộc JWT (`require_user`: kiểm khoá tài khoản +
đổi mật khẩu); thực thi dưới danh tính người bấm. CSRF không áp dụng: Bearer, không cookie.
Không `require_region`: chỉ include trong khối `if ai_enabled_for_region(...)` (T8, D19).
Cả 2 route là `def` đồng bộ ⇒ FastAPI chạy trong threadpool; KHÔNG đổi sang `async def`:
claim giữ row lock, request trùng token chờ lock sẽ chặn event loop (QA C1).
"""

# Không dùng `from __future__ import annotations`: slowapi bọc hàm ⇒ annotation chuỗi không resolve (P08).
import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.ai_capabilities.loader import Registry, get_registry
from app.auth import require_user
from app.config import settings
from app.database import get_db
from app.middleware.rate_limit import limiter
from app.schemas.ai_actions import AiConfirmResult, AiPendingPreview
from app.services.ai_actions.confirm_service import confirm_pending, preview_pending
from app.services.ai_actions.pending_store import PendingError

router = APIRouter(prefix="/api/ai/actions", tags=["ai-actions"])

_TOKEN_RE = re.compile(r"^[A-Za-z0-9_-]{43}$")
_MESSAGES = {
    "not_found": "confirmation link not found",
    "forbidden": "this confirmation belongs to another user",
    "used": "this confirmation was already used",
    "expired": "this confirmation has expired",
    "action_unavailable": "this action is no longer available",
}


def _error(exc: PendingError) -> HTTPException:
    return HTTPException(status_code=exc.http_status,
                         detail={"code": exc.code, "message": _MESSAGES.get(exc.code, "action was rejected")})


def _check_token(token: str) -> None:
    if not _TOKEN_RE.match(token):
        raise _error(PendingError("not_found", 404))


@router.get("/{token}", response_model=AiPendingPreview)
@limiter.limit(lambda: settings.ai_confirm_rate_limit)
def preview_ai_action(
    request: Request,
    token: str,
    lang: Optional[str] = Query(None, max_length=35),  # `ja-JP` hợp lệ, normalize ở service (QA L6)
    db: Session = Depends(get_db),
    registry: Registry = Depends(get_registry),
) -> AiPendingPreview:
    _check_token(token)
    try:
        return AiPendingPreview(**preview_pending(db, registry, token, lang=lang))
    except PendingError as exc:
        raise _error(exc) from None


@router.post("/{token}/confirm", response_model=AiConfirmResult)
@limiter.limit(lambda: settings.ai_confirm_rate_limit)
def confirm_ai_action(
    request: Request,
    token: str,
    claims: dict = Depends(require_user),
    db: Session = Depends(get_db),
    registry: Registry = Depends(get_registry),
) -> AiConfirmResult:
    _check_token(token)
    try:
        out = confirm_pending(db, registry, token, claims, authorization=request.headers.get("authorization"))
    except PendingError as exc:
        raise _error(exc) from None
    return AiConfirmResult(**out)
