"""Tóm tắt tin cho màn xác nhận action ghi, theo thị trường đang chạy (Phase 09, F-4).

jp: từ `get_listing_detail` (JPY, có 間取り). vn: từ `get_vn_listing_detail` (VND, không layout — Phase 13 F-6).
Region khác ⇒ None.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy.orm import Session

from app.config import settings
from app.services.jp_search.listing_search_service import get_listing_detail
from app.services.vn_search.listing_search_service import get_vn_listing_detail


def listing_brief(db: Session, listing_id: Optional[int]) -> Optional[dict]:
    if listing_id is None:
        return None
    if settings.region == "vn":
        vn = get_vn_listing_detail(db, int(listing_id))
        if vn is None:
            return None
        return {"listing_id": vn["listing_id"], "title": vn["title"] or "", "price": vn["price"],
                "currency": "VND", "layout": None}
    if settings.region != "jp":
        return None
    detail = get_listing_detail(db, int(listing_id))
    if detail is None:
        return None
    terms = detail.get("rental_terms") or {}
    info = detail.get("property_info") or {}
    return {
        "listing_id": detail["listing_id"],
        "title": detail.get("title") or "",
        "price": terms.get("monthly_rent"),
        "currency": "JPY",
        "layout": info.get("layout") or None,
    }
