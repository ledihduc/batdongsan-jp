"""Hồi quy QA/CR Phase 09: C1 (chặn event loop), M1 (token vào log), M2 (giờ không offset), L6 (lang), CR M-1."""

from __future__ import annotations

import inspect
import logging
from datetime import datetime

import pytest
from fastapi.testclient import TestClient

from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from app.api.routes import ai_actions
from app.config import settings
from app.middleware.rate_limit import limiter
from app.observability.middleware import RequestContextMiddleware
from app.services.ai_actions import confirm_service
from app.domain.ai_pending_action import AiPendingAction
from app.models import Wishlist
from app.services.jp_search import ai_write_tools
from tests.ai.mcp_test_client import mcp_tool
from tests.ai.write_test_utils import WRITE_TABLES, bearer, build_actions_test_app, make_user, valid_slot
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.setattr(settings, "region", "jp")
    monkeypatch.setattr(settings, "mcp_allowed_hosts", ["testserver"])
    monkeypatch.setattr(settings, "mcp_allowed_origins", [])
    limiter.reset()
    yield
    limiter.reset()


@pytest.fixture()
def db():
    session = make_sqlite_session(extra_tables=WRITE_TABLES)
    yield session
    session.close()


@pytest.fixture()
def ids(db):
    return seed_search_fixture(db)


@pytest.fixture()
def c(db, ids):
    reg = load_registry(DEFAULT_REGISTRY_PATH)
    app = build_actions_test_app(db, lambda: reg)
    app.add_middleware(RequestContextMiddleware, hash_salt="testsalt")
    with TestClient(app) as client:
        yield client


def _token(c, listing_id: int) -> str:
    is_error, out = mcp_tool(c, "run_action", {"action": "save_favorite", "params": {"listing_id": listing_id}})
    assert not is_error, out
    return out["confirm_url"].rsplit("/", 1)[1]


def test_ai_actions_confirm_path_is_sync_so_row_lock_wait_never_blocks_event_loop():
    # Assert — `def` ⇒ FastAPI chạy trong threadpool; `async def` + UPDATE đồng bộ ⇒ treo loop khi bấm trùng (C1)
    assert not inspect.iscoroutinefunction(ai_actions.confirm_ai_action)
    assert not inspect.iscoroutinefunction(inspect.unwrap(ai_actions.confirm_ai_action))
    assert not inspect.iscoroutinefunction(confirm_service.confirm_pending)


def test_ai_actions_request_log_redacts_confirm_token(c, ids, caplog):
    # Arrange
    token = _token(c, ids["[SBY-OK1]"])
    caplog.set_level(logging.INFO, logger="app.request")
    # Act
    c.get(f"/api/ai/actions/{token}")
    c.post(f"/api/ai/actions/{token}/confirm")
    # Assert
    logged = [f"{r.path} {r.route}" for r in caplog.records if getattr(r, "event", "") == "http_request"]
    assert len(logged) == 2 and all("/api/ai/actions/{token}" in line for line in logged)
    assert not any(token in line for line in logged)


def test_ai_actions_preview_expires_at_has_utc_offset_and_accepts_locale_lang(c, ids):
    # Act
    res = c.get(f"/api/ai/actions/{_token(c, ids['[SBY-OK1]'])}", params={"lang": "ja-JP"})
    # Assert
    body = res.json()
    assert res.status_code == 200 and body["title"] == "お気に入りに保存"
    assert datetime.fromisoformat(body["expires_at"].replace("Z", "+00:00")).utcoffset() is not None


def test_ai_actions_mcp_write_with_invalid_slot_creates_no_pending(c, db, ids):
    # Act — dry-run handler từ chối ⇒ không được tạo pending (thứ tự dry-run trước create_pending, CR M-1)
    is_error, out = mcp_tool(c, "run_action", {"action": "request_viewing",
                                               "params": {"listing_id": ids["[SBY-OK1]"], "slots": [valid_slot(days=-1)]}})
    # Assert
    assert is_error and out["error"] == "invalid_arguments" and db.query(AiPendingAction).count() == 0


def test_ai_actions_confirm_handler_crash_returns_502_and_marks_failed(c, db, ids, monkeypatch):
    # Arrange
    token = _token(c, ids["[SBY-OK1]"])

    def boom(*_a, **_k):
        raise RuntimeError("db exploded")

    monkeypatch.setattr(ai_write_tools, "save_wishlist", boom)
    # Act
    res = c.post(f"/api/ai/actions/{token}/confirm", headers=bearer(make_user(db)))
    # Assert
    db.expire_all()
    row = db.query(AiPendingAction).one()
    assert res.status_code == 502 and res.json()["error"]["code"] == "upstream_error"
    assert "exploded" not in res.text and row.status == "failed" and row.error_code == "upstream_error"
    assert db.query(Wishlist).count() == 0
