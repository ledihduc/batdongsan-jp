"""Lưu tin yêu thích — dùng chung jp và vn (Phase 13), DRY (Phase 09, T11).

Không có route `/api/wishlists` (F22) ⇒ ghi thẳng model `Wishlist` (UNIQUE user+house).
Không commit: người gọi (confirm_service) commit cùng transaction với claim pending.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import Wishlist


def save_wishlist(db: Session, *, user_id: int, house_id: int, dry_run: bool) -> dict:
    """Get-or-create; `created=False` khi tin đã có sẵn (undo không được xoá dòng đó)."""
    if dry_run:
        return {"preview": {"house_id": house_id}}
    existing = db.query(Wishlist).filter_by(user_id=user_id, house_id=house_id).first()
    if existing is not None:
        return {"saved": True, "created": False, "wishlist_id": existing.id}
    row = Wishlist(user_id=user_id, house_id=house_id)
    db.add(row)
    db.flush()
    return {"saved": True, "created": True, "wishlist_id": row.id}
