"""Đổi ORM sang dict đúng key Flutter đọc (`JpListingSummary`, `JpListing.fromJson`).

Dart đọc `listing_id`, `monthly_rent`, `id`… bằng `as int` ⇒ ép Decimal/chuỗi
sang int; cột tháng/tỉ lệ sang float. Không trả SĐT/email chủ tin (AC4, T5).
"""

from __future__ import annotations

from decimal import Decimal
from typing import Optional

from app.domain.jp.property_info import JpPropertyInfo
from app.domain.jp.rental_terms import JpRentalTerms
from app.domain.jp.transit import TransitAccess
from app.models import House


def _int(v: Optional[Decimal]) -> Optional[int]:
    return None if v is None else int(v)


def _float(v) -> Optional[float]:
    return None if v is None else float(v)


def _image_urls(house: House) -> list[str]:
    return [u for u in (house.images or []) if isinstance(u, str) and u]


def to_summary(
    house: House, terms: JpRentalTerms, info: Optional[JpPropertyInfo], nearest: Optional[TransitAccess],
) -> dict:
    images = _image_urls(house)
    return {
        "listing_id": house.id,
        "title": house.title,
        "monthly_rent": int(terms.monthly_rent_jpy),
        "layout": (info.layout if info else None) or "",
        "floor_area_m2": _float(info.floor_area_sqm if info else None) or 0.0,
        "nearest_station_name": nearest.station.name_ja if nearest else None,
        "nearest_station_walk_min": nearest.walk_min if nearest else None,
        "thumbnail_url": images[0] if images else None,
        "city": house.city or None,
        "is_published": house.status == "published",
    }


def _rental_terms(t: JpRentalTerms) -> dict:
    return {
        "id": t.id,
        "monthly_rent": int(t.monthly_rent_jpy),
        "management_fee": _int(t.management_fee_jpy),
        "shikikin_months": _float(t.shikikin_months),
        "reikin_months": _float(t.reikin_months),
        "hoshoukin_months": _float(t.hoshou_months),
        "koushinryo_months": _float(t.koushinryo_months),
        "brokerage_fee_rate": _float(t.brokerage_rate),
        "guarantee_company_fee": _int(t.hoshou_fee_jpy),
        "tax_included": t.tax_treatment == "included",
    }


def _property_info(i: Optional[JpPropertyInfo]) -> dict:
    # Dart bắt buộc property_info khác null ⇒ thiếu dòng thì trả khung rỗng.
    if i is None:
        return {"id": 0, "layout": "", "floor_area_m2": 0}
    return {
        "id": i.id,
        "layout": i.layout or "",
        "floor_area_m2": _float(i.floor_area_sqm) or 0.0,
        "structure": i.structure,
        "building_year": i.building_year,
        "floor_number": i.floor_number,
        "orientation": i.orientation,
        "available_from": i.available_from.isoformat() if i.available_from else None,
    }


def _transit(t: TransitAccess) -> dict:
    s = t.station
    return {
        "id": t.id,
        "listing_id": int(t.listing_id),
        "station": {
            "id": s.id,
            "name": s.name_ja,
            "name_kana": "",
            "line_name": s.line.name_ja if s.line else "",
            "line_id": s.line_id or 0,
            "prefecture_name": s.prefecture,
            "latitude": _float(s.latitude),
            "longitude": _float(s.longitude),
        },
        "walk_minutes": t.walk_min,
    }


def to_detail(
    house: House, terms: JpRentalTerms, info: Optional[JpPropertyInfo],
    transits: list[TransitAccess], host_name: Optional[str],
) -> dict:
    """`transits` đã sắp `walk_min` tăng dần; tỉnh lấy từ ga gần nhất (houses không có cột tỉnh)."""
    return {
        "listing_id": house.id,
        "title": house.title,
        "rental_terms": _rental_terms(terms),
        "property_info": _property_info(info),
        "transit_accesses": [_transit(t) for t in transits],
        "description": house.description or None,
        "image_urls": _image_urls(house),
        "host_name": host_name,
        "prefecture": transits[0].station.prefecture if transits else None,
        "city": house.city or None,
        "address": house.address or None,
        "is_published": house.status == "published",
    }
