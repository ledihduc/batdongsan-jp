"""Handler python cho action ghi của registry vn (Phase 13, T11, T17).

Dùng chung `save_wishlist` với bản jp. `ctx.dry_run` ⇒ chỉ kiểm tin, không ghi (lúc tạo pending,
kênh MCP chưa có user). Ghi thật chạy khi xác nhận, `ctx.user` = người bấm. Không commit — confirm_service commit.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.ai_capabilities.context import ActionContext
from app.services.ai_actions.wishlist_writer import save_wishlist
from app.services.vn_search.listing_search_service import get_vn_listing_detail


def tool_save_favorite(db: Session, args: dict, ctx: ActionContext) -> dict:
    listing_id = int(args["listing_id"])
    detail = get_vn_listing_detail(db, listing_id)
    if detail is None:  # tin JP / chưa đăng / không có ⇒ không cho lưu ở bản vn
        raise LookupError("listing not found")
    if ctx.dry_run:
        return {"preview": {"listing_id": listing_id, "title": detail.get("title")}}
    if not ctx.user or ctx.user.get("sub") is None:
        raise ValueError("login required to write")  # không xảy ra qua confirm (require_user)
    return save_wishlist(db, user_id=int(ctx.user["sub"]), house_id=listing_id, dry_run=False)
