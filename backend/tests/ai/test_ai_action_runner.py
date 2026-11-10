"""run_action: validate tham số, luật login/write, handler jp_search (T3, T5, K4 — Phase 05)."""

from __future__ import annotations

import json
from contextlib import nullcontext

import pytest

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.ai_capabilities.action_runner import ActionError, encode_tool_result, run_action
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from app.config import settings
from app.domain.ai_pending_action import AiPendingAction
from app.models import House, Wishlist
from app.services.ai_actions.pending_store import hash_token
from tests.ai.ai_registry_test_utils import make_action, write_registry
from tests.ai.write_test_utils import WRITE_TABLES
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture

CTX = ActionContext(channel="mcp")


@pytest.fixture()
def db():
    session = make_sqlite_session()
    yield session
    session.close()


@pytest.fixture()
def ids(db) -> dict[str, int]:
    return seed_search_fixture(db)


@pytest.fixture()
def scope(db):
    return lambda: nullcontext(db)


@pytest.fixture()
def wdb():
    session = make_sqlite_session(extra_tables=WRITE_TABLES)
    yield session
    session.close()


@pytest.fixture()
def wids(wdb) -> dict[str, int]:
    return seed_search_fixture(wdb)


@pytest.fixture()
def wscope(wdb):
    return lambda: nullcontext(wdb)


@pytest.fixture(scope="module")
def reg():
    return load_registry(DEFAULT_REGISTRY_PATH)


def _code(excinfo) -> str:
    return excinfo.value.code


def test_ai_action_runner_search_listings_shibuya_returns_matching_ids(reg, ids, scope):
    # Act
    out = run_action(reg, "search_listings", {
        "station_name": "渋谷", "max_walk_min": 10, "max_rent_jpy": 150000, "layouts": ["1LDK"], "limit": 10,
    }, CTX, session_scope=scope)
    # Assert
    assert {i["listing_id"] for i in out["items"]} == {ids["[SBY-OK1]"], ids["[SBY-OK2]"], ids["[SBY-OK3]"]}
    assert out["total"] == 3 and out["note"]


def test_ai_action_runner_search_listings_default_limit_is_five(reg, ids, scope):
    # Act (jsonschema không áp default ⇒ handler tự đặt)
    out = run_action(reg, "search_listings", {}, CTX, session_scope=scope)
    # Assert
    assert len(out["items"]) == 5 and out["total"] == 7


def test_ai_action_runner_invalid_arguments_raises_action_error(reg, ids, scope):
    # Act
    with pytest.raises(ActionError) as exc:
        run_action(reg, "search_listings", {"max_walk_min": "ten"}, CTX, session_scope=scope)
    # Assert
    assert _code(exc) == "invalid_arguments"


def test_ai_action_runner_extra_argument_raises_action_error(reg, ids, scope):
    # Act
    with pytest.raises(ActionError) as exc:
        run_action(reg, "search_listings", {"pets": True}, CTX, session_scope=scope)
    # Assert
    assert _code(exc) == "invalid_arguments"


def test_ai_action_runner_unknown_action_raises_action_error(reg, scope):
    # Act
    with pytest.raises(ActionError) as exc:
        run_action(reg, "drop_db", {}, CTX, session_scope=scope)
    # Assert
    assert _code(exc) == "unknown_action"


def test_ai_action_runner_get_listing_truncates_description_and_omits_address(reg, db, ids, scope):
    # Arrange
    house = db.get(House, ids["[SBY-OK1]"])
    house.description = "あ" * 3000
    db.commit()
    # Act
    out = run_action(reg, "get_listing", {"listing_id": house.id}, CTX, session_scope=scope)
    # Assert
    assert len(out["description"]) <= 1500 and "address" not in out
    assert out["listing_id"] == house.id and out["rental_terms"]["monthly_rent"] == 120000


def test_ai_action_runner_get_listing_unknown_id_raises_not_found(reg, ids, scope):
    # Act
    with pytest.raises(ActionError) as exc:
        run_action(reg, "get_listing", {"listing_id": 999999}, CTX, session_scope=scope)
    # Assert
    assert _code(exc) == "not_found"


def test_ai_action_runner_login_required_read_without_user_raises(tmp_path, ids, scope):
    # Arrange
    reg = load_registry(write_registry(tmp_path, [make_action(requires_login=True)]))
    # Act
    with pytest.raises(ActionError) as exc:
        run_action(reg, "find_station", {"q": "渋谷"}, CTX, session_scope=scope)
    # Assert
    assert _code(exc) == "login_required"


def test_ai_action_runner_login_required_read_with_user_runs(tmp_path, ids, scope):
    # Arrange
    reg = load_registry(write_registry(tmp_path, [make_action(requires_login=True)]))
    ctx = ActionContext(channel="chat", user={"sub": 1, "role": "guest"})
    # Act
    out = run_action(reg, "find_station", {"q": "渋谷"}, ctx, session_scope=scope)
    # Assert
    assert out["stations"]


def test_ai_action_runner_write_action_creates_pending_not_executed(wdb, wids, wscope):
    # Arrange — MCP không có user: vẫn tạo pending, người bấm xác nhận phải đăng nhập (P09 F-3)
    reg = load_registry(DEFAULT_REGISTRY_PATH)
    # Act
    out = run_action(reg, "save_favorite", {"listing_id": wids["[SBY-OK1]"]}, ActionContext(channel="mcp"),
                     session_scope=wscope)
    # Assert
    assert out["status"] == "confirmation_required" and out["action"] == "save_favorite"
    assert out["confirm_url"].startswith(settings.ai_confirm_base_url + "/ai-confirm/")
    pending = wdb.query(AiPendingAction).one()
    assert wdb.query(Wishlist).count() == 0 and pending.status == "pending" and pending.owner_user_id is None
    assert pending.token_sha256 == hash_token(out["confirm_url"].rsplit("/", 1)[1])


def test_ai_action_runner_write_action_chat_guest_raises_login_required(wdb, wids, wscope):
    # Arrange
    reg = load_registry(DEFAULT_REGISTRY_PATH)
    # Act
    with pytest.raises(ActionError) as exc:
        run_action(reg, "save_favorite", {"listing_id": wids["[SBY-OK1]"]}, ActionContext(channel="chat"),
                   session_scope=wscope)
    # Assert
    assert _code(exc) == "login_required" and wdb.query(AiPendingAction).count() == 0


def test_ai_tool_result_encoding_keeps_japanese_and_escapes_quotes():
    # Act
    encoded = encode_tool_result({"d": '渋谷"x"'})
    # Assert
    assert "渋谷" in encoded and json.loads(encoded) == {"d": '渋谷"x"'}
