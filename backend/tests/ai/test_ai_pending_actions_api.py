"""MCP tạo pending → GET xem trước → POST xác nhận (JWT) (Phase 09, AC14 phần MCP + xác nhận)."""

from __future__ import annotations

from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from tests.ai.write_test_utils import WRITE_TABLES, bearer, build_actions_test_app, make_user, valid_slot

from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from app.config import settings
from app.domain.ai_pending_action import AiPendingAction
from app.domain.jp.viewing import JpViewing
from app.middleware.rate_limit import limiter
from app.models import Wishlist
from app.services.ai_actions.pending_store import utcnow
from tests.ai.ai_registry_test_utils import packaged_registry_dict, write_registry
from tests.ai.mcp_test_client import mcp_tool
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.setattr(settings, "region", "jp")  # listing_brief rẽ theo region
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
def holder():
    return {"reg": load_registry(DEFAULT_REGISTRY_PATH)}


@pytest.fixture()
def c(db, ids, holder):
    with TestClient(build_actions_test_app(db, lambda: holder["reg"])) as client:
        yield client


def _pending(c, action: str, params: dict) -> str:
    is_error, out = mcp_tool(c, "run_action", {"action": action, "params": params})
    assert not is_error, out
    return out["confirm_url"].rsplit("/", 1)[1]


def test_ai_actions_mcp_write_returns_confirm_link_without_db_write(c, db, ids):
    # Act
    is_error, out = mcp_tool(c, "run_action", {"action": "save_favorite", "params": {"listing_id": ids["[SBY-OK1]"]}})
    # Assert
    assert not is_error and out["status"] == "confirmation_required" and "/ai-confirm/" in out["confirm_url"]
    assert db.query(Wishlist).count() == 0 and db.query(AiPendingAction).count() == 1


def test_ai_actions_preview_returns_action_and_listing(c, ids):
    # Arrange
    token = _pending(c, "save_favorite", {"listing_id": ids["[SBY-OK1]"]})
    # Act
    res = c.get(f"/api/ai/actions/{token}", params={"lang": "en"})
    # Assert
    body = res.json()
    assert res.status_code == 200 and body["action"] == "save_favorite" and body["title"] == "Save to favorites"
    assert body["listing"]["title"].startswith("[SBY-OK1]") and body["listing"]["currency"] == "JPY"
    assert body["listing"]["price"] == 120000 and body["status"] == "pending" and body["owner_bound"] is False


def test_ai_actions_confirm_with_jwt_creates_row_for_that_user(c, db, ids):
    # Arrange
    token = _pending(c, "save_favorite", {"listing_id": ids["[SBY-OK1]"]})
    uid = make_user(db)
    # Act
    res = c.post(f"/api/ai/actions/{token}/confirm", headers=bearer(uid))
    # Assert
    assert res.status_code == 200 and res.json()["status"] == "executed" and res.json()["result"]["created"] is True
    assert db.query(Wishlist).filter_by(user_id=uid).count() == 1
    row = db.query(AiPendingAction).one()
    assert row.status == "executed" and row.executed_by_user_id == uid and row.result["wishlist_id"]


def test_ai_actions_confirm_twice_returns_409(c, db, ids):
    # Arrange
    token = _pending(c, "save_favorite", {"listing_id": ids["[SBY-OK1]"]})
    uid = make_user(db)
    assert c.post(f"/api/ai/actions/{token}/confirm", headers=bearer(uid)).status_code == 200
    # Act
    res = c.post(f"/api/ai/actions/{token}/confirm", headers=bearer(uid))
    # Assert
    assert res.status_code == 409 and res.json()["error"]["code"] == "used"
    assert c.get(f"/api/ai/actions/{token}").status_code == 409


def test_ai_actions_confirm_expired_returns_410(c, db, ids):
    # Arrange
    token = _pending(c, "save_favorite", {"listing_id": ids["[SBY-OK1]"]})
    db.query(AiPendingAction).update({"expires_at": utcnow() - timedelta(minutes=1)})
    db.commit()
    # Act
    res = c.post(f"/api/ai/actions/{token}/confirm", headers=bearer(make_user(db)))
    # Assert
    assert res.status_code == 410 and res.json()["error"]["code"] == "expired"
    assert db.query(Wishlist).count() == 0 and c.get(f"/api/ai/actions/{token}").status_code == 410


def test_ai_actions_confirm_without_jwt_returns_401(c, db, ids):
    # Arrange
    token = _pending(c, "save_favorite", {"listing_id": ids["[SBY-OK1]"]})
    # Act
    res = c.post(f"/api/ai/actions/{token}/confirm")
    # Assert
    assert res.status_code == 401 and db.query(Wishlist).count() == 0


def test_ai_actions_confirm_unknown_token_returns_404(c, db):
    # Act — đúng dạng 43 ký tự nhưng không có; sai dạng cũng 404
    res = c.post(f"/api/ai/actions/{'A' * 43}/confirm", headers=bearer(make_user(db)))
    bad = c.get("/api/ai/actions/short")
    # Assert
    assert res.status_code == 404 and res.json()["error"]["code"] == "not_found" and bad.status_code == 404


def test_ai_actions_confirm_request_viewing_creates_viewing(c, db, ids):
    # Arrange
    token = _pending(c, "request_viewing", {"listing_id": ids["[SBY-OK1]"], "slots": [valid_slot()]})
    uid = make_user(db)
    # Act
    res = c.post(f"/api/ai/actions/{token}/confirm", headers=bearer(uid))
    # Assert
    assert res.status_code == 200 and res.json()["result"]["status"] == "requested"
    assert db.query(JpViewing).one().tenant_id == uid


def test_ai_actions_confirm_invalid_slot_at_confirm_returns_422_and_marks_failed(c, db, ids):
    # Arrange — giờ đã trôi: slot của pending thành quá khứ
    token = _pending(c, "request_viewing", {"listing_id": ids["[SBY-OK1]"], "slots": [valid_slot()]})
    db.query(AiPendingAction).update({"params": {"listing_id": ids["[SBY-OK1]"], "slots": [valid_slot(days=-1)]}})
    db.commit()
    # Act
    res = c.post(f"/api/ai/actions/{token}/confirm", headers=bearer(make_user(db)))
    # Assert
    db.expire_all()
    row = db.query(AiPendingAction).one()
    assert res.status_code == 422 and res.json()["error"]["code"] == "invalid_arguments"
    assert row.status == "failed" and row.error_code == "invalid_arguments" and db.query(JpViewing).count() == 0


def test_ai_actions_disabled_action_at_confirm_returns_410(c, db, ids, holder, tmp_path):
    # Arrange — registry đổi sau khi tạo pending: save_favorite bị gỡ
    token = _pending(c, "save_favorite", {"listing_id": ids["[SBY-OK1]"]})
    actions = [a for a in packaged_registry_dict()["actions"] if a["name"] != "save_favorite"]
    holder["reg"] = load_registry(write_registry(tmp_path, actions))
    # Act
    res = c.post(f"/api/ai/actions/{token}/confirm", headers=bearer(make_user(db)))
    # Assert
    assert res.status_code == 410 and res.json()["error"]["code"] == "action_unavailable"
    assert db.query(Wishlist).count() == 0
