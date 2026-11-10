"""Handler `rest`: gọi in-process qua ASGITransport, chuyển tiếp Authorization, map mã lỗi (Phase 06, AC15)."""

from __future__ import annotations

import pytest
from fastapi import FastAPI, HTTPException, Request

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.ai_capabilities.action_runner import ActionError
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.fixed_tools import call_fixed_tool
from app.ai_capabilities.loader import HandlerSpec, load_registry
from app.ai_capabilities.rest_handler import call_rest, parse_rest_whitelist
from app.api.routes.jp.listings import router as jp_listings_router
from app.config import settings
from app.database import get_db
from tests.ai.ai_registry_test_utils import make_rest_action, write_registry
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_station_fixture

echo_app = FastAPI()


@echo_app.get("/api/test/echo")
async def _echo(request: Request):
    q = request.query_params
    return {"auth": request.headers.get("authorization"), "q": q.get("q"), "layouts": q.get("layouts")}


@echo_app.get("/api/test/items/{item_id}")
async def _item(item_id: int):
    return {"item_id": item_id}


@echo_app.get("/api/test/status/{code}")
async def _status(code: int):
    raise HTTPException(status_code=code, detail="x")


WL_TEST = parse_rest_whitelist(["GET /api/test/echo", "GET /api/test/items/{item_id}", "GET /api/test/status/{code}"])
CTX = ActionContext(channel="chat", asgi_app=echo_app)


def _spec(path: str) -> HandlerSpec:
    return HandlerSpec("rest", method="GET", path=path)


@pytest.fixture()
def stations_app(monkeypatch):
    monkeypatch.setattr(settings, "region", "jp")
    db = make_sqlite_session()
    seed_station_fixture(db)
    app = FastAPI()
    app.include_router(jp_listings_router)
    app.dependency_overrides[get_db] = lambda: db
    yield app
    db.close()


async def test_ai_rest_handler_forwards_authorization_header():
    # Arrange
    ctx = ActionContext(channel="chat", authorization="Bearer t1", asgi_app=echo_app)
    # Act
    out = await call_rest(_spec("/api/test/echo"), {"q": "渋谷", "layouts": ["1K", "1LDK"]}, ctx,
                          timeout_s=5, whitelist=WL_TEST)
    # Assert
    assert out == {"auth": "Bearer t1", "q": "渋谷", "layouts": "1K,1LDK"}


async def test_ai_rest_handler_path_param_substituted():
    # Act
    out = await call_rest(_spec("/api/test/items/{item_id}"), {"item_id": 7}, CTX, timeout_s=5, whitelist=WL_TEST)
    # Assert
    assert out["item_id"] == 7


@pytest.mark.parametrize(("status", "code"), [(401, "login_required"), (403, "login_required"),
                                              (404, "not_found"), (422, "invalid_arguments"),
                                              (500, "upstream_error")])
async def test_ai_rest_handler_status_maps_error_code(status, code):
    # Act / Assert
    with pytest.raises(ActionError) as exc:
        await call_rest(_spec("/api/test/status/{code}"), {"code": status}, CTX, timeout_s=5, whitelist=WL_TEST)
    assert exc.value.code == code


async def test_ai_rest_handler_not_whitelisted_raises_endpoint_not_allowed():
    # Act / Assert
    with pytest.raises(ActionError) as exc:
        await call_rest(_spec("/api/test/secret"), {}, CTX, timeout_s=5, whitelist=WL_TEST)
    assert exc.value.code == "endpoint_not_allowed"


async def test_ai_rest_handler_real_stations_route_returns_items(stations_app):
    # Arrange: whitelist mặc định của settings (không truyền whitelist)
    ctx = ActionContext(channel="mcp", asgi_app=stations_app)
    # Act
    out = await call_rest(HandlerSpec("rest", method="GET", path="/api/jp/stations/search"), {"q": "渋谷"},
                          ctx, timeout_s=5)
    # Assert
    assert out["items"][0]["name_ja"] == "渋谷"


async def test_ai_fixed_tools_run_action_rest_action_runs_in_process(tmp_path, stations_app):
    # Arrange
    reg = load_registry(write_registry(tmp_path, [make_rest_action("GET", "/api/jp/stations/search")]))
    ctx = ActionContext(channel="chat", asgi_app=stations_app)
    # Act
    is_error, payload = await call_fixed_tool(reg, "run_action", {"action": "find_station", "params": {"q": "渋谷"}}, ctx)
    # Assert
    assert is_error is False and payload["items"][0]["name_ja"] == "渋谷"
