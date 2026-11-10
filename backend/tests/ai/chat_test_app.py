"""App test cho `POST /api/ai/chat` + fixture chung (plan 20261027-1102 Phase 08, bước 0)."""

from __future__ import annotations

from contextlib import nullcontext
from typing import Callable

import pytest

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from slowapi.errors import RateLimitExceeded
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.ai_capabilities.loader import Registry, get_registry
from app.api.routes import ai_chat
from app.config import settings
from app.middleware.error_handler import http_exception_handler, rate_limit_exceeded_handler, validation_handler
from app.middleware.rate_limit import limiter
from app.services.ai_chat.anthropic_client import get_anthropic_client
from tests.ai.fake_anthropic import FakeAnthropic


def build_chat_test_app(db, fake, registry_provider: Callable[[], Registry]) -> FastAPI:
    """FastAPI trần + router chat; Claude = `fake`, DB = SQLite của test."""
    app = FastAPI()
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, rate_limit_exceeded_handler)
    app.add_exception_handler(RequestValidationError, validation_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.include_router(ai_chat.router)
    app.dependency_overrides[get_anthropic_client] = lambda: fake
    app.dependency_overrides[get_registry] = registry_provider
    app.dependency_overrides[ai_chat.get_chat_session_scope] = lambda: (lambda: nullcontext(db))
    return app


@pytest.fixture()
def fake() -> FakeAnthropic:
    return FakeAnthropic()


@pytest.fixture(autouse=True)
def chat_env(monkeypatch):
    """Region jp, key giả, giờ Tokyo (env `$PYTEST` ghim Asia/Ho_Chi_Minh); bộ đếm slowapi sạch."""
    monkeypatch.setattr(settings, "region", "jp")
    monkeypatch.setattr(settings, "anthropic_api_key", "test-key")
    monkeypatch.setattr(settings, "default_tz", "Asia/Tokyo")
    monkeypatch.setattr(settings, "mcp_allowed_hosts", ["testserver"])
    monkeypatch.setattr(settings, "mcp_allowed_origins", [])
    limiter.reset()
    yield
    limiter.reset()
