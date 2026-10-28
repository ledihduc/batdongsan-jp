"""Tách dữ liệu 2 thị trường (jp / vn) bằng code trên cùng một DB demo (T14).

Bản jp và bản vn chạy lần lượt trên cùng DB local: lọc ở câu truy vấn thay vì
tắt `is_active` trên DB ⇒ đổi thị trường chỉ cần đổi REGION + restart.
Chỉ có hiệu lực khi `settings.demo_market_scope` bật; prod để tắt ⇒ hành vi cũ.

- Loại hình: jp chỉ thấy tên trong `JP_CATEGORY_NAMES`; vn ẩn đúng các tên đó.
- Tin: jp chỉ thấy tin có `jp_rental_terms` region jp; vn bỏ các tin đó.
"""

from __future__ import annotations

from sqlalchemy import String, cast, exists
from sqlalchemy.orm import Query
from sqlalchemy.sql.elements import ColumnElement

from app.config import settings
from app.domain.jp.rental_terms import JpRentalTerms
from app.models import Category, House

JP_CATEGORY_NAMES: tuple[str, ...] = ("マンション", "アパート", "一戸建て", "テラスハウス", "シェアハウス")


def market_scope_on() -> bool:
    return settings.demo_market_scope


def jp_listing_exists() -> ColumnElement[bool]:
    """EXISTS(jp_rental_terms region jp gắn với houses.id) — `listing_id` lưu id dạng chuỗi."""
    return exists().where(
        JpRentalTerms.listing_id == cast(House.id, String),
        JpRentalTerms.region == "jp",
    )


def scope_categories(q: Query, region: str) -> Query:
    if region == "jp":
        return q.filter(Category.name.in_(JP_CATEGORY_NAMES))
    return q.filter(Category.name.notin_(JP_CATEGORY_NAMES))


def scope_houses(q: Query, region: str) -> Query:
    if region == "jp":
        return q.filter(jp_listing_exists())
    return q.filter(~jp_listing_exists())
