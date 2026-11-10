"""Tạo / tra pending action (Phase 09, P6, K13).

Token 256 bit (`secrets.token_urlsafe(32)` = 43 ký tự), DB chỉ lưu SHA-256. Hết hạn sau
`settings.ai_pending_ttl_min`. Không log token. Thời gian naive UTC (cột DateTime không tz).
"""

from __future__ import annotations

import hashlib
import logging
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import TYPE_CHECKING, Optional

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.config import settings
from app.domain.ai_pending_action import AiPendingAction

if TYPE_CHECKING:
    from app.ai_capabilities.context import ActionContext
    from app.ai_capabilities.loader import Action

logger = logging.getLogger(__name__)

_STALE_AFTER = timedelta(days=1)  # dòng pending hết hạn quá 1 ngày ⇒ dọn khi tạo mới


@dataclass(frozen=True)
class PendingCreated:
    token: str
    pending_id: int
    expires_at: datetime
    confirm_url: str


class PendingError(Exception):
    """not_found 404 · forbidden 403 · used 409 · expired 410 · action_unavailable 410 · <mã handler> 422."""

    def __init__(self, code: str, http_status: int) -> None:
        super().__init__(code)
        self.code = code
        self.http_status = http_status


def utcnow() -> datetime:
    return datetime.utcnow()


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def confirm_url_for(token: str) -> str:
    return f"{settings.ai_confirm_base_url.rstrip('/')}/ai-confirm/{token}"


def create_pending(db: Session, action: "Action", params: dict, ctx: "ActionContext", *,
                   now: Optional[datetime] = None) -> PendingCreated:
    """Ghi 1 dòng `pending` và commit. Chat ⇒ gắn `owner_user_id`; MCP ⇒ NULL (ai đăng nhập cũng xác nhận được)."""
    now = now or utcnow()
    db.execute(delete(AiPendingAction).where(
        AiPendingAction.status == "pending", AiPendingAction.expires_at < now - _STALE_AFTER))
    token = secrets.token_urlsafe(32)
    owner = int(ctx.user["sub"]) if ctx.user and ctx.user.get("sub") is not None else None
    row = AiPendingAction(
        token_sha256=hash_token(token), action=action.name, params=params, channel=ctx.channel,
        owner_user_id=owner, status="pending", created_at=now,
        expires_at=now + timedelta(minutes=settings.ai_pending_ttl_min),
    )
    db.add(row)
    db.commit()
    logger.info("ai_action_pending_created", extra={
        "event": "ai_action_pending_created", "action": action.name, "pending_id": row.id,
        "user_id": owner, "channel": ctx.channel})
    return PendingCreated(token=token, pending_id=row.id, expires_at=row.expires_at, confirm_url=confirm_url_for(token))


def get_pending(db: Session, token: str) -> Optional[AiPendingAction]:
    return db.query(AiPendingAction).filter(AiPendingAction.token_sha256 == hash_token(token)).first()
