"""tool_bridge.call_tool: lỗi ngoài `call_fixed_tool` vẫn thành kết quả isError (Phase 07, F-3, QA M2)."""

from __future__ import annotations

import asyncio
import json
from decimal import Decimal

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.mcp import tool_bridge
from app.mcp.rate_limit import McpRateLimiter
from app.mcp.tool_bridge import call_tool, rate_key


def _limiter() -> McpRateLimiter:
    return McpRateLimiter(total_per_min=100, per_key_per_min=100)


def test_mcp_tool_bridge_unserializable_payload_returns_upstream_error(monkeypatch):
    # Arrange — handler trả Decimal (vd houses.price Numeric ở bản vn)
    async def fake_call_fixed_tool(*args, **kwargs):
        return False, {"price": Decimal("1.5")}
    monkeypatch.setattr(tool_bridge, "call_fixed_tool", fake_call_fixed_tool)
    # Act
    is_error, text = asyncio.run(call_tool(lambda: object(), _limiter(), "get_system_skills", {}, asgi_app=None))
    # Assert
    payload = json.loads(text)
    assert is_error is True and payload["error"] == "upstream_error"
    assert "Decimal" not in text  # không lộ chi tiết exception


def test_mcp_tool_bridge_registry_provider_failure_returns_upstream_error():
    # Arrange
    def broken_provider():
        raise RuntimeError("registry exploded /srv/secret/path")
    # Act
    is_error, text = asyncio.run(call_tool(broken_provider, _limiter(), "get_system_skills", {}, asgi_app=None))
    # Assert
    assert is_error is True and json.loads(text)["error"] == "upstream_error"
    assert "secret" not in text


def test_mcp_tool_bridge_rate_key_buckets():
    # Act / Assert
    assert rate_key("get_system_skills", {"lang": "en"}) == "get_system_skills"
    assert rate_key("run_action", {"action": "search_listings"}) == "run_action:search_listings"
    assert rate_key("run_action", {}) == "run_action:?"
    assert rate_key("run_action", None) == "run_action:?"
    assert rate_key("search_listings", {}) == "?"
