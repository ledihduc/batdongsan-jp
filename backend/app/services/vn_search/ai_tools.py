"""Handler python (đọc) của registry vn (`tool_*`) — bọc service tìm tin VN cho kênh AI (Phase 13).

`params` đã được runner validate theo JSON Schema trong `registry.vn.yaml` (additionalProperties false).
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.ai_capabilities.context import ActionContext
from app.services.vn_search.listing_search_service import (
    VnListingFilters,
    get_vn_listing_detail,
    search_vn_listings,
)


def tool_search_listings(db: Session, args: dict, ctx: ActionContext) -> dict:
    page = search_vn_listings(db, VnListingFilters(**args))
    return {"items": page.items, "total": page.total}


def tool_get_listing(db: Session, args: dict, ctx: ActionContext) -> dict:
    detail = get_vn_listing_detail(db, args["listing_id"])
    if detail is None:
        raise LookupError("listing not found")
    return detail
