"""Chat + action ghi: thẻ xác nhận, khách phải đăng nhập, token không lọt tới model (Phase 09, AC14 phần chat)."""

from __future__ import annotations

import json

import pytest
from fastapi.testclient import TestClient

from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from app.domain.ai_pending_action import AiPendingAction
from app.models import Wishlist
from tests.ai.chat_test_app import build_chat_test_app, chat_env, fake  # noqa: F401 — fixture
from tests.ai.fake_anthropic import fake_text, fake_tool_use
from tests.ai.write_test_utils import WRITE_TABLES, add_actions_router, bearer, make_user
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture

ASK = {"messages": [{"role": "user", "content": "この物件をお気に入りに保存して"}]}


@pytest.fixture()
def db():
    session = make_sqlite_session(extra_tables=WRITE_TABLES)
    yield session
    session.close()


@pytest.fixture()
def ids(db):
    return seed_search_fixture(db)


@pytest.fixture()
def client(db, ids, fake):
    reg = load_registry(DEFAULT_REGISTRY_PATH)
    return TestClient(add_actions_router(build_chat_test_app(db, fake, lambda: reg), db, lambda: reg))


def _script_save(fake, listing_id: int) -> None:
    fake.script[:] = [
        fake_tool_use("run_action", {"action": "save_favorite", "params": {"listing_id": listing_id}}, "tu1"),
        fake_text("確認カードを表示しました。"),
    ]


def test_ai_chat_write_logged_in_returns_pending_card_without_db_write(client, fake, db, ids):
    # Arrange
    _script_save(fake, ids["[SBY-OK1]"])
    uid = make_user(db)
    # Act
    res = client.post("/api/ai/chat", json=ASK, headers={**bearer(uid), "Accept-Language": "ja"})
    # Assert
    body = res.json()
    assert res.status_code == 200 and body["login_required"] is False and len(body["pending_actions"]) == 1
    card = body["pending_actions"][0]
    assert card["action"] == "save_favorite" and card["params"] == {"listing_id": ids["[SBY-OK1]"]}
    assert len(card["token"]) == 43 and card["title"] and card["expires_at"]
    assert db.query(Wishlist).count() == 0 and db.query(AiPendingAction).one().owner_user_id == uid
    sent = fake.messages.calls[1]["messages"][-1]["content"][0]["content"]
    assert card["token"] not in sent and "pending_token" not in json.loads(sent)  # token không qua model


def test_ai_chat_write_guest_returns_login_required(client, fake, db, ids):
    # Arrange
    _script_save(fake, ids["[SBY-OK1]"])
    # Act
    res = client.post("/api/ai/chat", json=ASK)
    # Assert
    body = res.json()
    assert res.status_code == 200 and body["login_required"] is True and body["pending_actions"] == []
    assert db.query(AiPendingAction).count() == 0 and db.query(Wishlist).count() == 0


def test_ai_chat_write_confirm_by_other_user_returns_403(client, fake, db, ids):
    # Arrange
    _script_save(fake, ids["[SBY-OK1]"])
    owner, other = make_user(db, "a@example.invalid"), make_user(db, "b@example.invalid")
    token = client.post("/api/ai/chat", json=ASK, headers=bearer(owner)).json()["pending_actions"][0]["token"]
    # Act
    res = client.post(f"/api/ai/actions/{token}/confirm", headers=bearer(other))
    # Assert
    assert res.status_code == 403 and res.json()["error"]["code"] == "forbidden"
    assert db.query(Wishlist).count() == 0
    assert client.post(f"/api/ai/actions/{token}/confirm", headers=bearer(owner)).status_code == 200
