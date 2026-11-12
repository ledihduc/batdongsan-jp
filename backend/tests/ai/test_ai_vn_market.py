"""Bản vn qua MCP / xác nhận / chat: cùng connector, chức năng theo thị trường, chỉ tin VN (Phase 13, AC17, AC18)."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from tests.ai.write_test_utils import WRITE_TABLES, bearer, build_actions_test_app, make_user
from tests.vn.vn_fixtures import seed_vn_fixture

from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, PACKAGED_REGISTRY_DIR, load_registry
from app.config import settings
from app.domain.ai_pending_action import AiPendingAction
from app.middleware.rate_limit import limiter
from app.models import House, Wishlist
from app.services.jp.demo_seed import seed_jp_demo
from tests.ai.chat_test_app import build_chat_test_app
from tests.ai.fake_anthropic import FakeAnthropic, fake_text, fake_tool_use
from tests.ai.mcp_test_client import build_mcp_test_app, mcp_initialize, mcp_rpc, mcp_tool
from tests.jp.search.jp_search_fixtures import _ac3_listing, make_sqlite_session, seed_station_fixture

AC17D = {"location": "Quận 1", "max_price_vnd": 20000000, "min_bedrooms": 2}
VN_REG = load_registry(PACKAGED_REGISTRY_DIR / "registry.vn.yaml")


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.setattr(settings, "region", "vn")
    monkeypatch.setattr(settings, "default_tz", "Asia/Ho_Chi_Minh")
    monkeypatch.setattr(settings, "anthropic_api_key", "test-key")
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
    return seed_vn_fixture(db)


@pytest.fixture()
def jp_id(db, ids):
    seed_station_fixture(db)
    seed_jp_demo(db, [_ac3_listing("[JP-1] 渋谷 1LDK", 120000, "1LDK", [(1130201, 5)])])
    return db.query(House).filter(House.title.startswith("[JP-1]")).one().id


@pytest.fixture()
def c(db, ids):
    with TestClient(build_actions_test_app(db, lambda: VN_REG)) as client:
        yield client


def _token(c, listing_id: int) -> str:
    is_error, out = mcp_tool(c, "run_action", {"action": "save_favorite", "params": {"listing_id": listing_id}})
    assert not is_error and out["status"] == "confirmation_required", out
    return out["confirm_url"].rsplit("/", 1)[1]


def test_ai_vn_mcp_initialize_instructions_same_as_jp(db):
    # Arrange
    jp_reg = load_registry(DEFAULT_REGISTRY_PATH)
    # Act
    with TestClient(build_mcp_test_app(db, lambda: VN_REG)) as vn_client:
        vn_init = mcp_initialize(vn_client)
        _, vn_tools = mcp_rpc(vn_client, "tools/list", rpc_id=2)
    with TestClient(build_mcp_test_app(db, lambda: jp_reg)) as jp_client:
        jp_init = mcp_initialize(jp_client)
        _, jp_tools = mcp_rpc(jp_client, "tools/list", rpc_id=2)
    # Assert
    assert vn_init["result"]["instructions"] == jp_init["result"]["instructions"]
    names = [t["name"] for t in vn_tools["result"]["tools"]]
    assert names == [t["name"] for t in jp_tools["result"]["tools"]] == ["get_system_skills", "run_action"]


def test_ai_vn_mcp_get_system_skills_returns_vn_market(c):
    # Act
    is_error, out = mcp_tool(c, "get_system_skills", {})
    # Assert
    assert not is_error and out["market"] == "vn" and out["default_lang"] == "vi"
    assert [a["name"] for a in out["actions"]] == ["search_listings", "get_listing", "save_favorite"]


def test_ai_vn_mcp_search_q1_only_vn_matches(c, ids, jp_id):
    # Act
    is_error, out = mcp_tool(c, "run_action", {"action": "search_listings", "params": AC17D})
    # Assert
    got = {i["listing_id"] for i in out["items"]}
    assert not is_error and got == {ids["[Q1-OK1]"], ids["[Q1-OK2]"]} and jp_id not in got


def test_ai_vn_mcp_request_viewing_is_unknown_action(c, ids):
    # Act
    is_error, out = mcp_tool(c, "run_action", {"action": "request_viewing", "params": {"listing_id": ids["[Q1-OK1]"]}})
    # Assert
    assert is_error and "unknown_action" in str(out)


def test_ai_vn_mcp_save_favorite_confirm_creates_one_wishlist(c, db, ids):
    # Arrange
    token = _token(c, ids["[Q1-OK1]"])
    assert db.query(Wishlist).count() == 0
    uid = make_user(db)
    # Act
    res = c.post(f"/api/ai/actions/{token}/confirm", headers=bearer(uid))
    # Assert
    assert res.status_code == 200 and res.json()["status"] == "executed"
    assert db.query(Wishlist).filter_by(user_id=uid, house_id=ids["[Q1-OK1]"]).count() == 1


def test_ai_vn_mcp_save_favorite_jp_listing_rejected(c, db, jp_id):
    # Act
    is_error, _ = mcp_tool(c, "run_action", {"action": "save_favorite", "params": {"listing_id": jp_id}})
    # Assert
    assert is_error
    assert db.query(Wishlist).count() == 0 and db.query(AiPendingAction).count() == 0


def test_ai_vn_preview_listing_currency_vnd(c, ids):
    # Arrange
    token = _token(c, ids["[Q1-OK1]"])
    # Act
    res = c.get(f"/api/ai/actions/{token}", params={"lang": "vi"})
    # Assert
    body = res.json()
    assert res.status_code == 200 and body["title"] == "Lưu vào yêu thích"
    assert body["listing"]["currency"] == "VND" and body["listing"]["price"] == 15000000
    assert body["listing"]["layout"] is None


def _chat(db, script: list, payload: dict) -> tuple[dict, FakeAnthropic]:
    fake = FakeAnthropic(script)
    res = TestClient(build_chat_test_app(db, fake, lambda: VN_REG)).post("/api/ai/chat", json=payload)
    assert res.status_code == 200, res.text
    return res.json(), fake


def test_ai_chat_vn_search_returns_vn_cards(db, ids):
    # Act
    body, _ = _chat(db, [
        fake_tool_use("run_action", {"action": "search_listings", "params": AC17D}, "tu1"),
        fake_text("Có 2 căn phù hợp."),
    ], {"messages": [{"role": "user", "content": "Căn hộ 2 phòng ngủ Quận 1 dưới 20 triệu"}], "lang": "vi"})
    # Assert
    assert body["reply"] == "Có 2 căn phù hợp."
    assert {c["listing_id"] for c in body["listings"]} == {ids["[Q1-OK1]"], ids["[Q1-OK2]"]}
    assert {c["currency"] for c in body["listings"]} == {"VND"}


def test_ai_chat_vn_get_listing_card_keeps_vnd_price(db, ids):
    # Arrange — payload get_listing bản vn đã phẳng (không rental_terms) ⇒ thẻ phải giữ giá VND
    lid = ids["[Q1-OK2]"]
    # Act
    body, _ = _chat(db, [
        fake_tool_use("run_action", {"action": "get_listing", "params": {"listing_id": lid}}, "tu1"),
        fake_text(f"Chi tiết tin [#{lid}]."),
    ], {"messages": [{"role": "user", "content": "Cho xem chi tiết"}], "lang": "vi"})
    # Assert
    card = body["listings"][0]
    assert (card["listing_id"], card["price"], card["currency"]) == (lid, 20000000, "VND")


def test_ai_chat_vn_no_lang_uses_default_vi(db, ids):
    # Act
    _, fake = _chat(db, [fake_text("Xin chào")], {"messages": [{"role": "user", "content": "xin chào"}]})
    # Assert
    assert "Tìm nhà" in fake.messages.calls[0]["system"][1]["text"]
