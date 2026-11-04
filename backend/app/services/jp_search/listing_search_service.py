"""Tìm + xem chi tiết tin thuê JP (D12, T1, T7).

"Tin JP" = `houses.status='published'` INNER JOIN `jp_rental_terms`
(`listing_id = houses.id` dạng chuỗi, `region='jp'`) LEFT JOIN `jp_property_info`.
Không lọc theo `org_id` (tin công khai; repo theo org luôn rỗng — F2).
Một trang = 1 query tin + 1 query đếm + 1 query transit (không N+1).
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import date
from typing import Optional

from sqlalchemy import String, and_, cast, exists
from sqlalchemy.orm import Query, Session, joinedload

from app.domain.jp.property_info import JpPropertyInfo
from app.domain.jp.rental_terms import JpRentalTerms
from app.domain.jp.transit import Station, TransitAccess
from app.models import House, User
from app.services.jp_search.listing_serializers import to_detail, to_summary
from app.services.jp_search.station_resolver import resolve_station_ids

_HOUSE_ID_STR = cast(House.id, String)
MAX_PAGE = 1000
MAX_PAGE_SIZE = 50


@dataclass(frozen=True)
class JpListingFilters:
    layouts: tuple[str, ...] = ()
    min_rent: Optional[int] = None
    max_rent: Optional[int] = None
    min_area: Optional[float] = None
    max_area: Optional[float] = None
    max_building_age: Optional[int] = None
    max_walk_min: Optional[int] = None
    station_id: Optional[int] = None
    station_name: Optional[str] = None
    page: int = 1
    page_size: int = 20


@dataclass(frozen=True)
class JpListingPage:
    items: list[dict]
    total: int
    page: int
    page_size: int


def _base_query(db: Session) -> Query:
    return (
        db.query(House, JpRentalTerms, JpPropertyInfo)
        .join(JpRentalTerms, and_(JpRentalTerms.listing_id == _HOUSE_ID_STR, JpRentalTerms.region == "jp"))
        .outerjoin(JpPropertyInfo, JpPropertyInfo.listing_id == _HOUSE_ID_STR)
        .filter(House.status == "published")
    )


def _apply_filters(q: Query, f: JpListingFilters, station_ids: Optional[list[int]]) -> Query:
    if f.min_rent is not None:
        q = q.filter(JpRentalTerms.monthly_rent_jpy >= f.min_rent)
    if f.max_rent is not None:
        q = q.filter(JpRentalTerms.monthly_rent_jpy <= f.max_rent)
    if f.min_area is not None:
        q = q.filter(JpPropertyInfo.floor_area_sqm >= f.min_area)
    if f.max_area is not None:
        q = q.filter(JpPropertyInfo.floor_area_sqm <= f.max_area)
    if f.layouts:
        q = q.filter(JpPropertyInfo.layout.in_(f.layouts))
    if f.max_building_age is not None:
        q = q.filter(JpPropertyInfo.building_year >= date.today().year - f.max_building_age)
    # Ga và phút đi bộ cùng nằm trên MỘT dòng transit; không có ga ⇒ xét mọi ga.
    if station_ids is not None or f.max_walk_min is not None:
        conds = [TransitAccess.listing_id == _HOUSE_ID_STR]
        if station_ids is not None:
            conds.append(TransitAccess.station_id.in_(station_ids))
        if f.max_walk_min is not None:
            conds.append(TransitAccess.walk_min <= f.max_walk_min)
        q = q.filter(exists().where(*conds))
    return q


def _transits_by_listing(
    db: Session, listing_ids: list[str], station_ids: Optional[list[int]] = None,
) -> dict[str, list[TransitAccess]]:
    """Dòng transit (kèm ga + tuyến) theo listing_id, sắp `walk_min` tăng dần."""
    if not listing_ids:
        return {}
    q = (
        db.query(TransitAccess)
        .options(joinedload(TransitAccess.station).joinedload(Station.line))
        .filter(TransitAccess.listing_id.in_(listing_ids))
    )
    if station_ids is not None:
        q = q.filter(TransitAccess.station_id.in_(station_ids))
    out: dict[str, list[TransitAccess]] = {}
    for row in q.order_by(TransitAccess.walk_min, TransitAccess.id):
        out.setdefault(row.listing_id, []).append(row)
    return out


def _normalize(f: JpListingFilters) -> JpListingFilters:
    """Luật chung cho mọi kênh (REST, MCP, chat): walk 0 = không giới hạn; kẹp trang."""
    return replace(
        f,
        max_walk_min=f.max_walk_min or None,
        page=min(max(f.page, 1), MAX_PAGE),
        page_size=min(max(f.page_size, 1), MAX_PAGE_SIZE),
    )


def search_listings(db: Session, filters: JpListingFilters) -> JpListingPage:
    filters = _normalize(filters)
    station_ids = resolve_station_ids(db, station_id=filters.station_id, station_name=filters.station_name)
    if station_ids == []:  # ga không tồn tại ⇒ không tin nào khớp
        return JpListingPage(items=[], total=0, page=filters.page, page_size=filters.page_size)
    q = _apply_filters(_base_query(db), filters, station_ids)
    total = q.count()
    rows = (
        q.order_by(JpRentalTerms.monthly_rent_jpy.asc(), House.id.asc())
        .offset((filters.page - 1) * filters.page_size)
        .limit(filters.page_size)
        .all()
    )
    # Ga hiển thị trên thẻ = ga gần nhất trong các ga đang lọc (nếu có lọc ga).
    transits = _transits_by_listing(db, [str(h.id) for h, _, _ in rows], station_ids)
    items = [
        to_summary(h, terms, info, (transits.get(str(h.id)) or [None])[0])
        for h, terms, info in rows
    ]
    return JpListingPage(items=items, total=total, page=filters.page, page_size=filters.page_size)


def get_listing_detail(db: Session, listing_id: int) -> Optional[dict]:
    """None khi không phải tin JP đang đăng (route trả 404)."""
    # Chưa có unique trên listing_id ⇒ chọn dòng cũ nhất, khớp thứ tự thẻ tìm kiếm.
    row = (
        _base_query(db).filter(House.id == listing_id)
        .order_by(JpRentalTerms.id, JpPropertyInfo.id).first()
    )
    if row is None:
        return None
    house, terms, info = row
    transits = _transits_by_listing(db, [str(house.id)]).get(str(house.id), [])
    host = db.get(User, house.host_id)
    return to_detail(house, terms, info, transits, host.name if host else None)
