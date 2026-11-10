"""Đúng 2 tool cố định cho mọi kênh AI: `get_system_skills`, `run_action` (X2, K6).

MCP (P07) và chat (P08) cùng gọi `call_fixed_tool` — một đường code. Tool không
bao giờ đổi; thay đổi nằm trong kết quả `get_system_skills` (kèm `registry_version`).
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone, tzinfo
from typing import Optional
from zoneinfo import ZoneInfo

from jsonschema import Draft202012Validator

from app.ai_capabilities.action_runner import ActionError, SessionScope, run_action_async
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.loader import Registry
from app.ai_capabilities.system_skills import render_system_skills
from app.config import settings
from app.database import SessionLocal

logger = logging.getLogger(__name__)

GET_SYSTEM_SKILLS = "get_system_skills"
RUN_ACTION = "run_action"

FIXED_TOOLS: tuple[dict, ...] = (
    {
        "name": GET_SYSTEM_SKILLS,
        "title": "Get system skills",
        "description": "Return the market, default_lang, guide and available actions (JSON Schema params). "
                       "Call first, with lang = the user's language code.",
        "input_schema": {
            "type": "object",
            "additionalProperties": False,
            "properties": {"lang": {"type": "string", "maxLength": 64, "description": "ja, vi, en…"}},
        },
        "read_only": True,
    },
    {
        "name": RUN_ACTION,
        "title": "Run action",
        "description": "Run one action listed by get_system_skills with params matching its schema.",
        "input_schema": {
            "type": "object",
            "additionalProperties": False,
            "required": ["action"],
            "properties": {
                "action": {"type": "string", "minLength": 1, "maxLength": 64},
                "params": {"type": "object"},
            },
        },
        "read_only": False,
    },
)
_VALIDATORS = {t["name"]: Draft202012Validator(t["input_schema"]) for t in FIXED_TOOLS}


def local_tz() -> tzinfo:
    """Múi giờ `settings.default_tz`; tên sai ⇒ UTC + cảnh báo (chat P08 dùng chung)."""
    try:
        return ZoneInfo(settings.default_tz)
    except (ValueError, KeyError):  # ZoneInfoNotFoundError là KeyError (QA M2)
        logger.warning("ai_bad_default_tz", extra={"event": "ai_bad_default_tz", "tz": settings.default_tz})
        return timezone.utc


def _now_local() -> str:
    return datetime.now(local_tz()).isoformat(timespec="seconds")


def _log_action(registry: Registry, ctx: ActionContext, action: str, outcome: str) -> None:
    logger.info("ai_action", extra={
        "event": "ai_action", "action": action[:64], "outcome": outcome, "channel": ctx.channel,
        "user_sub": (ctx.user or {}).get("sub"), "registry_version": registry.version,
    })


def _error(code: str, message: str) -> tuple[bool, dict]:
    payload = {"error": code, "message": message}
    if code in ("unknown_action", "invalid_arguments"):
        payload["hint"] = "call get_system_skills again"
    return True, payload


async def call_fixed_tool(
    registry: Registry, tool_name: str, arguments: Optional[dict], ctx: ActionContext,
    *, session_scope: SessionScope = SessionLocal,
) -> tuple[bool, dict]:
    """Trả `(is_error, payload)`; không bao giờ ném ra ngoài (kênh gọi chỉ việc encode)."""
    validator = _VALIDATORS.get(tool_name)
    if validator is None:
        return _error("unknown_tool", f"unknown tool: {str(tool_name)[:64]}")
    arguments = arguments or {}
    if not isinstance(arguments, dict):
        return _error("invalid_arguments", "arguments must be an object")
    error = next(iter(validator.iter_errors(arguments)), None)
    if error is not None:
        return _error("invalid_arguments", error.message[:300])
    if tool_name == GET_SYSTEM_SKILLS:
        payload = render_system_skills(registry, arguments.get("lang"))
        # Giờ địa phương để model tính ngày giờ (P09 hẹn xem nhà).
        payload["now_local"] = _now_local()
        return False, payload
    try:
        result = await run_action_async(
            registry, arguments["action"], arguments.get("params"), ctx, session_scope=session_scope,
        )
    except ActionError as exc:
        _log_action(registry, ctx, arguments["action"], exc.code)
        return _error(exc.code, exc.message)
    except Exception:  # noqa: BLE001 — không lộ stack trace/SQL cho model
        logger.exception("ai_action_failed", extra={"event": "ai_action_failed", "action": arguments["action"][:64]})
        _log_action(registry, ctx, arguments["action"], "upstream_error")
        return _error("upstream_error", "action failed")
    _log_action(registry, ctx, arguments["action"], "ok")
    return False, result
