"""AC9 tự động: thêm/tắt action rest trong registry ⇒ MCP và chat cùng thấy, không restart (Phase 08)."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.ai_capabilities.registry_store import RegistryStore
from tests.ai.ai_registry_test_utils import bump_mtime, make_rest_action, packaged_registry_dict, write_registry
from tests.ai.chat_test_app import build_chat_test_app, chat_env, fake  # noqa: F401 — fixture
from tests.ai.fake_anthropic import fake_text
from tests.ai.mcp_test_client import build_mcp_test_app, mcp_rpc, mcp_tool
from tests.jp.search.jp_search_fixtures import make_sqlite_session

FIND_STATION_PARAMS = {"type": "object", "additionalProperties": False, "required": ["q"],
                       "properties": {"q": {"type": "string", "minLength": 1, "maxLength": 40}}}


@pytest.fixture()
def db():
    session = make_sqlite_session()
    yield session
    session.close()


def _seen_by_mcp_and_chat(db, fake, store: RegistryStore) -> tuple[list[str], int, str]:
    with TestClient(build_mcp_test_app(db, store.current)) as c:
        _, skills = mcp_tool(c, "get_system_skills", {})
        _, tools = mcp_rpc(c, "tools/list", rpc_id=2)
    fake.script[:] = [fake_text("はい")]
    res = TestClient(build_chat_test_app(db, fake, store.current)).post(
        "/api/ai/chat", json={"messages": [{"role": "user", "content": "駅"}]})
    assert res.status_code == 200
    return [a["name"] for a in skills["actions"]], len(tools["result"]["tools"]), fake.messages.calls[-1]["system"][1]["text"]


def test_ai_registry_rest_action_added_visible_in_mcp_and_chat(tmp_path, db, fake):
    # Arrange
    find_station = make_rest_action("GET", "/api/jp/stations/search", name="find_station", params=FIND_STATION_PARAMS)
    base = packaged_registry_dict()["actions"]
    path = write_registry(tmp_path, base)
    store = RegistryStore(path)
    names_before, _, chat_before = _seen_by_mcp_and_chat(db, fake, store)
    # Act
    write_registry(tmp_path, [*base, find_station])
    bump_mtime(path)
    names_after, n_tools, chat_after = _seen_by_mcp_and_chat(db, fake, store)
    # Assert
    assert "find_station" not in names_before and "find_station" not in chat_before
    assert "find_station" in names_after and n_tools == 2
    assert "find_station" in chat_after


def test_ai_registry_disabled_action_hidden_in_mcp_and_chat(tmp_path, db, fake):
    # Arrange
    find_station = make_rest_action("GET", "/api/jp/stations/search", name="find_station", params=FIND_STATION_PARAMS)
    base = packaged_registry_dict()["actions"]
    path = write_registry(tmp_path, [*base, find_station])
    store = RegistryStore(path)
    assert "find_station" in _seen_by_mcp_and_chat(db, fake, store)[0]
    # Act
    write_registry(tmp_path, [*base, {**find_station, "enabled": False}])
    bump_mtime(path)
    names, n_tools, chat_text = _seen_by_mcp_and_chat(db, fake, store)
    # Assert
    assert "find_station" not in names and n_tools == 2
    assert "find_station" not in chat_text
