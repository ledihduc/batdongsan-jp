"""Seed ~20 tin demo VN (HCM + Hà Nội) cho bản vn (plan 20261027-1102, Phase 13 — S12).

Chạy tay qua `scripts/seed_vn_demo.py`. Idempotent theo khoá tự nhiên:
  host = `VN_DEMO_HOST_EMAIL` · tin = (host_id, title).
Loại hình lấy theo TÊN có sẵn (12 loại VN của migration 0074) — không tạo loại hình mới.
`undo_vn_demo` xoá wishlist trỏ tin demo → tin → host demo; không đụng loại hình, tin thật.
"""

from __future__ import annotations

import json
import pathlib
import secrets
from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.auth import hash_password
from app.models import Category, House, User, Wishlist

VN_DEMO_HOST_EMAIL: str = "vn-demo-host@example.invalid"
_TRANSACTION_TYPES = ("rent", "sale")


@dataclass(frozen=True)
class VnDemoSeedResult:
    houses_created: int
    houses_updated: int


def load_vn_demo_listings(path: pathlib.Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError(f"{path}: cần mảng JSON các tin")
    return data


def _ensure_host(db: Session) -> User:
    host = db.query(User).filter(User.email == VN_DEMO_HOST_EMAIL).first()
    if host is None:
        # Mật khẩu ngẫu nhiên không lưu, không SĐT ⇒ không ai đăng nhập được.
        host = User(name="Nhà đất Demo", email=VN_DEMO_HOST_EMAIL, phone="", role="host",
                    password_hash=hash_password(secrets.token_urlsafe(24)))
        db.add(host)
        db.flush()
    return host


def _category_ids(db: Session, listings: list[dict]) -> dict[str, int]:
    wanted = {item.get("category", "") for item in listings}
    found = {c.name: c.id for c in db.query(Category).filter(Category.name.in_(wanted))}
    missing = sorted(wanted - set(found))
    if missing:
        raise ValueError(f"loại hình {missing[0]!r} chưa có trong bảng categories")
    return found


def _upsert_house(db: Session, host: User, category_id: int, item: dict) -> bool:
    if item.get("transaction_type") not in _TRANSACTION_TYPES:
        raise ValueError(f"transaction_type {item.get('transaction_type')!r} không hợp lệ ({item['title']})")
    house = db.query(House).filter(House.host_id == host.id, House.title == item["title"]).first()
    created = house is None
    if created:
        house = House(host_id=host.id, title=item["title"], images=[], amenities=[])
        db.add(house)
    house.description = item.get("description", "")
    house.category_id = category_id
    house.transaction_type = item["transaction_type"]
    house.price = float(item["price_vnd"])
    house.area = float(item.get("area_m2") or 0)
    house.bedrooms = int(item.get("bedrooms") or 0)
    house.bathrooms = int(item.get("bathrooms") or 0)
    house.address = item.get("address", "")
    house.district = item.get("district", "")
    house.city = item.get("city", "")
    house.province_code = item.get("province_code")
    house.status = "published"
    db.flush()
    return created


def seed_vn_demo(db: Session, listings: list[dict]) -> VnDemoSeedResult:
    """Ghi/cập nhật tin demo; commit cuối hàm. Lỗi dữ liệu ⇒ rollback, ném ValueError."""
    try:
        categories = _category_ids(db, listings)
        host = _ensure_host(db)
        created = updated = 0
        for item in listings:
            is_new = _upsert_house(db, host, categories[item["category"]], item)
            created, updated = created + is_new, updated + (not is_new)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return VnDemoSeedResult(houses_created=created, houses_updated=updated)


def undo_vn_demo(db: Session) -> int:
    """Xoá wishlist trỏ tin demo, tin demo, host demo. Trả số tin đã xoá."""
    host = db.query(User).filter(User.email == VN_DEMO_HOST_EMAIL).first()
    if host is None:
        return 0
    try:
        houses = db.query(House).filter(House.host_id == host.id).all()
        ids = [h.id for h in houses]
        if ids:
            db.query(Wishlist).filter(Wishlist.house_id.in_(ids)).delete(synchronize_session=False)
        for h in houses:
            db.delete(h)
        db.delete(host)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return len(houses)
