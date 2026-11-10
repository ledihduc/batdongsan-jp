"""Helper test action ghi AI: user, JWT, slot hợp lệ, app MCP + xác nhận (plan 20261027-1102 Phase 09)."""

from __future__ import annotations

from contextlib import nullcontext
from datetime import datetime, timedelta, timezone
from typing import Callable

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from slowapi.errors import RateLimitExceeded
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.ai_capabilities.loader import Registry, get_registry
from app.auth import sign_token
from app.database import get_db
from app.mcp.mount import mount_mcp
from app.middleware.error_handler import http_exception_handler, rate_limit_exceeded_handler, validation_handler
from app.middleware.rate_limit import limiter
from app.models import User

WRITE_TABLES = ("wishlists", "jp_viewings", "ai_pending_actions")
_JST = timezone(timedelta(hours=9))


def make_user(db, email: str = "t@example.invalid") -> int:
    user = User(name="AI Tester", email=email, password_hash="x", role="guest", is_active=True)
    db.add(user)
    db.commit()
    return user.id


def bearer(user_id: int) -> dict:
    return {"Authorization": f"Bearer {sign_token(user_id, 'guest')}"}


def valid_slot(days: int = 2, hour: int = 11) -> str:
    """Slot ISO `+09:00` cách hôm nay `days` ngày, đúng `hour` giờ Tokyo."""
    day = datetime.now(_JST) + timedelta(days=days)
    return day.replace(hour=hour, minute=0, second=0, microsecond=0).isoformat()


def add_actions_router(app: FastAPI, db, registry_provider: Callable[[], Registry]) -> FastAPI:
    """Gắn router xác nhận + override DB/registry vào app test có sẵn (vd app chat P08)."""
    from app.api.routes import ai_actions  # noqa: PLC0415 — import trễ: test FAIL đúng chỗ khi chưa có route

    app.include_router(ai_actions.router)
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_registry] = registry_provider
    return app


def build_actions_test_app(db, registry_provider: Callable[[], Registry]) -> FastAPI:
    """FastAPI trần + `/mcp` + `/api/ai/actions/*`; DB = SQLite của test (dùng trong `with TestClient`)."""
    app = FastAPI()
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, rate_limit_exceeded_handler)
    app.add_exception_handler(RequestValidationError, validation_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    mount_mcp(app, registry_provider=registry_provider, session_scope=lambda: nullcontext(db))
    return add_actions_router(app, db, registry_provider)
