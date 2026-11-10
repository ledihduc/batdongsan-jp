"""Helper gọi `/mcp` trong test (plan 20261027-1102 Phase 07; Phase 08 dùng lại cho AC9)."""

from __future__ import annotations

import json
from contextlib import nullcontext
from typing import Callable, Optional

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from fastapi import FastAPI

from app.ai_capabilities.loader import Registry
from app.mcp.mount import mount_mcp
from app.mcp.rate_limit import McpRateLimiter

MCP_HEADERS = {
    "Accept": "application/json, text/event-stream",
    "Content-Type": "application/json",
    "MCP-Protocol-Version": "2025-06-18",
}


def _decode_body(resp) -> dict:
    """JSON thường, hoặc dòng `data:` cuối của SSE (phòng khi SDK trả stream).
    Body chữ thường (SDK trả 421/403 dạng text) ⇒ `{}`; test kiểm bằng status."""
    if "text/event-stream" in resp.headers.get("content-type", ""):
        data = [line[5:].strip() for line in resp.text.splitlines() if line.startswith("data:")]
        return json.loads(data[-1]) if data else {}
    if "application/json" not in resp.headers.get("content-type", ""):
        return {}
    return resp.json() if resp.content else {}


def mcp_rpc(client, method: str, params: Optional[dict] = None, rpc_id: int = 1,
            headers: Optional[dict] = None) -> tuple[int, dict]:
    body = {"jsonrpc": "2.0", "id": rpc_id, "method": method}
    if params is not None:
        body["params"] = params
    resp = client.post("/mcp", json=body, headers={**MCP_HEADERS, **(headers or {})})
    return resp.status_code, _decode_body(resp)


def mcp_initialize(client) -> dict:
    _, body = mcp_rpc(client, "initialize", {
        "protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "pytest", "version": "0"},
    })
    return body


def mcp_tool(client, name: str, arguments: dict, rpc_id: int = 9) -> tuple[bool, dict]:
    """`tools/call` ⇒ `(isError, payload)` với payload = JSON trong `content[0].text`."""
    _, body = mcp_rpc(client, "tools/call", {"name": name, "arguments": arguments}, rpc_id=rpc_id)
    result = body["result"]
    return bool(result.get("isError")), json.loads(result["content"][0]["text"])


def build_mcp_test_app(db, registry_provider: Callable[[], Registry],
                       limiter: Optional[McpRateLimiter] = None) -> FastAPI:
    """FastAPI trần + `/mcp`; session DB là SQLite của test (dùng trong `with TestClient(app)`)."""
    app = FastAPI()
    mount_mcp(app, registry_provider=registry_provider, limiter=limiter,
              session_scope=lambda: nullcontext(db))
    return app
