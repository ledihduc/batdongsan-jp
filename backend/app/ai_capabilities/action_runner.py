"""Chạy một action của registry: validate tham số → luật login/write → handler (T3, D14).

Handler python chạy trong threadpool; handler rest (P06) gọi in-process qua ASGI và
chỉ chạy được ở bản async. Action `write` không ghi: handler chạy dry-run để kiểm rồi tạo
pending, người dùng xác nhận mới ghi (P09, confirm_service).
Lỗi luôn là `ActionError(code, message)` ngắn, không stack trace.
"""

from __future__ import annotations

import json
from dataclasses import replace
from datetime import timezone
from typing import Callable, ContextManager, Optional

from jsonschema import Draft202012Validator
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.ai_capabilities.action_errors import ActionError
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.loader import Action, Registry
from app.ai_capabilities.rest_handler import call_rest
from app.config import settings
from app.database import SessionLocal

__all__ = ["ActionError", "SessionScope", "call_python_handler", "encode_tool_result", "run_action", "run_action_async",
           "validate_params"]

SessionScope = Callable[[], ContextManager[Session]]


def validate_params(action: Action, params: Optional[dict]) -> dict:
    params = {} if params is None else params
    if not isinstance(params, dict):
        raise ActionError("invalid_arguments", "params must be an object")
    error = next(iter(Draft202012Validator(action.params).iter_errors(params)), None)
    if error is not None:
        where = "/".join(str(p) for p in error.absolute_path) or "params"
        raise ActionError("invalid_arguments", f"{where}: {error.message}"[:300])
    return params


def _prepare(registry: Registry, name: str, params: Optional[dict], ctx: ActionContext) -> tuple[Action, dict]:
    """Luật chung mọi loại handler: action có thật → params hợp lệ → write bị chặn → login."""
    action = registry.get(name)
    if action is None:
        raise ActionError("unknown_action", f"unknown action: {str(name)[:64]}")
    params = validate_params(action, params)
    if action.mode == "write":
        # Chat biết người dùng ⇒ khách phải đăng nhập trước. MCP không có user ⇒ vẫn tạo pending;
        # đăng nhập được kiểm lúc xác nhận (require_user của người bấm, F-3).
        if ctx.channel == "chat" and ctx.user is None:
            raise ActionError("login_required", "this action requires login")
        return action, params
    if action.requires_login and ctx.user is None:
        raise ActionError("login_required", "this action requires login")
    return action, params


def run_action(
    registry: Registry, name: str, params: Optional[dict], ctx: ActionContext,
    *, session_scope: SessionScope = SessionLocal,
) -> dict:
    action, params = _prepare(registry, name, params, ctx)
    if action.mode == "write":
        return _create_pending(action, params, ctx, session_scope)
    if action.handler.type == "rest":
        raise ActionError("upstream_error", "rest handler is async-only")
    return _run_python(action, params, ctx, session_scope)


def call_python_handler(action: Action, db: Session, params: dict, ctx: ActionContext) -> dict:
    """Gọi handler python + đổi lỗi thành ActionError (dùng chung runner và confirm_service)."""
    if action.func is None:
        raise ActionError("upstream_error", "handler not available")
    try:
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


def _run_python(action: Action, params: dict, ctx: ActionContext, session_scope: SessionScope) -> dict:
    with session_scope() as db:
        return call_python_handler(action, db, params, ctx)


def _create_pending(action: Action, params: dict, ctx: ActionContext, session_scope: SessionScope) -> dict:
    """Dry-run handler (báo lỗi tham số/slot sớm cho AI) rồi tạo pending; không ghi dữ liệu nghiệp vụ."""
    from app.services.ai_actions.pending_store import create_pending  # noqa: PLC0415 — tránh vòng import

    if action.handler.type != "python":
        raise ActionError("upstream_error", "write actions support python handlers only")
    with session_scope() as db:
        call_python_handler(action, db, params, replace(ctx, dry_run=True))
        created = create_pending(db, action, params, ctx)
    out = {"status": "confirmation_required", "action": action.name, "params": params,
           "expires_at": created.expires_at.replace(tzinfo=timezone.utc).isoformat()}
    if ctx.channel == "chat":
        out["pending_token"] = created.token  # chat_service tách ra thẻ, không gửi model (F-6)
    else:
        out["confirm_url"] = created.confirm_url
    return out


async def run_action_async(
    registry: Registry, name: str, params: Optional[dict], ctx: ActionContext,
    *, session_scope: SessionScope = SessionLocal,
) -> dict:
    action, params = _prepare(registry, name, params, ctx)
    if action.mode == "write":
        return await run_in_threadpool(_create_pending, action, params, ctx, session_scope)
    if action.handler.type == "rest":
        return await call_rest(action.handler, params, ctx, timeout_s=settings.ai_rest_timeout_s)
    # Handler + Session đồng bộ ⇒ chạy trong threadpool để không chặn event loop.
    return await run_in_threadpool(_run_python, action, params, ctx, session_scope)


def encode_tool_result(result: dict) -> str:
    """JSON giữ nguyên tiếng Nhật; nội dung tin luôn nằm trong chuỗi JSON (X8)."""
    return json.dumps(result, ensure_ascii=False, separators=(",", ":"))
