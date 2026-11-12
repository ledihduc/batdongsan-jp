"""Tìm / xem tin VN cho kênh AI (MCP + chatbot) của bản vn (plan 20261027-1102, Phase 13 — S12, T5, T7).

Đọc bảng `houses` trực tiếp, KHÔNG qua `/api/houses`: `house_to_dict` trả `host_phone` (T5) và
`GET /api/houses/{id}` tăng `view_count` (F30). "Tin VN" = `published` và không phải tin JP —
`scope_houses(q, "vn")` áp LUÔN (không phụ thuộc `demo_market_scope`): AI bản vn không bao giờ trả tin JP.
Item search = đúng khoá thẻ trung tính `CARD_KEYS` (T15); chi tiết thêm vài trường, không địa chỉ/liên hệ.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from sqlalchemy import func, or_
from sqlalchemy.orm import Query, Session

from app.helpers import _rel_upload_url
from app.models import Category, House
from app.services.market_scope import scope_houses
from app.services.vn_search.vn_location_normalizer import escape_like, normalize_location

DESCRIPTION_MAX_CHARS = 1500


@dataclass(frozen=True)
class VnListingFilters:
    location: Optional[str] = None
    category: Optional[str] = None
    transaction_type: Optional[str] = None
    min_price_vnd: Optional[int] = None
    max_price_vnd: Optional[int] = None
    min_area_m2: Optional[float] = None
    max_area_m2: Optional[float] = None
    min_bedrooms: Optional[int] = None
    limit: int = 10


@dataclass(frozen=True)
class VnListingPage:
    items: list[dict]
    total: int


def _vn_published(db: Session) -> Query:
    return scope_houses(db.query(House).filter(House.status == "published"), "vn")


def _apply_filters(q: Query, f: VnListingFilters) -> Query:
    # Mỗi phần địa danh (đã chuẩn hoá) phải khớp: BẰNG quận (không LIKE: "Quận 1" khớp nhầm
    # "Quận 10") hoặc thành phố CHỨA chuỗi. "Ba Đình, Hà Nội" ⇒ quận Ba Đình VÀ thành phố Hà Nội.
    for part in normalize_location(f.location):
        q = q.filter(or_(func.lower(House.district) == part.lower(),
                         House.city.ilike(f"%{escape_like(part)}%", escape="\\")))
    if f.category:
        q = q.join(Category, House.category_id == Category.id).filter(Category.name == f.category)
    if f.transaction_type:
        q = q.filter(House.transaction_type == f.transaction_type)
    if f.min_price_vnd is not None:
        q = q.filter(House.price >= f.min_price_vnd)
    if f.max_price_vnd is not None:
        q = q.filter(House.price <= f.max_price_vnd)
    if f.min_area_m2 is not None:
        q = q.filter(House.area >= f.min_area_m2)
    if f.max_area_m2 is not None:
        q = q.filter(House.area <= f.max_area_m2)
    if f.min_bedrooms is not None:
        q = q.filter(House.bedrooms >= f.min_bedrooms)
    return q


def _card(h: House) -> dict:
    images = h.images or []
    return {
        "listing_id": h.id,
        "title": h.title,
        "price": int(h.price or 0),
        "currency": "VND",
        "area_m2": h.area,
        "layout": None,
        "bedrooms": h.bedrooms,
        "station_name": None,
        "walk_min": None,
        "city": h.city or None,
        "thumbnail_url": _rel_upload_url(images[0]) if images else None,
    }


def search_vn_listings(db: Session, filters: VnListingFilters) -> VnListingPage:
    q = _apply_filters(_vn_published(db), filters)
    total = q.count()
    limit = max(1, min(int(filters.limit or 10), 20))
    rows = q.order_by(House.price, House.id).limit(limit).all()
    return VnListingPage(items=[_card(h) for h in rows], total=total)


def get_vn_listing_detail(db: Session, listing_id: int) -> Optional[dict]:
    """Tin VN đang đăng ⇒ thẻ + mô tả/loại hình/quận; tin JP, chưa đăng, không có ⇒ None."""
    h = _vn_published(db).filter(House.id == int(listing_id)).first()
    if h is None:
        return None
    category = db.get(Category, h.category_id) if h.category_id else None
    return {
        **_card(h),
        "description": (h.description or "")[:DESCRIPTION_MAX_CHARS],
        "category": category.name if category else None,
        "transaction_type": h.transaction_type,
        "bathrooms": h.bathrooms,
        "district": h.district or None,
    }
