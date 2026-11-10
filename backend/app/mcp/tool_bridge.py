"""Cầu giữa giao thức MCP và 2 tool cố định của `app.ai_capabilities` (Phase 07).

Không phụ thuộc SDK: `sdk_server` chỉ đổi kiểu dữ liệu. Registry lấy MỖI lần gọi từ
`registry_provider` (bản nạp nóng P06), nên chức năng mới hiện ra mà danh sách tool không đổi.
"""

from __future__ import annotations

import logging
from typing import Any, Callable, ContextManager, Optional

from sqlalchemy.orm import Session

from app.ai_capabilities.action_runner import encode_tool_result
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.fixed_tools import FIXED_TOOLS, GET_SYSTEM_SKILLS, RUN_ACTION, call_fixed_tool
from app.ai_capabilities.loader import Registry
from app.database import SessionLocal
from app.mcp.rate_limit import McpRateLimiter

logger = logging.getLogger(__name__)

_MAX_KEY_ACTION_LEN = 64
_UPSTREAM_ERROR = {"error": "upstream_error", "message": "tool failed"}


def list_tool_specs() -> list[dict]:
    """Spec tool theo tên trường MCP (camelCase), thứ tự cố định như `FIXED_TOOLS`."""
    return [
        {
            "name": t["name"],
            "title": t["title"],
            "description": t["description"],
            "inputSchema": t["input_schema"],
            "annotations": {"readOnlyHint": t["read_only"], "destructiveHint": False, "openWorldHint": False},
        }
        for t in FIXED_TOOLS
    ]


def _action_name(tool_name: str, arguments: Optional[dict]) -> Optional[str]:
    if tool_name != RUN_ACTION or not isinstance(arguments, dict):
        return None
    action = arguments.get("action")
    return action[:_MAX_KEY_ACTION_LEN] if isinstance(action, str) and action else None


def rate_key(tool_name: str, arguments: Optional[dict]) -> str:
    """Khoá hạn mức: `get_system_skills` | `run_action:<action>` | `run_action:?` (2 tool cố định
    nên đếm theo tool sẽ gộp mọi action vào 1 bucket). Tên tool lạ đi chung bucket `?`."""
    if tool_name == GET_SYSTEM_SKILLS:
        return GET_SYSTEM_SKILLS
    if tool_name == RUN_ACTION:
        return f"{RUN_ACTION}:{_action_name(tool_name, arguments) or '?'}"
    return "?"


async def call_tool(
    registry_provider: Callable[[], Registry], limiter: McpRateLimiter, name: str, arguments: Optional[dict],
    *, asgi_app: Any, session_scope: Callable[[], ContextManager[Session]] = SessionLocal,
) -> tuple[bool, str]:
    """`(is_error, text)` — text là JSON payload; lỗi action thành kết quả `isError`, không ném (F-3)."""
    if not limiter.allow_key(rate_key(name, arguments)):
        is_error, payload = True, {"error": "rate_limited", "message": "too many calls"}
    else:
        ctx = ActionContext(channel="mcp", asgi_app=asgi_app)
        try:
            is_error, payload = await call_fixed_tool(
                registry_provider(), name, arguments, ctx, session_scope=session_scope,
            )
        except Exception:  # noqa: BLE001 — registry_provider hỏng: không lộ exception cho client (QA M2)
            logger.exception("mcp_tool_call_failed", extra={"event": "mcp_tool_call_failed", "tool": str(name)[:64]})
            is_error, payload = True, _UPSTREAM_ERROR
    try:
        text = encode_tool_result(payload)
    except (TypeError, ValueError):  # handler trả kiểu không ra JSON (Decimal, date…) — QA M2
        logger.exception("mcp_tool_result_unencodable", extra={"event": "mcp_tool_result_unencodable"})
        is_error, payload = True, _UPSTREAM_ERROR
        text = encode_tool_result(payload)
    # NF-1: không log tham số.
    logger.info("mcp_tool_call", extra={
        "event": "mcp_tool_call", "tool": str(name)[:64], "action": _action_name(name, arguments),
        "is_error": is_error, "error": payload.get("error") if is_error else None,
    })
    return is_error, text
