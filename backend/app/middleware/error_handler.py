"""
Uniform error envelope: tất cả 4xx/5xx trả về {error: {code, message, details?}}.
Stack trace bị suppress khi ENVIRONMENT=production.
"""

from __future__ import annotations

import logging
import time
import traceback

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded
from starlette.exceptions import HTTPException

from app.observability.fingerprint import compute_fingerprint, top_frame_of
from app.observability.redaction import redact_text

_logger = logging.getLogger("app.error")


def _request_id() -> str | None:
    from app.observability.context import request_id_var

    return request_id_var.get()


def _make_error(code: str, message: str, details: object = None) -> dict:
    envelope: dict = {"error": {"code": code, "message": message}}
    if details is not None:
        envelope["error"]["details"] = details
    rid = _request_id()
    if rid:
        envelope["error"]["request_id"] = rid
    return envelope


def _sanitize_error(err: dict) -> dict:
    """Strip non-JSON-serializable fields (e.g. Pydantic v2 puts raw ValueError in ctx)."""
    return {k: v for k, v in err.items() if k != "ctx"}


async def validation_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Xử lý RequestValidationError (Pydantic) → 422 với envelope chuẩn."""
    return JSONResponse(
        status_code=422,
        content=_make_error(
            code="VALIDATION_ERROR",
            message="Dữ liệu đầu vào không hợp lệ",
            details=[_sanitize_error(e) for e in exc.errors()],
        ),
    )


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """
    Xử lý HTTPException:
    - Nếu detail đã là dict có 'code' + 'message' → pass-through nguyên văn.
    - Ngược lại → wrap vào envelope chuẩn.
    """
    detail = exc.detail

    if isinstance(detail, dict) and "code" in detail and "message" in detail:
        # Đã có envelope — pass-through (+ request_id để đối chiếu log)
        content = {"error": dict(detail)}
        rid = _request_id()
        if rid and "request_id" not in content["error"]:
            content["error"]["request_id"] = rid
    elif isinstance(detail, str):
        # String message từ routers cũ
        content = _make_error(code=f"HTTP_{exc.status_code}", message=detail)
    else:
        content = _make_error(code=f"HTTP_{exc.status_code}", message=str(detail))

    return JSONResponse(status_code=exc.status_code, content=content)


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Fallback cho 500. Stack trace bị ẩn khi production để tránh leak nội bộ.
    """
    from app.config import settings  # import late

    is_prod = getattr(settings, "environment", "development") == "production"

    # ── Structured log (đã redact) — nguồn dữ liệu cho pipeline self-heal ──────
    tb_text = redact_text(traceback.format_exc())
    fingerprint = compute_fingerprint(
        exc_type=type(exc).__name__,
        message=str(exc),
        route=request.scope.get("path"),
        top_frame=top_frame_of(tb_text),
    )
    _logger.error(
        "unhandled_exception",
        extra={
            "event": "unhandled_exception",
            "error_code": "INTERNAL_ERROR",
            "exc_type": type(exc).__name__,
            "fingerprint": fingerprint,
            "method": request.method,
            "path": request.url.path,
            "traceback": tb_text,
        },
    )

    if is_prod:
        details = None
    else:
        details = {"traceback": traceback.format_exc()}

    return JSONResponse(
        status_code=500,
        content=_make_error(
            code="INTERNAL_ERROR",
            message="Lỗi máy chủ nội bộ",
            details=details,
        ),
    )


def _retry_after_seconds(request: Request, exc: RateLimitExceeded) -> int:
    """Giây tới khi cửa sổ slowapi mở lại; đọc kho đếm thất bại ⇒ cả độ dài cửa sổ (an toàn)."""
    try:
        limit, args = request.state.view_rate_limit
        reset_at, _ = request.app.state.limiter.limiter.get_window_stats(limit, *args)
        return max(1, int(reset_at - time.time()) + 1)
    except Exception:  # noqa: BLE001 — header phụ, không được làm hỏng response 429
        try:
            return max(1, int(exc.limit.limit.get_expiry()))
        except Exception:  # noqa: BLE001
            return 60


async def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    """429 theo envelope chung + `Retry-After` cho mọi route slowapi (QA M2, Phase 08).

    Thay `_rate_limit_exceeded_handler` của slowapi (body `{"error": "<chuỗi>"}`, không Retry-After).
    """
    return JSONResponse(
        status_code=429,
        content=_make_error(code="RATE_LIMITED", message=f"Rate limit exceeded: {exc.detail}"),
        headers={"Retry-After": str(_retry_after_seconds(request, exc))},
    )
