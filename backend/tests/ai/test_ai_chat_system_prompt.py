"""Request gửi Claude: 2 tool cố định, cache, skill hệ thống theo `lang`, lỗi upstream (Phase 08, AC16, T13)."""

from __future__ import annotations

import httpx
import pytest
from anthropic import APIConnectionError, APITimeoutError
from fastapi.testclient import TestClient

from app.ai_capabilities.fixed_skill import fixed_instructions
from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from tests.ai.chat_test_app import build_chat_test_app, chat_env, fake  # noqa: F401 — fixture
from tests.ai.fake_anthropic import fake_text
from tests.jp.search.jp_search_fixtures import make_sqlite_session

USER_Q = {"messages": [{"role": "user", "content": "渋谷の1LDK"}]}


@pytest.fixture()
def reg():
    return load_registry(DEFAULT_REGISTRY_PATH)


@pytest.fixture()
def client(reg, fake):
    db = make_sqlite_session()
    yield TestClient(build_chat_test_app(db, fake, lambda: reg))
    db.close()


def _first_call(client, fake, body=None) -> dict:
    fake.script[:] = [fake_text("はい")]
    res = client.post("/api/ai/chat", json=body or USER_Q)
    assert res.status_code == 200
    return fake.messages.calls[0]


def test_ai_chat_request_has_two_fixed_tools_cache_control_and_no_sampling(client, fake):
    # Act
    kwargs = _first_call(client, fake)
    # Assert
    tools, system = kwargs["tools"], kwargs["system"]
    assert [t["name"] for t in tools] == ["get_system_skills", "run_action"]
    assert tools[-1]["cache_control"] == {"type": "ephemeral"} and "cache_control" not in tools[0]
    assert system[1]["cache_control"] == {"type": "ephemeral"}
    assert "cache_control" not in system[2] and "+09:00" in system[2]["text"]
    assert "temperature" not in kwargs and "tool_choice" not in kwargs


def test_ai_chat_system_prompt_preloads_system_skills_in_requested_lang(client, fake, reg):
    # Act
    kwargs = _first_call(client, fake, {**USER_Q, "lang": "en"})
    # Assert
    text = kwargs["system"][1]["text"]
    assert "Search rental listings" in text and reg.version in text


def test_ai_chat_system_prompt_contains_language_rule(client, fake):
    # Act
    kwargs = _first_call(client, fake)
    # Assert
    assert kwargs["system"][0]["text"] == fixed_instructions()
    assert "default_lang" in kwargs["system"][0]["text"]


def test_ai_chat_no_lang_uses_registry_default_lang(client, fake):
    # Act
    kwargs = _first_call(client, fake)
    # Assert
    text = kwargs["system"][1]["text"]
    assert "賃貸物件を検索" in text and '"lang":"ja"' in text


def test_ai_chat_messages_forwarded_as_history(client, fake):
    # Arrange
    history = {"messages": [{"role": "user", "content": "こんにちは"}, {"role": "assistant", "content": "はい"},
                            {"role": "user", "content": "渋谷"}]}
    # Act
    kwargs = _first_call(client, fake, history)
    # Assert
    assert kwargs["messages"] == history["messages"]


@pytest.mark.parametrize(("exc", "status", "code"), [
    (APITimeoutError(request=httpx.Request("POST", "https://api.anthropic.com")), 504, "AI_TIMEOUT"),
    (APIConnectionError(request=httpx.Request("POST", "https://api.anthropic.com")), 502, "AI_UPSTREAM_ERROR"),
])
def test_ai_chat_upstream_errors_map_to_gateway_status(client, fake, exc, status, code):
    # Arrange
    async def boom(**kwargs):
        raise exc
    fake.script[:] = [boom]
    # Act
    res = client.post("/api/ai/chat", json=USER_Q)
    # Assert
    assert res.status_code == status and res.json()["error"]["code"] == code
