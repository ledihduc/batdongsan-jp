"""Thẻ tin trả kèm câu chat (Phase 08, AC7, PD3, T15).

Chỉ lấy tin do `run_action` của chính lượt trả về ⇒ mọi `listing_id` có thật trong DB và
thoả tham số đã dùng. Thẻ dạng trung tính thị trường để bản vn (Phase 13) dùng lại.
"""

from __future__ import annotations

import re
from typing import Optional

CARD_KEYS = ("listing_id", "title", "price", "currency", "area_m2", "layout", "bedrooms",
             "station_name", "walk_min", "city", "thumbnail_url")
_CITE_RE = re.compile(r"\[#(\d+)\]")


def to_card(item: dict) -> dict:
    """Item JP (có `monthly_rent`) ⇒ map sang khoá trung tính; item đã có `currency` ⇒ giữ đúng CARD_KEYS."""
    if "currency" in item or "monthly_rent" not in item:
        return {k: item.get(k) for k in CARD_KEYS}
    return {
        "listing_id": item.get("listing_id"),
        "title": item.get("title"),
        "price": item.get("monthly_rent"),
        "currency": "JPY",
        "area_m2": item.get("floor_area_m2"),
        "layout": item.get("layout"),
        "bedrooms": None,
        "station_name": item.get("nearest_station_name"),
        "walk_min": item.get("nearest_station_walk_min"),
        "city": item.get("city"),
        "thumbnail_url": item.get("thumbnail_url"),
    }


def _first(seq) -> Optional[dict]:
    return seq[0] if isinstance(seq, list) and seq and isinstance(seq[0], dict) else None


def detail_to_item(detail: dict) -> dict:
    """Payload `get_listing` (lồng nhau) ⇒ dạng item tìm kiếm phẳng như `to_summary`."""
    terms = detail.get("rental_terms") or {}
    info = detail.get("property_info") or {}
    transit = _first(detail.get("transit_accesses")) or {}
    images = detail.get("image_urls") or []
    return {
        "listing_id": detail.get("listing_id"),
        "title": detail.get("title"),
        "monthly_rent": terms.get("monthly_rent"),
        "layout": info.get("layout"),
        "floor_area_m2": info.get("floor_area_m2"),
        "nearest_station_name": (transit.get("station") or {}).get("name"),
        "nearest_station_walk_min": transit.get("walk_minutes"),
        "thumbnail_url": images[0] if images else None,
        "city": detail.get("city"),
    }


def extract_cited_ids(reply: str) -> list[int]:
    """`[#<id>]` theo thứ tự xuất hiện, bỏ trùng."""
    seen: list[int] = []
    for raw in _CITE_RE.findall(reply or ""):
        value = int(raw)
        if value not in seen:
            seen.append(value)
    return seen


def select_cards(reply: str, tool_items: list[dict], last_search_items: list[dict]) -> list[dict]:
    """Có trích dẫn ⇒ chỉ tin vừa trích VÀ do tool trả (theo thứ tự trích); không trích ⇒ kết quả tìm cuối."""
    cited = extract_cited_ids(reply)
    if not cited:
        return list(last_search_items)
    by_id: dict[int, dict] = {}
    for item in tool_items:
        by_id.setdefault(item.get("listing_id"), item)  # giữ bản đầu (thẻ tìm kiếm) khi trùng
    return [by_id[i] for i in cited if i in by_id]
