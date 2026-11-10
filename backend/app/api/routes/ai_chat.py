"""`POST /api/ai/chat` — chat AI không stream, không trạng thái (plan 20261027-1102 Phase 08).

Router mỏng: kiểm key, dựng `ActionContext`, đặt hạn chót lượt, map lỗi; logic ở
`app.services.ai_chat`. Không gắn `require_region`: chỉ include trong khối
`if ai_enabled_for_region(...)` của main.py (T8, D19). Đăng nhập không bắt buộc (F-6).
"""

# Không dùng `from __future__ import annotations`: slowapi bọc hàm, FastAPI đọc annotation chuỗi
# theo globals của slowapi ⇒ body `AiChatRequest` không resolve được, request nào cũng 422.
import asyncio
import logging
from typing import Callable, ContextManager, Optional

from anthropic import APIError, APITimeoutError
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.loader import Registry, get_registry
from app.auth import optional_user
from app.config import settings
from app.database import SessionLocal
from app.middleware.rate_limit import limiter
from app.schemas.ai_chat import AiChatRequest, AiChatResponse
from app.services.ai_chat.anthropic_client import AI_NOT_CONFIGURED, get_anthropic_client
from app.services.ai_chat.chat_service import run_chat_turn

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/ai", tags=["ai-chat"])

_TIMEOUT = {"code": "AI_TIMEOUT", "message": "AI did not answer in time"}
_UPSTREAM = {"code": "AI_UPSTREAM_ERROR", "message": "AI service error"}


def get_chat_session_scope() -> Callable[[], ContextManager[Session]]:
    """Session cho handler python của action; test override bằng SQLite."""
    return SessionLocal


@router.post("/chat", response_model=AiChatResponse)
@limiter.limit(lambda: settings.ai_chat_rate_limit)
async def ai_chat(
    request: Request,
    payload: AiChatRequest,
    claims: Optional[dict] = Depends(optional_user),
    client=Depends(get_anthropic_client),
    registry: Registry = Depends(get_registry),
    session_scope=Depends(get_chat_session_scope),
) -> AiChatResponse:
    if not settings.anthropic_api_key:  # trước mọi việc khác (N103)
        raise HTTPException(status_code=503, detail=AI_NOT_CONFIGURED)
    ctx = ActionContext(
        channel="chat",
        user=claims,
        authorization=request.headers.get("authorization") if claims else None,
        asgi_app=request.app,
    )
    lang = payload.lang or registry.default_lang
    try:
        async with asyncio.timeout(settings.ai_chat_turn_deadline_s):
            result = await run_chat_turn(
                client, registry, [m.model_dump() for m in payload.messages], lang=lang, ctx=ctx,
                model=settings.ai_chat_model, max_rounds=settings.ai_chat_max_tool_rounds,
                max_tokens=settings.ai_chat_max_tokens, max_tool_calls=settings.ai_chat_max_tool_calls,
                session_scope=session_scope,
            )
    except (TimeoutError, APITimeoutError):  # APITimeoutError là con của APIError ⇒ bắt trước
        logger.warning("ai_chat_timeout", extra={"event": "ai_chat_timeout", "model": settings.ai_chat_model})
        raise HTTPException(status_code=504, detail=_TIMEOUT) from None
    except APIError as exc:  # kết nối, status, validation response… sau retry (L2)
        logger.warning("ai_chat_upstream_error", extra={
            "event": "ai_chat_upstream_error", "error": type(exc).__name__,
            "status": getattr(exc, "status_code", None)})
        raise HTTPException(status_code=502, detail=_UPSTREAM) from None
    return AiChatResponse(
        reply=result.reply, listings=result.listings, tool_rounds=result.tool_rounds,
        tool_calls=result.tool_calls, model=settings.ai_chat_model,
        pending_actions=list(result.pending_actions), login_required=result.login_required,
    )
