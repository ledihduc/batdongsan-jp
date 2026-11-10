"""Handler python cho action ghi của registry jp (Phase 09, T11, F22, F23).

Route REST tương ứng không dùng được (không có `/api/wishlists`; `POST /api/jp/viewings` luôn 403)
⇒ ghi qua model/service. `ctx.dry_run` ⇒ chỉ kiểm, không ghi (lúc tạo pending). Ghi thật chạy
khi xác nhận, `ctx.user` = người bấm (require_user). Không commit — confirm_service commit.
"""

from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.ai_capabilities.context import ActionContext
from app.repositories.jp.viewing import JpViewingRepository
from app.services.ai_actions.wishlist_writer import save_wishlist
from app.services.jp.viewing.scheduler import ViewingSchedulerError, create_viewing_request, validate_slots
from app.services.jp_search.listing_search_service import get_listing_detail


def _require_listing(db: Session, listing_id: int) -> dict:
    detail = get_listing_detail(db, listing_id)
    if detail is None:
        raise LookupError("listing not found")
    return detail


def _user_id(ctx: ActionContext) -> int:
    if not ctx.user or ctx.user.get("sub") is None:
        raise ValueError("login required to write")  # không bao giờ xảy ra qua confirm (require_user)
    return int(ctx.user["sub"])


def tool_save_favorite(db: Session, args: dict, ctx: ActionContext) -> dict:
    listing_id = int(args["listing_id"])
    detail = _require_listing(db, listing_id)
    if ctx.dry_run:
        return {"preview": {"listing_id": listing_id, "title": detail.get("title")}}
    return save_wishlist(db, user_id=_user_id(ctx), house_id=listing_id, dry_run=False)


def tool_request_viewing(db: Session, args: dict, ctx: ActionContext) -> dict:
    listing_id = int(args["listing_id"])
    slots = list(args["slots"])
    detail = _require_listing(db, listing_id)
    try:
        validate_slots(slots)  # cả lúc tạo pending (báo sớm cho AI) lẫn lúc xác nhận (giờ đã trôi)
    except ViewingSchedulerError as exc:
        raise ValueError(str(exc)) from exc
    if ctx.dry_run:
        return {"preview": {"listing_id": listing_id, "title": detail.get("title"), "slots": slots}}
    note = (args.get("note") or "").strip()
    try:
        viewing = create_viewing_request(
            JpViewingRepository(db), org_id=None, listing_id=str(listing_id), tenant_id=_user_id(ctx),
            requested_slots=slots, notes=f"[AI] {note}" if note else "[AI]",
        )
    except HTTPException as exc:
        raise ValueError(str(exc.detail)) from exc
    return {"viewing_id": viewing.id, "status": "requested", "created": True}
