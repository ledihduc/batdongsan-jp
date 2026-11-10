"""`/mcp`: 2 tool cố định, instructions cố định, guard Host/Origin, hạn mức, SKILL.md (Phase 07, AC6, AC11, AC17b)."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.ai_capabilities.fixed_skill import fixed_instructions, fixed_skill_markdown
from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from app.ai_capabilities.registry_store import RegistryStore
from app.config import settings
from app.mcp.rate_limit import McpRateLimiter
from app.services.jp_search.listing_search_service import JpListingFilters, search_listings
from tests.ai.ai_registry_test_utils import bump_mtime, make_action, write_registry
from tests.ai.mcp_test_client import build_mcp_test_app, mcp_initialize, mcp_rpc, mcp_tool
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture


@pytest.fixture(autouse=True)
def _mcp_settings(monkeypatch):
    monkeypatch.setattr(settings, "region", "jp")
    monkeypatch.setattr(settings, "mcp_allowed_hosts", ["testserver"])
    monkeypatch.setattr(settings, "mcp_allowed_origins", [])


@pytest.fixture()
def db():
    session = make_sqlite_session()
    yield session
    session.close()


@pytest.fixture()
def st(db):
    return seed_search_fixture(db)


@pytest.fixture(scope="module")
def reg():
    return load_registry(DEFAULT_REGISTRY_PATH)


@pytest.fixture()
def c(db, st, reg):
    with TestClient(build_mcp_test_app(db, lambda: reg)) as client:
        yield client


def _tool_annotations(client) -> dict:
    status, body = mcp_rpc(client, "tools/list", rpc_id=2)
    assert status == 200
    return {t["name"]: t["annotations"] for t in body["result"]["tools"]}


def test_mcp_initialize_returns_fixed_instructions(c):
    # Act
    res = mcp_initialize(c)
    # Assert
    assert res["result"]["instructions"] == fixed_instructions()
    assert res["result"]["capabilities"]["tools"]["listChanged"] is False


def test_mcp_tools_list_returns_two_fixed_tools(c):
    # Arrange
    mcp_initialize(c)
    # Act
    tools = _tool_annotations(c)
    # Assert
    assert list(tools) == ["get_system_skills", "run_action"]
    assert tools["get_system_skills"]["readOnlyHint"] is True
    assert tools["run_action"]["readOnlyHint"] is False and tools["run_action"]["destructiveHint"] is False


def test_mcp_get_system_skills_lang_en_lists_enabled_actions(c, reg):
    # Act
    is_error, payload = mcp_tool(c, "get_system_skills", {"lang": "en"})
    # Assert
    assert not is_error
    assert [a["name"] for a in payload["actions"]] == reg.names()
    assert [a["title"] for a in payload["actions"]] == [a.title["en"] for a in reg.actions]


def test_mcp_run_action_search_listings_matches_rest_search(c, db, st):
    # Arrange
    args = {"action": "search_listings", "params": {
        "station_id": st["shibuya_yamanote"], "max_walk_min": 10, "max_rent_jpy": 150000,
        "layouts": ["1LDK"], "limit": 10,
    }}
    # Act
    is_error, payload = mcp_tool(c, "run_action", args)
    rest = search_listings(db, JpListingFilters(
        layouts=("1LDK",), max_rent=150000, station_id=st["shibuya_yamanote"], max_walk_min=10, page_size=10,
    ))
    # Assert
    assert not is_error
    assert {i["listing_id"] for i in payload["items"]} == {i["listing_id"] for i in rest.items}
    assert rest.items  # bộ AC3 phải có tin khớp, không so 2 tập rỗng


def test_mcp_run_action_invalid_arguments_returns_is_error_result(c, st):
    # Act
    is_error, payload = mcp_tool(c, "run_action", {
        "action": "search_listings", "params": {"station_id": st["shibuya_yamanote"], "max_walk_min": "ten"},
    })
    # Assert
    assert is_error and payload["error"] == "invalid_arguments"


def test_mcp_run_action_unknown_action_returns_error_with_hint(c):
    # Act
    is_error, payload = mcp_tool(c, "run_action", {"action": "drop_db", "params": {}})
    # Assert
    assert is_error and payload["error"] == "unknown_action"
    assert "get_system_skills" in payload["hint"]


def test_mcp_unknown_tool_name_returns_error(c):
    # Act
    is_error, payload = mcp_tool(c, "search_listings", {"q": "x"})
    # Assert
    assert is_error and payload["error"] == "unknown_tool"


def test_mcp_unknown_host_header_returns_421(c):
    # Act
    status, _ = mcp_rpc(c, "tools/list", headers={"Host": "evil.example"})
    # Assert
    assert status == 421


def test_mcp_foreign_origin_header_returns_403(c):
    # Act
    status, _ = mcp_rpc(c, "tools/list", headers={"Origin": "https://evil.example"})
    # Assert
    assert status == 403


def test_mcp_total_rate_limit_exceeded_returns_429(db, reg):
    # Arrange
    limiter = McpRateLimiter(total_per_min=3, per_key_per_min=100)
    with TestClient(build_mcp_test_app(db, lambda: reg, limiter=limiter)) as client:
        # Act
        statuses = [mcp_rpc(client, "ping", rpc_id=i)[0] for i in range(4)]
        _, body = mcp_rpc(client, "ping", rpc_id=5)
    # Assert
    assert statuses == [200, 200, 200, 429]
    assert body["error"]["code"] == "RATE_LIMITED"


def test_mcp_per_action_rate_limit_exceeded_returns_tool_error(db, st, reg):
    # Arrange
    limiter = McpRateLimiter(total_per_min=100, per_key_per_min=1)
    args = {"action": "search_listings", "params": {"station_id": st["shibuya_yamanote"]}}
    with TestClient(build_mcp_test_app(db, lambda: reg, limiter=limiter)) as client:
        # Act
        first = mcp_tool(client, "run_action", args)
        second = mcp_tool(client, "run_action", args)
        other = mcp_tool(client, "get_system_skills", {})
    # Assert
    assert first[0] is False
    assert second[0] is True and second[1]["error"] == "rate_limited"
    assert other[0] is False  # khoá khác (get_system_skills) không bị gộp bucket


def test_mcp_vn_registry_same_tools_and_instructions(tmp_path, db):
    # Arrange
    reg_vn = load_registry(write_registry(tmp_path, [make_action()], market="vn", default_lang="vi"))
    with TestClient(build_mcp_test_app(db, lambda: reg_vn)) as client:
        # Act
        init = mcp_initialize(client)
        tools = _tool_annotations(client)
        is_error, skills = mcp_tool(client, "get_system_skills", {})
    # Assert
    assert init["result"]["instructions"] == fixed_instructions()
    assert list(tools) == ["get_system_skills", "run_action"]
    assert not is_error and skills["market"] == "vn" and skills["lang"] == "vi"


def test_mcp_registry_change_visible_without_restart(tmp_path, db):
    # Arrange
    path = write_registry(tmp_path, [make_action(name="a_one")])
    store = RegistryStore(path)
    with TestClient(build_mcp_test_app(db, store.current)) as client:
        _, before = mcp_tool(client, "get_system_skills", {})
        write_registry(tmp_path, [make_action(name="a_one"), make_action(name="a_two")])
        bump_mtime(path)
        # Act
        _, after = mcp_tool(client, "get_system_skills", {})
        tools = _tool_annotations(client)
    # Assert
    assert [a["name"] for a in before["actions"]] == ["a_one"]
    assert [a["name"] for a in after["actions"]] == ["a_one", "a_two"]
    assert after["registry_version"] != before["registry_version"]
    assert list(tools) == ["get_system_skills", "run_action"]


@pytest.mark.parametrize("method", ["GET", "DELETE"])
def test_mcp_non_post_method_returns_405_without_opening_stream(c, method):
    # Act — GET từng mở SSE treo mãi, không bị đếm hạn mức (QA M1)
    resp = c.request(method, "/mcp", headers={"Accept": "text/event-stream"})
    # Assert
    assert resp.status_code == 405
    assert resp.headers["allow"] == "POST"


def test_mcp_skill_markdown_served(c):
    # Act
    resp = c.get("/mcp/SKILL.md")
    # Assert
    assert resp.status_code == 200
    assert resp.text == fixed_skill_markdown()
    assert "text/markdown" in resp.headers["content-type"]
