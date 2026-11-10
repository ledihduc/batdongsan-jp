"""Hồi quy QA 261104 phase 06 (M1 path sau khi thay giá trị, M2 chi tiết 422, M3 429, L4 whitelist sai dạng)."""

from __future__ import annotations

import pytest
from fastapi import FastAPI, HTTPException

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.ai_capabilities.action_runner import ActionError
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.loader import HandlerSpec
from app.ai_capabilities.rest_handler import call_rest, parse_rest_whitelist

app = FastAPI()


@app.get("/api/{seg}/chat")
async def _chat(seg: str):
    return {"seg": seg}


@app.get("/api/q/names/{name}")
async def _name(name: str):
    return {"name": name}


@app.get("/api/q/count")
async def _count(n: int):
    return {"n": n}


@app.get("/api/q/limited")
async def _limited():
    raise HTTPException(status_code=429, detail="slow down")


WL = parse_rest_whitelist(["GET /api/{seg}/chat", "GET /api/q/names/{name}", "GET /api/q/count", "GET /api/q/limited"])
CTX = ActionContext(channel="chat", asgi_app=app)


async def _error(path: str, params: dict) -> ActionError:
    with pytest.raises(ActionError) as exc:
        await call_rest(HandlerSpec("rest", method="GET", path=path), params, CTX, timeout_s=5, whitelist=WL)
    return exc.value


async def test_ai_rest_handler_resolved_path_into_ai_namespace_rejected():
    # Act (M1: template hợp lệ nhưng giá trị "ai" đưa path vào /api/ai/)
    err = await _error("/api/{seg}/chat", {"seg": "ai"})
    # Assert
    assert err.code == "endpoint_not_allowed"


@pytest.mark.parametrize("value", ["..", ".", ""])
async def test_ai_rest_handler_dot_segment_path_value_rejected(value):
    # Act (M1: quote() để nguyên "." / "..")
    err = await _error("/api/q/names/{name}", {"name": value})
    # Assert
    assert err.code == "invalid_arguments"


async def test_ai_rest_handler_422_detail_message_is_forwarded_truncated():
    # Act (M2)
    err = await _error("/api/q/count", {"n": "abc"})
    # Assert
    assert err.code == "invalid_arguments" and err.message.startswith("upstream status 422: n")
    assert len(err.message) <= 300


async def test_ai_rest_handler_status_429_maps_rate_limited():
    # Act (M3)
    err = await _error("/api/q/limited", {})
    # Assert
    assert err.code == "rate_limited"


@pytest.mark.parametrize("entry", ["GET", "GET api/x", " "])
def test_ai_rest_whitelist_malformed_entry_raises(entry):
    # Act / Assert (L4: trước đây ra ("GET", "") im lặng)
    with pytest.raises(ValueError):
        parse_rest_whitelist([entry])
