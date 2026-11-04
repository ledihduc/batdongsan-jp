"""Hồi quy cho QA 261104 phase 05 (H1, M1–M5, Low repr) — mỗi test bắt lại đúng lỗi gốc."""

from __future__ import annotations

import asyncio
from contextlib import nullcontext

import pytest

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

import app.services.jp_search.ai_tools as ai_tools
from app.ai_capabilities.action_runner import ActionError, run_action
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.fixed_tools import call_fixed_tool
from app.ai_capabilities.loader import (
    DEFAULT_REGISTRY_PATH,
    RegistryError,
    ai_enabled_for_region,
    get_registry,
    load_registry,
)
from app.config import settings
from tests.ai.ai_registry_test_utils import make_action, write_registry
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


@pytest.mark.parametrize("blank", ["駅", " ", "　"])
def test_ai_search_listings_blank_station_name_returns_invalid_arguments(reg, scope, blank):
    # Act (H1: trước đây bỏ lọc ga, trả tin bất kỳ)
    with pytest.raises(ActionError) as exc:
        run_action(reg, "search_listings", {"station_name": blank}, CTX, session_scope=scope)
    # Assert
    assert exc.value.code == "invalid_arguments"


def test_ai_search_listings_unknown_station_returns_hint(reg, scope):
    # Act (H1: romaji không khớp ga ⇒ gợi ý dùng search_stations)
    out = run_action(reg, "search_listings", {"station_name": "Shibuya"}, CTX, session_scope=scope)
    # Assert
    assert out["total"] == 0 and "search_stations" in out["hint"]


@pytest.mark.parametrize(("raw", "lang"), [("ja-JP", "ja"), ("vi_VN", "vi"), ("vn", "vi"),
                                           ("ja-JP,en;q=0.9", "ja"), ("  ", "ja")])
def test_ai_get_system_skills_locale_tags_normalized(reg, scope, raw, lang):
    # Act (M1)
    is_error, payload = _call(reg, "get_system_skills", {"lang": raw}, scope)
    # Assert
    assert is_error is False and payload["lang"] == lang


def test_ai_get_system_skills_bad_default_tz_does_not_raise(reg, scope, monkeypatch):
    # Arrange (M2)
    monkeypatch.setattr(settings, "default_tz", "Mars/Olympus")
    # Act
    is_error, payload = _call(reg, "get_system_skills", {}, scope)
    # Assert
    assert is_error is False and payload["now_local"].endswith("+00:00")


def test_ai_get_registry_market_mismatch_with_region_raises(tmp_path, monkeypatch):
    # Arrange (M3: file vn đặt nhầm tên registry.jp.yaml)
    path = write_registry(tmp_path, [make_action()], market="vn", default_lang="vi")
    path.rename(tmp_path / "registry.jp.yaml")
    monkeypatch.setattr(settings, "ai_registry_dir", str(tmp_path))
    monkeypatch.setattr(settings, "region", "jp")
    get_registry.cache_clear()
    # Act / Assert
    try:
        with pytest.raises(RegistryError, match="REGION"):
            get_registry()
    finally:
        get_registry.cache_clear()


def test_ai_registry_loader_empty_actions_raises(tmp_path):
    # Act / Assert (M3)
    with pytest.raises(RegistryError):
        load_registry(write_registry(tmp_path, []))


def test_ai_registry_loader_async_handler_raises(tmp_path, monkeypatch):
    # Arrange (M4: coroutine bị trả về như payload thành công)
    async def tool_async_probe(db, args, ctx):
        return {}

    monkeypatch.setattr(ai_tools, "tool_async_probe", tool_async_probe, raising=False)
    target = "app.services.jp_search.ai_tools:tool_async_probe"
    # Act / Assert
    with pytest.raises(RegistryError, match="đồng bộ"):
        load_registry(write_registry(tmp_path, [make_action(handler={"type": "python", "target": target})]))


@pytest.mark.parametrize(("behaviour", "code"), [("keyerror", "upstream_error"), ("nondict", "upstream_error")])
def test_ai_run_action_handler_bug_returns_generic_upstream_error(tmp_path, monkeypatch, scope, behaviour, code):
    # Arrange (M4 non-dict, M5 KeyError lộ text nội bộ dưới dạng not_found)
    def tool_buggy_probe(db, args, ctx):
        if behaviour == "keyerror":
            raise KeyError("internal_column_name")
        return ["not", "a", "dict"]

    monkeypatch.setattr(ai_tools, "tool_buggy_probe", tool_buggy_probe, raising=False)
    target = "app.services.jp_search.ai_tools:tool_buggy_probe"
    reg = load_registry(write_registry(tmp_path, [make_action(handler={"type": "python", "target": target})]))
    # Act
    is_error, payload = _call(reg, "run_action", {"action": "find_station", "params": {"q": "x"}}, scope)
    # Assert
    assert is_error is True and payload["error"] == code
    assert "internal_column_name" not in payload["message"]


def test_ai_action_context_repr_hides_bearer_token():
    # Act (Low: log ctx không được lộ token)
    text = repr(ActionContext(channel="chat", authorization="Bearer secret-token-xyz"))
    # Assert
    assert "secret-token-xyz" not in text


def test_ai_registry_get_registry_broken_file_fails_fast(tmp_path, monkeypatch):
    # Arrange: đúng chuỗi gọi của main.py (ai_enabled_for_region → get_registry) — AC5, tester G3 (chuyển từ test loader)
    write_registry(tmp_path, [make_action(handler={"type": "python", "target": "os:system"})])
    monkeypatch.setattr(settings, "ai_registry_dir", str(tmp_path))
    monkeypatch.setattr(settings, "region", "jp")
    get_registry.cache_clear()
    # Act / Assert
    try:
        assert ai_enabled_for_region(settings.region) is True
        with pytest.raises(RegistryError, match="whitelist"):
            get_registry()
    finally:
        get_registry.cache_clear()


def test_ai_registry_loader_action_name_with_trailing_newline_raises(tmp_path):
    # Act / Assert (code review L-1: pattern `$` cho lọt "find_station\n")
    with pytest.raises(RegistryError):
        load_registry(write_registry(tmp_path, [make_action(name="find_station\n")]))


def test_ai_fixed_tools_run_action_logs_outcome_without_params(reg, scope, caplog):
    # Act (code review M-1: mỗi lần gọi có 1 dòng log, không chứa giá trị params)
    with caplog.at_level("INFO", logger="app.ai_capabilities.fixed_tools"):
        _call(reg, "run_action", {"action": "search_stations", "params": {"q": "secret-probe"}}, scope)
    # Assert
    rec = next(r for r in caplog.records if r.getMessage() == "ai_action")
    assert rec.outcome == "ok" and rec.channel == "mcp" and rec.registry_version == reg.version
    assert "secret-probe" not in caplog.text
