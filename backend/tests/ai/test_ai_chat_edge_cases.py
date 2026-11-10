"""`POST /api/ai/chat` ca biên từ QA Phase 08: M1, M2, M3, M5, L1, L2, L6 (qa-reviewer-261110-phase-08.md)."""

from __future__ import annotations

import logging
from types import SimpleNamespace

import httpx
import pytest
from anthropic import APIStatusError
from fastapi.testclient import TestClient

from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from app.config import settings
from app.schemas.ai_chat import MAX_TOTAL_CHARS
from app.services.ai_chat.chat_service import FALLBACK_REPLIES
from tests.ai.chat_test_app import build_chat_test_app, chat_env, fake  # noqa: F401 — fixture
from tests.ai.fake_anthropic import fake_text, fake_tool_use
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture

SECRET_Q = "渋谷で秘密のメモ-XYZ-123"
SEARCH = {"action": "search_listings", "params": {"station_name": "渋谷", "max_rent_jpy": 150000, "layouts": ["1LDK"]}}


@pytest.fixture()
def client(fake):
    db = make_sqlite_session()
    seed_search_fixture(db)
    reg = load_registry(DEFAULT_REGISTRY_PATH)
    yield TestClient(build_chat_test_app(db, fake, lambda: reg))
    db.close()


def _ask(client, content: str = SECRET_Q, **extra):
    return client.post("/api/ai/chat", json={"messages": [{"role": "user", "content": content}], **extra})


@pytest.mark.parametrize("blank", ["   ", "\n\t", "　"])
def test_ai_chat_blank_message_content_returns_422(client, fake, blank):
    # Act
    res = _ask(client, blank)
    # Assert — chặn trước khi gọi Claude (Messages API trả 400 cho text rỗng ⇒ từng thành 502)
    assert res.status_code == 422 and res.json()["error"]["code"] == "VALIDATION_ERROR"
    assert fake.messages.calls == []


def test_ai_chat_tool_use_without_blocks_returns_text_without_empty_user_turn(client, fake):
    # Arrange
    fake.script[:] = [SimpleNamespace(stop_reason="tool_use", content=[SimpleNamespace(type="text", text="確認中です")])]
    # Act
    res = _ask(client)
    # Assert
    assert res.status_code == 200 and res.json()["reply"] == "確認中です"
    assert len(fake.messages.calls) == 1 and res.json()["tool_rounds"] == 0


def test_ai_chat_round_limit_fallback_has_no_listing_cards(client, fake):
    # Arrange — mọi vòng đều tìm được tin nhưng model không chịu kết thúc
    fake.script[:] = [fake_tool_use("run_action", SEARCH, f"tu{i}") for i in range(7)]
    # Act
    body = _ask(client).json()
    # Assert
    assert body["reply"] == FALLBACK_REPLIES["ja"] and body["listings"] == []
    assert body["tool_rounds"] == 6 and len(body["tool_calls"]) == 6


def test_ai_chat_api_status_error_returns_502(client, fake):
    # Arrange
    req = httpx.Request("POST", "https://api.anthropic.com/v1/messages")

    async def boom(**kwargs):
        raise APIStatusError("overloaded", response=httpx.Response(529, request=req), body=None)
    fake.script[:] = [boom]
    # Act
    res = _ask(client)
    # Assert
    assert res.status_code == 502 and res.json()["error"]["code"] == "AI_UPSTREAM_ERROR"


def test_ai_chat_turn_logs_registry_fields_without_message_text(client, fake, caplog):
    # Arrange
    fake.script[:] = [fake_tool_use("run_action", SEARCH, "tu1"), fake_text("ありました")]
    # Act
    with caplog.at_level(logging.INFO):
        assert _ask(client).status_code == 200
    # Assert — NF-1: 1 dòng ai_chat_tools đủ trường; không dòng log nào chứa nội dung chat
    rows = [r for r in caplog.records if getattr(r, "event", None) == "ai_chat_tools"]
    assert len(rows) == 1
    row = rows[0]
    assert "search_listings" in row.actions and row.registry_version and row.market == "jp"
    assert (row.tool_rounds, row.lang) == (1, "ja") and row.model
    assert all("XYZ-123" not in (r.getMessage() + str(r.__dict__)) for r in caplog.records)


def test_ai_chat_rate_limit_429_uses_error_envelope_and_retry_after(client, fake, monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "ai_chat_rate_limit", "1/hour")
    fake.script[:] = [fake_text("はい")]
    assert _ask(client).status_code == 200
    # Act
    res = _ask(client)
    # Assert — QA M2: envelope chung để Flutter (P10) đọc một dạng, kèm Retry-After
    assert res.status_code == 429 and res.json()["error"]["code"] == "RATE_LIMITED"
    assert 1 <= int(res.headers["retry-after"]) <= 3600


def test_ai_chat_total_history_over_cap_returns_422(client, fake):
    # Arrange — 5 tin × 2.000 ký tự = 10.000 > MAX_TOTAL_CHARS
    long = "あ" * 2000
    msgs = [{"role": r, "content": long} for r in ("user", "assistant", "user", "assistant", "user")]
    # Act
    res = client.post("/api/ai/chat", json={"messages": msgs})
    # Assert
    assert sum(len(m["content"]) for m in msgs) > MAX_TOTAL_CHARS
    assert res.status_code == 422 and fake.messages.calls == []


def test_ai_chat_tool_calls_over_cap_stops_with_fallback(client, fake, monkeypatch):
    # Arrange — 1 vòng đòi 9 tool cùng lúc (> trần 8)
    monkeypatch.setattr(settings, "ai_chat_max_tool_calls", 8)
    blocks = [SimpleNamespace(type="tool_use", id=f"tu{i}", name="get_system_skills", input={}) for i in range(9)]
    fake.script[:] = [SimpleNamespace(stop_reason="tool_use", content=blocks)]
    # Act
    body = _ask(client).json()
    # Assert
    assert body["reply"] == FALLBACK_REPLIES["ja"] and body["tool_calls"] == []
    assert len(fake.messages.calls) == 1


def test_ai_chat_multiple_tool_blocks_in_one_response_keep_order_ids_and_errors(client, fake):
    # Arrange — text trước, 1 tool lỗi tham số + 1 tool đúng trong CÙNG response (review M5)
    blocks = [SimpleNamespace(type="text", text="調べます"),
              SimpleNamespace(type="tool_use", id="bad", name="run_action",
                              input={"action": "search_listings", "params": {"max_walk_min": "ten"}}),
              SimpleNamespace(type="tool_use", id="ok", name="run_action", input=SEARCH)]
    fake.script[:] = [SimpleNamespace(stop_reason="tool_use", content=blocks), fake_text("ありました")]
    # Act
    body = _ask(client).json()
    # Assert
    results = fake.messages.calls[1]["messages"][-1]["content"]
    assert [(r["tool_use_id"], r["is_error"]) for r in results] == [("bad", True), ("ok", False)]
    assert [c["is_error"] for c in body["tool_calls"]] == [True, False] and body["tool_rounds"] == 1
    assert body["listings"]  # không trích dẫn ⇒ thẻ = kết quả search đúng


def test_ai_chat_long_model_reply_clamped_to_message_limit(client, fake):
    # Arrange — reply dài hơn trần content 2.000 ⇒ client gửi lại làm lịch sử sẽ 422 (review L1)
    fake.script[:] = [fake_text("a" * 4000)]
    # Act
    body = _ask(client).json()
    # Assert
    assert len(body["reply"]) == 2000


def test_ai_chat_retry_after_falls_back_to_window_length_when_stats_fail():
    # Arrange
    from app.middleware.error_handler import _retry_after_seconds
    request = SimpleNamespace(state=SimpleNamespace(), app=SimpleNamespace(state=SimpleNamespace()))
    exc = SimpleNamespace(limit=SimpleNamespace(limit=SimpleNamespace(get_expiry=lambda: 3600)))
    # Act / Assert
    assert _retry_after_seconds(request, exc) == 3600
