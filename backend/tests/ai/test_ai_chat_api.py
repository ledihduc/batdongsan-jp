"""`POST /api/ai/chat`: vòng lặp 2 tool, thẻ tin, lỗi, hạn mức (Phase 08, AC7, AC11, AC16)."""

from __future__ import annotations

import asyncio
import json
import re

import pytest
from fastapi.testclient import TestClient

from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from app.auth import sign_token
from app.config import settings
from app.services.ai_chat import chat_service
from app.services.ai_chat.chat_service import FALLBACK_REPLIES, REFUSAL_REPLIES
from app.services.jp_search.listing_search_service import JpListingFilters, search_listings
from tests.ai.chat_test_app import build_chat_test_app, chat_env, fake  # noqa: F401 — fixture
from tests.ai.fake_anthropic import fake_text, fake_tool_use
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture

USER_Q = {"messages": [{"role": "user", "content": "渋谷駅から徒歩10分以内、家賃15万円以下の1LDK"}]}


@pytest.fixture()
def db():
    session = make_sqlite_session()
    yield session
    session.close()


@pytest.fixture()
def ids(db):
    return seed_search_fixture(db)


@pytest.fixture(scope="module")
def reg():
    return load_registry(DEFAULT_REGISTRY_PATH)


@pytest.fixture()
def client(db, ids, reg, fake):
    return TestClient(build_chat_test_app(db, fake, lambda: reg))


def test_ai_chat_shibuya_query_returns_ja_reply_with_matching_listings(client, fake, ids, db):
    # Arrange
    ok = [ids["[SBY-OK1]"], ids["[SBY-OK2]"], ids["[SBY-OK3]"]]
    fake.script[:] = [
        fake_tool_use("run_action", {"action": "search_listings", "params": {
            "station_name": "渋谷", "max_walk_min": 10, "max_rent_jpy": 150000, "layouts": ["1LDK"], "limit": 10}}, "tu1"),
        fake_text("条件に合う物件は3件です。" + " ".join(f"[#{i}]" for i in ok)),
    ]
    # Act
    res = client.post("/api/ai/chat", json=USER_Q)
    # Assert
    body = res.json()
    assert res.status_code == 200 and re.search(r"[぀-ヿ一-鿿]", body["reply"])
    assert {c["listing_id"] for c in body["listings"]} == set(ok) and {c["currency"] for c in body["listings"]} == {"JPY"}
    expected = search_listings(db, JpListingFilters(
        layouts=("1LDK",), max_rent=150000, station_name="渋谷", max_walk_min=10, page_size=50))
    assert {c["listing_id"] for c in body["listings"]} <= {i["listing_id"] for i in expected.items}
    assert body["tool_rounds"] == 1 and body["tool_calls"][0]["arguments"]["action"] == "search_listings"
    assert body["model"] == settings.ai_chat_model
    second = fake.messages.calls[1]["messages"]
    assert second[-2]["role"] == "assistant"  # replay nguyên `response.content`
    assert second[-1]["role"] == "user" and second[-1]["content"][0]["type"] == "tool_result"
    assert second[-1]["content"][0]["tool_use_id"] == "tu1"
    json.loads(second[-1]["content"][0]["content"])  # JSON-encode (X8)


def test_ai_chat_tool_loop_stops_after_six_rounds(client, fake):
    # Arrange
    fake.script[:] = [fake_tool_use("get_system_skills", {}, f"tu{i}") for i in range(7)]
    # Act
    res = client.post("/api/ai/chat", json=USER_Q)
    # Assert
    body = res.json()
    assert res.status_code == 200 and body["reply"] == FALLBACK_REPLIES["ja"]
    assert body["tool_rounds"] == 6 and len(fake.messages.calls) == 7


def test_ai_chat_invalid_action_arguments_sends_is_error_tool_result(client, fake, ids):
    # Arrange
    fake.script[:] = [
        fake_tool_use("run_action", {"action": "search_listings", "params": {"max_walk_min": "ten"}}, "tu1"),
        fake_text("もう一度お試しください。"),
    ]
    # Act
    res = client.post("/api/ai/chat", json=USER_Q)
    # Assert
    result = fake.messages.calls[1]["messages"][-1]["content"][0]
    assert res.status_code == 200 and result["is_error"] is True
    assert json.loads(result["content"])["error"] == "invalid_arguments"
    assert res.json()["tool_calls"][0]["is_error"] is True and res.json()["listings"] == []


def test_ai_chat_logged_in_user_reaches_action_context(client, fake, monkeypatch):
    # Arrange
    seen = []

    async def spy(registry, name, arguments, ctx, **kwargs):
        seen.append(ctx)
        return False, {"items": [], "total": 0}
    monkeypatch.setattr(chat_service, "call_fixed_tool", spy)
    fake.script[:] = [fake_tool_use("run_action", {"action": "search_listings", "params": {}}, "tu1"), fake_text("なし")]
    token = sign_token(3, "guest")
    # Act
    res = client.post("/api/ai/chat", json=USER_Q, headers={"Authorization": f"Bearer {token}"})
    # Assert
    assert res.status_code == 200
    assert seen[0].user["sub"] == 3 and seen[0].channel == "chat"
    assert seen[0].authorization == f"Bearer {token}"


def test_ai_chat_refusal_returns_reply_in_request_lang(client, fake):
    # Arrange
    fake.script[:] = [fake_text("", stop_reason="refusal")]
    # Act
    res = client.post("/api/ai/chat", json={**USER_Q, "lang": "vi"})
    # Assert
    assert res.status_code == 200 and res.json()["reply"] == REFUSAL_REPLIES["vi"]
    assert res.json()["listings"] == []


def test_ai_chat_stop_reason_max_tokens_returns_partial_text_or_fallback(client, fake):
    # Arrange
    fake.script[:] = [fake_text("途中までの回答", stop_reason="max_tokens"), fake_text("", stop_reason="max_tokens")]
    # Act
    partial = client.post("/api/ai/chat", json=USER_Q).json()
    empty = client.post("/api/ai/chat", json={**USER_Q, "lang": "en"}).json()
    # Assert
    assert partial["reply"] == "途中までの回答"
    assert empty["reply"] == FALLBACK_REPLIES["en"]


def test_ai_chat_turn_deadline_exceeded_returns_504(client, fake, monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "ai_chat_turn_deadline_s", 0.05)

    async def slow(**kwargs):
        await asyncio.sleep(0.2)
        return fake_text("遅い")
    fake.script[:] = [slow]
    # Act
    res = client.post("/api/ai/chat", json=USER_Q)
    # Assert
    assert res.status_code == 504 and res.json()["error"]["code"] == "AI_TIMEOUT"


def test_ai_chat_missing_api_key_returns_503(client, monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "anthropic_api_key", "")
    # Act
    res = client.post("/api/ai/chat", json=USER_Q)
    # Assert
    assert res.status_code == 503 and res.json()["error"]["code"] == "AI_NOT_CONFIGURED"


def test_ai_chat_last_message_not_user_returns_422(client):
    # Act
    res = client.post("/api/ai/chat", json={"messages": [
        {"role": "user", "content": "こんにちは"}, {"role": "assistant", "content": "はい"}]})
    # Assert
    assert res.status_code == 422 and res.json()["error"]["code"] == "VALIDATION_ERROR"


def test_ai_chat_rate_limit_exceeded_returns_429(client, fake):
    # Arrange
    n = int(settings.ai_chat_rate_limit.split("/")[0])
    fake.script[:] = [fake_text("はい") for _ in range(n + 1)]
    # Act
    statuses = [client.post("/api/ai/chat", json=USER_Q).status_code for _ in range(n + 1)]
    # Assert
    assert statuses[:n] == [200] * n and statuses[n] == 429
