"""Xem trước + xác nhận pending action (Phase 09, F-4, F-5, K13).

Xác nhận: kiểm theo thứ tự 404 → 403 → 409 → 410 (hết hạn / action không còn) → validate lại
theo registry HIỆN TẠI → claim 1 lần bằng UPDATE có điều kiện → chạy handler dưới danh tính
người bấm, cùng transaction. Handler từ chối ⇒ rollback cả claim, ghi `failed` ở transaction mới.

Toàn bộ là hàm ĐỒNG BỘ, route gọi trong threadpool (QA C1): UPDATE claim giữ row lock tới commit;
nếu chạy trên event loop, request thứ 2 cùng token chờ lock sẽ chặn cả loop ⇒ request 1 không commit được.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import update
from sqlalchemy.orm import Session
from app.ai_capabilities.action_runner import ActionError, call_python_handler, validate_params
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.loader import Action, Registry
from app.ai_capabilities.system_skills import normalize_lang, pick_text
from app.domain.ai_pending_action import AiPendingAction
from app.services.ai_actions.listing_brief import listing_brief
from app.services.ai_actions.pending_store import PendingError, get_pending, utcnow

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class _Checked:
    row: AiPendingAction
    action: Action


def _check(db: Session, registry: Registry, token: str, now: datetime, user_id: Optional[int]) -> _Checked:
    row = get_pending(db, token)
    if row is None:
        raise PendingError("not_found", 404)
    if user_id is not None and row.owner_user_id is not None and row.owner_user_id != user_id:
        raise PendingError("forbidden", 403)
    if row.status != "pending":
        raise PendingError("used", 409)
    if row.expires_at <= now:
        raise PendingError("expired", 410)
    action = registry.get(row.action)
    # Pending chỉ tạo được cho handler python (action_runner._create_pending) ⇒ rest = registry đã đổi.
    if action is None or action.mode != "write" or action.handler.type != "python":
        raise PendingError("action_unavailable", 410)
    return _Checked(row=row, action=action)


def preview_pending(db: Session, registry: Registry, token: str, *, lang: Optional[str] = None,
                    now: Optional[datetime] = None) -> dict:
    """Không ghi gì. `lang` thiếu ⇒ `registry.default_lang`."""
    checked = _check(db, registry, token, now or utcnow(), user_id=None)
    lang = normalize_lang(lang) or registry.default_lang
    row, action = checked.row, checked.action
    params = row.params or {}
    return {
        "action": row.action,
        "title": pick_text(action.title, lang, registry.default_lang),
        "description": pick_text(action.description, lang, registry.default_lang),
        "params": params,
        "listing": listing_brief(db, params.get("listing_id")),
        "status": row.status,
        "expires_at": row.expires_at.replace(tzinfo=timezone.utc),  # naive UTC ⇒ có offset như thẻ chat (QA M2)
        "owner_bound": row.owner_user_id is not None,
    }


def _mark_failed(db: Session, row_id: int, action: str, code: str, user_id: int) -> None:
    db.execute(update(AiPendingAction).where(AiPendingAction.id == row_id, AiPendingAction.status == "pending")
               .values(status="failed", error_code=code[:40], executed_by_user_id=user_id, executed_at=utcnow()))
    db.commit()
    logger.info("ai_action_failed", extra={"event": "ai_action_failed", "action": action, "pending_id": row_id,
                                           "user_id": user_id, "error_code": code})


def confirm_pending(db: Session, registry: Registry, token: str, claims: dict, *,
                    authorization: Optional[str], now: Optional[datetime] = None) -> dict:
    now = now or utcnow()
    user_id = int(claims["sub"])
    checked = _check(db, registry, token, now, user_id=user_id)
    row_id, action = checked.row.id, checked.action
    try:
        params = validate_params(action, checked.row.params)
    except ActionError as exc:
        _mark_failed(db, row_id, action.name, exc.code, user_id)
        raise PendingError(exc.code, 422) from exc
    claimed = db.execute(
        update(AiPendingAction)
        .where(AiPendingAction.id == row_id, AiPendingAction.status == "pending", AiPendingAction.expires_at > now)
        .values(status="executed", executed_by_user_id=user_id, executed_at=now)
    )
    if claimed.rowcount != 1:  # bấm 2 lần đồng thời / vừa hết hạn
        db.rollback()
        raise PendingError("used", 409)
    ctx = ActionContext(channel="confirm", user=claims, authorization=authorization)
    try:
        result = call_python_handler(action, db, params, ctx)
    except ActionError as exc:
        db.rollback()
        _mark_failed(db, row_id, action.name, exc.code, user_id)
        raise PendingError(exc.code, 422) from exc
    except Exception:  # noqa: BLE001 — không lộ chi tiết; claim đã rollback
        logger.exception("ai_action_confirm_crashed", extra={"event": "ai_action_failed", "pending_id": row_id})
        db.rollback()
        _mark_failed(db, row_id, action.name, "upstream_error", user_id)
        raise PendingError("upstream_error", 502) from None
    db.execute(update(AiPendingAction).where(AiPendingAction.id == row_id).values(result=result))
    db.commit()
    logger.info("ai_action_executed", extra={"event": "ai_action_executed", "action": action.name,
                                             "pending_id": row_id, "user_id": user_id})
    return {"status": "executed", "action": action.name, "result": result}
