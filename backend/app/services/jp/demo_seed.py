"""Seed tin demo Tokyo cho bản jp (plan 20261027-1102, Phase 03 — AC2).

`seed.run` không chạy trên DB đã có user (F12) ⇒ seed riêng, chạy tay qua
`scripts/seed_jp_demo.py`. Idempotent theo khoá tự nhiên:
  host = `DEMO_HOST_EMAIL` · tin = (host_id, title) · terms/info = listing_id
  · transit = (listing_id, station_id).
`listing_id` = `str(houses.id)` (cùng quy ước `jp_transit_access`). Giá tin
`houses.price` = tiền thuê JPY (A5); không thêm cột vào `houses` (D12).
"""

from __future__ import annotations

import json
import pathlib
import secrets
from dataclasses import dataclass
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session

from app.auth import hash_password
from app.domain.jp.property_info import LAYOUT_VALUES, JpPropertyInfo
from app.domain.jp.rental_terms import JpRentalTerms
from app.domain.jp.transit import Station, TransitAccess
from app.models import Category, House, User
from app.services.market_scope import JP_CATEGORY_NAMES

DEMO_HOST_EMAIL: str = "jp-demo-host@example.invalid"


@dataclass(frozen=True)
class DemoSeedResult:
    houses_created: int
    houses_updated: int
    transit_rows: int


def load_demo_listings(path: pathlib.Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError(f"{path}: cần mảng JSON các tin")
    return data


def _dec(value) -> Optional[Decimal]:
    return None if value is None else Decimal(str(value))


def _ensure_host(db: Session) -> User:
    host = db.query(User).filter(User.email == DEMO_HOST_EMAIL).first()
    if host is None:
        # Mật khẩu ngẫu nhiên không lưu, không SĐT ⇒ không ai đăng nhập được.
        host = User(name="デモ不動産", email=DEMO_HOST_EMAIL, phone="", role="host",
                    password_hash=hash_password(secrets.token_urlsafe(24)))
        db.add(host)
        db.flush()
    return host


def _ensure_categories(db: Session) -> dict[str, int]:
    """Get-or-create 5 loại hình JP; không đụng loại hình khác (12 loại VN)."""
    existing = {c.name: c for c in db.query(Category).filter(Category.name.in_(JP_CATEGORY_NAMES))}
    for order, name in enumerate(JP_CATEGORY_NAMES):
        if name not in existing:
            existing[name] = Category(name=name, icon="", group_key="stay_long", sort_order=order, is_active=True)
            db.add(existing[name])
    db.flush()
    return {name: c.id for name, c in existing.items()}


def _stations_by_cd(db: Session, listings: list[dict]) -> dict[int, Station]:
    wanted = {int(t["station_cd"]) for item in listings for t in item.get("transit", [])}
    found = {s.ekidata_station_cd: s for s in db.query(Station).filter(Station.ekidata_station_cd.in_(wanted))}
    missing = sorted(wanted - set(found))
    if missing:
        raise ValueError(f"station_cd {missing[0]} chưa import (thiếu {len(missing)} mã)")
    return found


def _upsert_house(db: Session, host: User, category_id: int, item: dict, first: Station) -> tuple[House, bool]:
    layout = item["layout"]
    if layout not in LAYOUT_VALUES:
        raise ValueError(f"layout {layout!r} không thuộc LAYOUT_VALUES ({item['title']})")
    house = db.query(House).filter(House.host_id == host.id, House.title == item["title"]).first()
    created = house is None
    if created:
        house = House(host_id=host.id, title=item["title"], images=[], amenities=[])
        db.add(house)
    house.description = item.get("description", "")
    house.category_id = category_id
    house.price = float(item["rent_jpy"])
    house.area = float(item.get("floor_area_sqm") or 0)
    house.address = item.get("address", "")
    house.city = item.get("city", "")
    house.status = "published"
    house.transaction_type = "rent"
    house.bedrooms = int(layout[0])  # "1LDK" → 1, "4LDK+" → 4
    house.latitude = float(first.latitude) if first.latitude is not None else None
    house.longitude = float(first.longitude) if first.longitude is not None else None
    db.flush()
    return house, created


def _upsert_jp_rows(db: Session, listing_id: str, item: dict) -> None:
    terms = db.query(JpRentalTerms).filter(JpRentalTerms.listing_id == listing_id).first()
    if terms is None:
        terms = JpRentalTerms(listing_id=listing_id, region="jp", tax_treatment="included")
        db.add(terms)
    terms.monthly_rent_jpy = _dec(item["rent_jpy"])
    terms.management_fee_jpy = _dec(item.get("management_fee_jpy"))
    terms.shikikin_months = _dec(item.get("shikikin_months"))
    terms.reikin_months = _dec(item.get("reikin_months"))

    info = db.query(JpPropertyInfo).filter(JpPropertyInfo.listing_id == listing_id).first()
    if info is None:
        info = JpPropertyInfo(listing_id=listing_id, region="jp")
        db.add(info)
    info.layout = item["layout"]
    info.floor_area_sqm = _dec(item.get("floor_area_sqm"))
    info.building_year = item.get("building_year")
    info.structure = item.get("structure")
    info.floor_number = item.get("floor_number")
    info.orientation = item.get("orientation")


def _upsert_transit(db: Session, listing_id: str, item: dict, stations: dict[int, Station]) -> int:
    wanted = {stations[int(t["station_cd"])].id: int(t["walk_min"]) for t in item.get("transit", [])}
    rows = {r.station_id: r for r in db.query(TransitAccess).filter(TransitAccess.listing_id == listing_id)}
    for station_id, row in rows.items():
        if station_id not in wanted:  # ga đã bỏ khỏi dữ liệu demo
            db.delete(row)
    for station_id, walk in wanted.items():
        row = rows.get(station_id) or TransitAccess(listing_id=listing_id, station_id=station_id, region="jp")
        row.walk_min = walk
        db.add(row)
    return len(wanted)


def seed_jp_demo(db: Session, listings: list[dict]) -> DemoSeedResult:
    """Ghi/cập nhật tin demo; commit cuối hàm. Lỗi dữ liệu ⇒ rollback, ném ValueError."""
    try:
        stations = _stations_by_cd(db, listings)
        host = _ensure_host(db)
        categories = _ensure_categories(db)
        created = updated = transit_rows = 0
        for item in listings:
            if not item.get("transit"):
                raise ValueError(f"tin {item.get('title')!r} thiếu transit")
            category_id = categories.get(item.get("category", ""))
            if category_id is None:
                raise ValueError(f"category {item.get('category')!r} không thuộc JP_CATEGORY_NAMES")
            first = stations[int(item["transit"][0]["station_cd"])]
            house, is_new = _upsert_house(db, host, category_id, item, first)
            created, updated = created + is_new, updated + (not is_new)
            listing_id = str(house.id)
            _upsert_jp_rows(db, listing_id, item)
            transit_rows += _upsert_transit(db, listing_id, item, stations)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return DemoSeedResult(houses_created=created, houses_updated=updated, transit_rows=transit_rows)


def undo_jp_demo(db: Session) -> int:
    """Xoá tin/host/loại hình demo JP. Loại hình JP còn tin khác dùng thì giữ lại."""
    host = db.query(User).filter(User.email == DEMO_HOST_EMAIL).first()
    if host is None:
        return 0
    try:
        houses = db.query(House).filter(House.host_id == host.id).all()
        ids = [str(h.id) for h in houses]
        for model in (TransitAccess, JpRentalTerms, JpPropertyInfo):
            db.query(model).filter(model.listing_id.in_(ids)).delete(synchronize_session=False)
        for h in houses:
            db.delete(h)
        db.delete(host)
        db.flush()
        for cat in db.query(Category).filter(Category.name.in_(JP_CATEGORY_NAMES)):
            if db.query(House).filter(House.category_id == cat.id).count() == 0:
                db.delete(cat)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return len(houses)
