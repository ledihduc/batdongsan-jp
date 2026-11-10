"""Client Anthropic dùng chung cho chat (Phase 08). Test override `get_anthropic_client`."""

from __future__ import annotations

from functools import lru_cache

from anthropic import AsyncAnthropic
from fastapi import HTTPException

from app.config import settings

AI_NOT_CONFIGURED = {"code": "AI_NOT_CONFIGURED", "message": "AI chat is not configured"}


@lru_cache(maxsize=1)
def _build_client(api_key: str, timeout_s: float) -> AsyncAnthropic:
    return AsyncAnthropic(api_key=api_key, timeout=timeout_s, max_retries=2)


def get_anthropic_client() -> AsyncAnthropic:
    """Thiếu key ⇒ 503 trước khi dựng client (route cũng tự kiểm vì test override hàm này, N103)."""
    if not settings.anthropic_api_key:
        raise HTTPException(status_code=503, detail=AI_NOT_CONFIGURED)
    return _build_client(settings.anthropic_api_key, settings.ai_chat_call_timeout_s)
