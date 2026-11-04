"""Chạy một action của registry: validate tham số → luật login/write → handler (T3, D14).

Phase 05 chỉ chạy action `read` + handler python; action `write` bị chặn tới P09
(pending + xác nhận). Lỗi luôn là `ActionError(code, message)` ngắn, không stack trace.
"""

from __future__ import annotations

import json
from typing import Callable, ContextManager, Optional

from jsonschema import Draft202012Validator
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.loader import Action, Registry
from app.database import SessionLocal

SessionScope = Callable[[], ContextManager[Session]]


class ActionError(Exception):
    """code ∈ unknown_action | invalid_arguments | not_found | login_required |
    confirmation_unavailable | upstream_error | rate_limited."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message


def validate_params(action: Action, params: Optional[dict]) -> dict:
    params = {} if params is None else params
    if not isinstance(params, dict):
        raise ActionError("invalid_arguments", "params must be an object")
    error = next(iter(Draft202012Validator(action.params).iter_errors(params)), None)
    if error is not None:
        where = "/".join(str(p) for p in error.absolute_path) or "params"
        raise ActionError("invalid_arguments", f"{where}: {error.message}"[:300])
    return params


def run_action(
    registry: Registry, name: str, params: Optional[dict], ctx: ActionContext,
    *, session_scope: SessionScope = SessionLocal,
) -> dict:
    action = registry.get(name)
    if action is None:
        raise ActionError("unknown_action", f"unknown action: {str(name)[:64]}")
    params = validate_params(action, params)
    if action.mode == "write":
        raise ActionError("confirmation_unavailable", "write actions require user confirmation (not available yet)")
    if action.requires_login and ctx.user is None:
        raise ActionError("login_required", "this action requires login")
    if action.func is None:  # handler rest (P06)
        raise ActionError("upstream_error", "handler not available")
    try:
        with session_scope() as db:
            result = action.func(db, params, ctx)
    except KeyError:  # lỗi lập trình, không phải "không thấy" ⇒ upstream_error ở call_fixed_tool (QA M5)
        raise
    except LookupError as exc:
        raise ActionError("not_found", str(exc) or "not found") from exc
    except ValueError as exc:
        raise ActionError("invalid_arguments", str(exc)[:300] or "invalid arguments") from exc
    if not isinstance(result, dict):
        raise ActionError("upstream_error", "handler returned no object")
    return result


async def run_action_async(
    registry: Registry, name: str, params: Optional[dict], ctx: ActionContext,
    *, session_scope: SessionScope = SessionLocal,
) -> dict:
    # Handler + Session đồng bộ ⇒ chạy trong threadpool để không chặn event loop.
    return await run_in_threadpool(run_action, registry, name, params, ctx, session_scope=session_scope)


def encode_tool_result(result: dict) -> str:
    """JSON giữ nguyên tiếng Nhật; nội dung tin luôn nằm trong chuỗi JSON (X8)."""
    return json.dumps(result, ensure_ascii=False, separators=(",", ":"))
