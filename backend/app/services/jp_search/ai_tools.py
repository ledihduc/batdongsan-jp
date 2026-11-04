"""Handler python của registry jp (`tool_*`) — bọc service tìm kiếm cho kênh AI (Phase 05).

`params` đã được runner validate theo JSON Schema trong registry. Kết quả là dữ liệu
gửi cho model: không SĐT/email/địa chỉ chi tiết, mô tả tin cắt ngắn (T5, K4, X8).
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.ai_capabilities.context import ActionContext
from app.services.jp_search.listing_search_service import (
    JpListingFilters,
    get_listing_detail,
    search_listings,
)
from app.services.jp_search.station_resolver import resolve_station_ids, search_stations

DESCRIPTION_MAX_CHARS = 1500
_DEFAULT_LIMIT = 5  # jsonschema không áp `default` ⇒ đặt ở đây
_UNSUPPORTED_NOTE = "ペット可等の条件は未対応 / pet etc. filters not supported"
_STATION_NOT_FOUND_HINT = "station not found: pass the Japanese name (e.g. 渋谷) or check it with search_stations"


def tool_search_listings(db: Session, args: dict, ctx: ActionContext) -> dict:
    # REST coi tên ga rỗng là "không lọc"; với AI thì phải báo, kẻo trả tin bất kỳ như thể khớp ga (QA H1).
    if args.get("station_name") is not None and args.get("station_id") is None:
        station_ids = resolve_station_ids(db, station_name=args["station_name"])
        if station_ids is None:
            raise ValueError("station_name is blank")
        if not station_ids:
            return {"items": [], "total": 0, "note": _UNSUPPORTED_NOTE, "hint": _STATION_NOT_FOUND_HINT}
    filters = JpListingFilters(
        layouts=tuple(args.get("layouts") or ()),
        min_rent=args.get("min_rent_jpy"),
        max_rent=args.get("max_rent_jpy"),
        min_area=args.get("min_area_m2"),
        max_area=args.get("max_area_m2"),
        max_walk_min=args.get("max_walk_min"),
        station_id=args.get("station_id"),
        station_name=args.get("station_name"),
        page=1,
        page_size=args.get("limit") or _DEFAULT_LIMIT,
    )
    page = search_listings(db, filters)
    return {"items": page.items, "total": page.total, "note": _UNSUPPORTED_NOTE}


def tool_get_listing(db: Session, args: dict, ctx: ActionContext) -> dict:
    detail = get_listing_detail(db, args["listing_id"])
    if detail is None:
        raise LookupError("listing not found")
    detail.pop("address", None)  # địa chỉ chi tiết không gửi cho model (T5)
    if detail.get("description"):
        detail["description"] = detail["description"][:DESCRIPTION_MAX_CHARS]
    return detail


def tool_search_stations(db: Session, args: dict, ctx: ActionContext) -> dict:
    return {"stations": search_stations(db, args["q"], limit=args.get("limit") or 10)}
