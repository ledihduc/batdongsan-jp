"""2 tool cố định get_system_skills / run_action — một đường code cho MCP và chat (X2, K6 — Phase 05)."""

from __future__ import annotations

import asyncio
from contextlib import nullcontext

import pytest

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.fixed_tools import FIXED_TOOLS, call_fixed_tool
from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from app.config import settings
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture

CTX = ActionContext(channel="mcp")


@pytest.fixture()
def scope():
    db = make_sqlite_session()
    seed_search_fixture(db)
    yield lambda: nullcontext(db)
    db.close()


@pytest.fixture(scope="module")
def reg():
    return load_registry(DEFAULT_REGISTRY_PATH)


def _call(reg, tool, args, scope):
    return asyncio.run(call_fixed_tool(reg, tool, args, CTX, session_scope=scope))


def test_ai_fixed_tools_exactly_two_tools_with_read_only_flags():
    # Act / Assert
    assert [(t["name"], t["read_only"]) for t in FIXED_TOOLS] == [("get_system_skills", True), ("run_action", False)]
    assert all(t["input_schema"]["type"] == "object" for t in FIXED_TOOLS)


def test_ai_fixed_tools_get_system_skills_returns_actions(reg, scope, monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "default_tz", "Asia/Tokyo")
    # Act
    is_error, payload = _call(reg, "get_system_skills", {"lang": "en"}, scope)
    # Assert
    assert is_error is False and payload["lang"] == "en"
    assert [a["name"] for a in payload["actions"]] == reg.names()
    assert payload["now_local"].endswith("+09:00")


def test_ai_fixed_tools_run_action_returns_payload(reg, scope):
    # Act
    is_error, payload = _call(reg, "run_action", {"action": "search_stations", "params": {"q": "渋谷"}}, scope)
    # Assert
    assert is_error is False and payload["stations"]


def test_ai_fixed_tools_run_action_unknown_action_returns_error_with_hint(reg, scope):
    # Act
    is_error, payload = _call(reg, "run_action", {"action": "drop_db"}, scope)
    # Assert
    assert is_error is True and payload["error"] == "unknown_action"
    assert payload["hint"] == "call get_system_skills again"


def test_ai_fixed_tools_run_action_missing_action_returns_error(reg, scope):
    # Act
    is_error, payload = _call(reg, "run_action", {}, scope)
    # Assert
    assert is_error is True and payload["error"] == "invalid_arguments" and payload["message"]


def test_ai_fixed_tools_unknown_tool_name_returns_error(reg, scope):
    # Act
    is_error, payload = _call(reg, "drop_db", {}, scope)
    # Assert
    assert is_error is True and payload["error"] == "unknown_tool"
