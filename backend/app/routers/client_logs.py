"""
/api/client-logs — nhận crash/error từ Flutter, redact rồi ghi vào cùng
JSONL sink (logger 'app.client'). Pipeline self-heal xử lý chung với lỗi backend.

An toàn:
- Rate-limit chống spam (slowapi).
- Redact PII/secret ngay khi nhận (payload từ client không đáng tin).
- Không lưu user-id thô — middleware đã gắn user_hash qua contextvar.

Note: KHÔNG dùng `from __future__ import annotations` ở đây — FastAPI/pydantic
cần resolve model ClientLog qua decorator limiter (forward-ref sẽ fail).
"""

import logging

from fastapi import APIRouter, Request
from pydantic import BaseModel, Field

from app.config import settings
from app.middleware.rate_limit import limiter
from app.observability.fingerprint import compute_fingerprint
from app.observability.redaction import redact_obj, redact_text

router = APIRouter(prefix="/api/client-logs", tags=["observability"])
_logger = logging.getLogger("app.client")


class ClientLog(BaseModel):
    level: str = Field(default="error", max_length=16)
    message: str = Field(default="", max_length=2000)
    error_type: str | None = Field(default=None, max_length=200)
    stack: str | None = Field(default=None, max_length=8000)
    route: str | None = Field(default=None, max_length=200)
    platform: str | None = Field(default=None, max_length=40)
    app_version: str | None = Field(default=None, max_length=40)
    context: dict | None = None


@router.post("", status_code=204)
@limiter.limit("120/hour")
async def ingest_client_log(request: Request, body: ClientLog):
    if not settings.client_logs_enabled:
        return

    stack = redact_text(body.stack or "")
    fingerprint = compute_fingerprint(
        exc_type=body.error_type or "ClientError",
        message=body.message,
        route=body.route,
        top_frame=(stack.splitlines()[0] if stack else ""),
    )
    level = logging.ERROR if body.level.lower() in ("error", "fatal") else logging.WARNING
    _logger.log(
        level,
        redact_text(body.message) or "client_error",
        extra={
            "event": "client_error",
            "source": "flutter",
            "error_code": body.error_type or "ClientError",
            "fingerprint": fingerprint,
            "route": redact_text(body.route or ""),
            "platform": body.platform,
            "app_version": body.app_version,
            "traceback": stack,
            "context": redact_obj(body.context or {}),
        },
    )
    return
