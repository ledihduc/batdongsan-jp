"""Gỡ dữ liệu do action ghi AI đã thực thi (Phase 09, F-8, rollback).

Chỉ xoá đúng dòng ghi trong `result` của pending `executed`: `save_favorite` với `created=True`
⇒ xoá `wishlists.id`; `request_viewing` ⇒ xoá `jp_viewings.id`. `created=False` (tin đã có sẵn
trong yêu thích từ trước) không đụng. Mọi dòng duyệt qua ⇒ `status='undone'`.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.domain.ai_pending_action import AiPendingAction
from app.domain.jp.viewing import JpViewing
from app.models import Wishlist

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class UndoReport:
    wishlists_deleted: int
    viewings_deleted: int
    pending_marked: int


def _target_ids(rows: list[AiPendingAction]) -> tuple[list[int], list[int]]:
    wishlist_ids, viewing_ids = [], []
    for row in rows:
        result = row.result if isinstance(row.result, dict) else {}
        if row.action == "save_favorite" and result.get("created") is True and result.get("wishlist_id"):
            wishlist_ids.append(int(result["wishlist_id"]))
        elif row.action == "request_viewing" and result.get("viewing_id"):
            viewing_ids.append(int(result["viewing_id"]))
    return wishlist_ids, viewing_ids


def undo_executed_actions(db: Session, *, since: Optional[datetime] = None, dry_run: bool = True) -> UndoReport:
    """`since` (naive UTC) lọc theo `executed_at`. `dry_run` ⇒ chỉ đếm dòng còn tồn tại."""
    query = db.query(AiPendingAction).filter(AiPendingAction.status == "executed")
    if since is not None:
        query = query.filter(AiPendingAction.executed_at >= since)
    rows = query.order_by(AiPendingAction.id).all()
    wishlist_ids, viewing_ids = _target_ids(rows)
    wishlists = db.query(Wishlist.id).filter(Wishlist.id.in_(wishlist_ids)).count() if wishlist_ids else 0
    viewings = db.query(JpViewing.id).filter(JpViewing.id.in_(viewing_ids)).count() if viewing_ids else 0
    report = UndoReport(wishlists_deleted=wishlists, viewings_deleted=viewings, pending_marked=len(rows))
    if dry_run or not rows:
        return report
    try:
        if wishlist_ids:
            db.execute(delete(Wishlist).where(Wishlist.id.in_(wishlist_ids)))
        if viewing_ids:
            db.execute(delete(JpViewing).where(JpViewing.id.in_(viewing_ids)))
        for row in rows:
            row.status = "undone"
        db.commit()
    except Exception:
        db.rollback()
        raise
    logger.info("ai_actions_undone", extra={"event": "ai_actions_undone", **report.__dict__})
    return report
