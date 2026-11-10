"""Hồi quy phase 06 — đóng các đột biến sống trong tester-261104-phase-06 (S2–S4, L4/L5/L9, R2–R24, C1–C3)."""

from __future__ import annotations

import asyncio
import os

import pytest
from fastapi import FastAPI, Request
from fastapi.responses import PlainTextResponse

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.ai_capabilities.action_runner import ActionError, run_action
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.loader import HandlerSpec, RegistryError, get_registry, load_registry
from app.ai_capabilities.registry_store import RegistryStore, get_registry_store
from app.ai_capabilities.rest_handler import call_rest, parse_rest_whitelist
from app.config import settings
from tests.ai.ai_registry_test_utils import bump_mtime, make_action, make_rest_action, write_registry

app = FastAPI()


@app.get("/api/t/names/{name}")
async def _name(name: str):
    return {"name": name}


@app.get("/api/t/secret")
async def _secret():
    return {"secret": True}


@app.get("/api/t/query")
async def _query(request: Request):
    return dict(request.query_params)


@app.post("/api/t/body/{item_id}")
async def _body(item_id: int, request: Request):
    return {"item_id": item_id, "body": await request.json()}


@app.get("/api/t/slow")
async def _slow():
    await asyncio.sleep(1)
    return {}


@app.get("/api/t/boom")
async def _boom():
    raise RuntimeError("internal")


@app.get("/api/t/shape/{kind}")
async def _shape(kind: str):
    return {"big": ["x" * 1000] * 60, "text": PlainTextResponse("hi"), "scalar": 5}[kind]


WL = parse_rest_whitelist(["get /api/t/names/{name}", "GET /api/t/query", "POST /api/t/body/{item_id}",
                           "GET /api/t/slow", "GET /api/t/boom", "GET /api/t/shape/{kind}",
                           "GET /api/ai/chat", "GET /health"])
CTX = ActionContext(channel="chat", asgi_app=app)


async def _call(method: str, path: str, params: dict, ctx: ActionContext = CTX, timeout_s: float = 5):
    return await call_rest(HandlerSpec("rest", method=method, path=path), params, ctx, timeout_s=timeout_s, whitelist=WL)


async def _code(*args, **kwargs) -> str:
    with pytest.raises(ActionError) as exc:
        await _call(*args, **kwargs)
    return exc.value.code


# --- store (S2–S4, L9) ---

@pytest.mark.parametrize("broken", [False, True])
def test_ai_registry_store_after_change_parses_once(tmp_path, broken):
    # Arrange (S2: sau khi đổi/hỏng không được parse lại mỗi lần gọi)
    calls = []
    path = write_registry(tmp_path, [make_action(name="a_one")])
    store = RegistryStore(path, loader=lambda p: calls.append(p) or load_registry(p))
    if broken:
        path.write_text("version: 9\n", encoding="utf-8")
    else:
        write_registry(tmp_path, [make_action(name="a_two")])
    bump_mtime(path)
    # Act
    for _ in range(3):
        store.current()
    # Assert
    assert len(calls) == 2


def test_ai_registry_store_same_size_edit_reloads(tmp_path):
    # Arrange (S4: chỉ mtime đổi, size giữ nguyên)
    path = write_registry(tmp_path, [make_action(name="a_one")])
    store = RegistryStore(path)
    write_registry(tmp_path, [make_action(name="a_two")])
    bump_mtime(path)
    # Act / Assert
    assert store.current().names() == ["a_two"]


def test_ai_registry_store_size_change_same_mtime_reloads(tmp_path):
    # Arrange (S3: mtime bị giữ nguyên, size đổi)
    path = write_registry(tmp_path, [make_action(name="a_one")])
    st = os.stat(path)
    store = RegistryStore(path)
    write_registry(tmp_path, [make_action(name="a_longer_name")])
    os.utime(path, ns=(st.st_atime_ns, st.st_mtime_ns))
    # Act / Assert
    assert store.current().names() == ["a_longer_name"]


def test_ai_get_registry_hot_reloads_through_public_entry(tmp_path, monkeypatch):
    # Arrange (L9: main.py + fixed tools đi qua get_registry())
    path = write_registry(tmp_path, [make_action(name="a_one")])
    monkeypatch.setattr(settings, "ai_registry_dir", str(tmp_path))
    monkeypatch.setattr(settings, "region", "jp")
    get_registry_store.cache_clear()
    try:
        assert get_registry().names() == ["a_one"]
        write_registry(tmp_path, [make_action(name="a_one"), make_action(name="a_two")])
        bump_mtime(path)
        # Act / Assert
        assert get_registry().names() == ["a_one", "a_two"]
    finally:
        get_registry_store.cache_clear()


# --- loader rest (L4/L5, C1–C3) ---

@pytest.mark.parametrize("params", [
    {"type": "object", "properties": {"name": {"type": "string"}}},
    {"type": "object", "required": ["name"], "properties": {}},
])
def test_ai_registry_loader_rest_path_param_needs_property_and_required(tmp_path, params):
    # Act / Assert
    with pytest.raises(RegistryError, match="name"):
        load_registry(write_registry(tmp_path, [make_rest_action("GET", "/api/t/names/{name}", params=params)]),
                      rest_whitelist=WL)


@pytest.mark.parametrize("handler", [
    {"type": "rest", "method": "GET", "path": "/health"},
    {"type": "rest", "method": "TRACE", "path": "/api/t/query"},
    {"type": "rest", "method": "GET"},
    {"type": "rest", "method": "GET", "path": "/api/t/query", "target": "x:y"},
])
def test_ai_registry_loader_rest_bad_handler_shape_raises(tmp_path, handler):
    # Act / Assert
    with pytest.raises(RegistryError):
        load_registry(write_registry(tmp_path, [make_action(handler=handler)]), rest_whitelist=WL)


# --- call_rest (R2–R24) ---

async def test_ai_rest_handler_path_param_traversal_is_escaped():
    # Act (R6: "../secret" không được thành /api/t/secret)
    code = await _code("GET", "/api/t/names/{name}", {"name": "../secret"})
    # Assert
    assert code == "not_found"


async def test_ai_rest_handler_path_param_unicode_and_space_roundtrip():
    # Act
    out = await _call("GET", "/api/t/names/{name}", {"name": "渋谷 駅"})
    # Assert
    assert out == {"name": "渋谷 駅"}


async def test_ai_rest_handler_query_encodes_bool_and_drops_none():
    # Act (R13, R14)
    out = await _call("GET", "/api/t/query", {"flag": True, "off": False, "gone": None, "n": 3})
    # Assert
    assert out == {"flag": "true", "off": "false", "n": "3"}


async def test_ai_rest_handler_post_sends_json_body_without_path_params():
    # Act (R18–R21; whitelist ghi "get" thường ⇒ parse phải upper)
    out = await _call("POST", "/api/t/body/{item_id}", {"item_id": 4, "note": "x"})
    # Assert
    assert out == {"item_id": 4, "body": {"note": "x"}}


@pytest.mark.parametrize("path", ["/api/ai/chat", "/health"])
async def test_ai_rest_handler_call_time_path_recheck(path):
    # Act / Assert (R2, R3: whitelist lỡ chứa path cấm vẫn bị chặn lúc gọi)
    assert await _code("GET", path, {}) == "endpoint_not_allowed"


async def test_ai_rest_handler_timeout_maps_upstream_error():
    # Act / Assert (R15)
    assert await _code("GET", "/api/t/slow", {}, timeout_s=0.05) == "upstream_error"


@pytest.mark.parametrize("path,params", [("/api/t/boom", {}), ("/api/t/shape/{kind}", {"kind": "big"}),
                                         ("/api/t/shape/{kind}", {"kind": "text"}),
                                         ("/api/t/shape/{kind}", {"kind": "scalar"})])
async def test_ai_rest_handler_bad_upstream_maps_upstream_error(path, params):
    # Act / Assert (R16 app exception, R11 >50 KB, R23 không JSON, R24 không phải object)
    assert await _code("GET", path, params) == "upstream_error"


async def test_ai_rest_handler_without_app_raises_upstream_error():
    # Act / Assert (R17)
    assert await _code("GET", "/api/t/query", {}, ctx=ActionContext(channel="mcp")) == "upstream_error"


def test_ai_run_action_sync_rest_action_is_async_only(tmp_path):
    # Arrange (A2)
    reg = load_registry(write_registry(tmp_path, [make_rest_action("GET", "/api/t/query", params={"type": "object"})]),
                        rest_whitelist=WL)
    # Act / Assert
    with pytest.raises(ActionError, match="async-only"):
        run_action(reg, "find_station", {}, CTX)
