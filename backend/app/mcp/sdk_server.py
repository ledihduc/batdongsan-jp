"""Nhánh A (MCP_BRANCH = A, spike Phase 02): SDK `mcp` 2.3.0 low-level `Server`, stateless + JSON.

Mỗi lần gọi dựng một `Server` + ASGI mới: `session_manager.run()` chỉ chạy được 1 lần mỗi
instance (review spike 261028), nên `mount.py` gọi hàm này trong startup, không lúc import.
"""

from __future__ import annotations

from typing import Any, Callable, ContextManager

from mcp.server import Server
from mcp.server.transport_security import TransportSecuritySettings
from mcp.types import CallToolResult, ListToolsResult, TextContent, Tool, ToolAnnotations
from sqlalchemy.orm import Session

from app.ai_capabilities.fixed_skill import fixed_instructions
from app.ai_capabilities.loader import Registry
from app.mcp.rate_limit import McpRateLimiter
from app.mcp.tool_bridge import call_tool, list_tool_specs

SERVER_NAME = "batdongsan-jp"
SERVER_VERSION = "0.2.0"


def _sdk_tools() -> list[Tool]:
    return [
        Tool(
            name=spec["name"], title=spec["title"], description=spec["description"],
            input_schema=spec["inputSchema"],
            annotations=ToolAnnotations(
                read_only_hint=spec["annotations"]["readOnlyHint"],
                destructive_hint=spec["annotations"]["destructiveHint"],
                open_world_hint=spec["annotations"]["openWorldHint"],
            ),
        )
        for spec in list_tool_specs()
    ]


def build_sdk_asgi_app(
    app: Any, registry_provider: Callable[[], Registry], limiter: McpRateLimiter,
    *, allowed_hosts: list[str], allowed_origins: list[str],
    session_scope: Callable[[], ContextManager[Session]],
) -> tuple[Any, Any]:
    """Trả `(asgi_app, session_manager)`; caller phải giữ `session_manager.run()` suốt vòng đời."""
    tools = _sdk_tools()

    async def on_list_tools(ctx, params) -> ListToolsResult:  # noqa: ARG001 — chữ ký SDK
        return ListToolsResult(tools=tools)

    async def on_call_tool(ctx, params) -> CallToolResult:  # noqa: ARG001 — chữ ký SDK
        is_error, text = await call_tool(
            registry_provider, limiter, params.name, params.arguments,
            asgi_app=app, session_scope=session_scope,
        )
        return CallToolResult(content=[TextContent(type="text", text=text)], is_error=is_error)

    server = Server(
        SERVER_NAME, version=SERVER_VERSION, instructions=fixed_instructions(),
        on_list_tools=on_list_tools, on_call_tool=on_call_tool,
    )
    asgi = server.streamable_http_app(
        stateless_http=True, json_response=True,
        transport_security=TransportSecuritySettings(
            allowed_hosts=list(allowed_hosts), allowed_origins=list(allowed_origins),
        ),
    )
    return asgi, server.session_manager
