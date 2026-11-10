"""Gắn `/mcp` + `/mcp/SKILL.md` vào FastAPI (Phase 07, PD2, D17, T8).

`Route("/mcp", endpoint=<ASGI>)` giữ nguyên đường `/mcp` (không 307). SDK kiểm Host (421) và
Origin (403); guard ở đây chỉ đếm hạn mức tổng cho mọi POST (429). Server SDK dựng trong
startup và đóng ở shutdown — mỗi vòng đời app một instance (spike 261028, M1).
"""

from __future__ import annotations

from contextlib import AsyncExitStack
from typing import Any, Callable, ContextManager, Optional

from fastapi import FastAPI
from sqlalchemy.orm import Session
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.routing import Route

from app.ai_capabilities.fixed_skill import fixed_skill_markdown
from app.ai_capabilities.loader import Registry, get_registry
from app.config import settings
from app.database import SessionLocal
from app.mcp.rate_limit import McpRateLimiter
from app.mcp.sdk_server import build_sdk_asgi_app


class _McpRuntime:
    """ASGI SDK đang chạy của vòng đời hiện tại (None khi app chưa startup / đã shutdown)."""

    def __init__(self) -> None:
        self.asgi: Optional[Any] = None
        self.stack: Optional[AsyncExitStack] = None


class McpGuardASGI:
    def __init__(self, runtime: _McpRuntime, limiter: McpRateLimiter) -> None:
        self._runtime = runtime
        self._limiter = limiter

    async def __call__(self, scope, receive, send) -> None:
        # Stateless chỉ cần POST; GET của SDK mở SSE treo mãi mà không bị đếm hạn mức (QA M1).
        if scope["type"] == "http" and scope["method"] != "POST":
            await JSONResponse(
                {"error": {"code": "METHOD_NOT_ALLOWED", "message": "use POST"}},
                status_code=405, headers={"Allow": "POST"},
            )(scope, receive, send)
            return
        if scope["type"] == "http" and not self._limiter.allow_request():
            response = JSONResponse(
                {"error": {"code": "RATE_LIMITED", "message": "too many MCP requests"}}, status_code=429,
            )
            await response(scope, receive, send)
            return
        if self._runtime.asgi is None:
            await JSONResponse(
                {"error": {"code": "MCP_UNAVAILABLE", "message": "MCP server not started"}}, status_code=503,
            )(scope, receive, send)
            return
        await self._runtime.asgi(scope, receive, send)


async def _skill_markdown(request: Request) -> Response:  # noqa: ARG001 — chữ ký Starlette
    return Response(fixed_skill_markdown(), media_type="text/markdown; charset=utf-8")


def mount_mcp(
    app: FastAPI, *, registry_provider: Callable[[], Registry] = get_registry,
    limiter: Optional[McpRateLimiter] = None,
    session_scope: Callable[[], ContextManager[Session]] = SessionLocal,
) -> None:
    limiter = limiter or McpRateLimiter(
        settings.mcp_rate_limit_total_per_min, settings.mcp_rate_limit_per_action_per_min,
    )
    runtime = _McpRuntime()

    async def _start_mcp() -> None:
        # Đọc settings lúc startup (không lúc import) ⇒ test monkeypatch allowlist được.
        asgi, session_manager = build_sdk_asgi_app(
            app, registry_provider, limiter,
            allowed_hosts=settings.mcp_allowed_hosts, allowed_origins=settings.mcp_allowed_origins,
            session_scope=session_scope,
        )
        stack = AsyncExitStack()
        await stack.enter_async_context(session_manager.run())
        runtime.asgi, runtime.stack = asgi, stack

    async def _stop_mcp() -> None:
        stack, runtime.asgi, runtime.stack = runtime.stack, None, None
        if stack is not None:
            await stack.aclose()

    app.add_event_handler("startup", _start_mcp)
    app.add_event_handler("shutdown", _stop_mcp)
    app.router.routes.append(Route("/mcp/SKILL.md", endpoint=_skill_markdown, methods=["GET"]))
    app.router.routes.append(Route("/mcp", endpoint=McpGuardASGI(runtime, limiter)))
