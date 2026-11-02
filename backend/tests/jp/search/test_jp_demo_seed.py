"""Seed 36 tin demo Tokyo (plan 20261027-1102, Phase 03 — AC2).

SQLite in-memory qua `jp_search_fixtures`; không cần Postgres.
"""

from __future__ import annotations

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

import pytest

from app.domain.jp.property_info import JpPropertyInfo
from app.domain.jp.rental_terms import JpRentalTerms
from app.domain.jp.transit import Station, TransitAccess
from app.models import Category, House, User
from app.services.jp.demo_seed import DEMO_HOST_EMAIL, seed_jp_demo, undo_jp_demo
from app.services.market_scope import JP_CATEGORY_NAMES
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_station_fixture


def _listing(title: str, rent: int, layout: str, transit: list[tuple[int, int]]) -> dict:
    return {
        "title": title, "description": "テスト（デモデータ）", "prefecture": "東京都", "city": "渋谷区",
        "address": "渋谷区神南1丁目", "category": "マンション", "rent_jpy": rent, "management_fee_jpy": 8000,
        "shikikin_months": 1.0, "reikin_months": 1.0, "layout": layout, "floor_area_sqm": 35.2,
        "building_year": 2015, "structure": "RC", "floor_number": 5, "orientation": "S",
        "transit": [{"station_cd": cd, "walk_min": walk} for cd, walk in transit],
    }


def _counts(db) -> tuple[int, ...]:
    return tuple(db.query(m).count() for m in (House, JpRentalTerms, JpPropertyInfo, TransitAccess, Category, User))


def test_jp_demo_seed_first_run_creates_published_listings_with_jp_data():
    # Arrange
    db = make_sqlite_session()
    seed_station_fixture(db)
    listings = [_listing("渋谷A", 120000, "1LDK", [(1130201, 5)]), _listing("恵比寿B", 98000, "1K", [(1130208, 4)])]

    # Act
    result = seed_jp_demo(db, listings)

    # Assert
    assert result.houses_created == 2
    houses = db.query(House).all()
    assert {h.status for h in houses} == {"published"}
    assert {h.price for h in houses} == {120000.0, 98000.0}
    ids = {str(h.id) for h in houses}
    assert {r.listing_id for r in db.query(JpRentalTerms)} == ids
    assert {p.listing_id for p in db.query(JpPropertyInfo)} == ids
    assert db.query(TransitAccess).count() == 2
    assert {t.listing_id for t in db.query(TransitAccess)} == ids


def test_jp_demo_seed_second_run_creates_no_duplicates():
    # Arrange
    db = make_sqlite_session()
    seed_station_fixture(db)
    listings = [_listing("渋谷A", 120000, "1LDK", [(1130201, 5), (2800105, 6)])]
    seed_jp_demo(db, listings)
    before = _counts(db)

    # Act
    second = seed_jp_demo(db, listings)

    # Assert
    assert second.houses_created == 0
    assert second.houses_updated == 1
    assert _counts(db) == before


def test_jp_demo_seed_unknown_station_cd_raises_value_error():
    # Arrange
    db = make_sqlite_session()
    seed_station_fixture(db)

    # Act + Assert
    with pytest.raises(ValueError, match="station_cd"):
        seed_jp_demo(db, [_listing("不明", 100000, "1K", [(9999999, 5)])])


def test_jp_demo_seed_keeps_vn_categories_and_undo_removes_jp_rows():
    # Arrange
    db = make_sqlite_session()
    seed_station_fixture(db)
    db.add(Category(name="Căn hộ", is_active=True))
    db.commit()

    # Act
    seed_jp_demo(db, [_listing("渋谷A", 120000, "1LDK", [(1130201, 5)])])

    # Assert
    names = {c.name: c.is_active for c in db.query(Category)}
    assert names["Căn hộ"] is True
    assert all(names.get(n) is True for n in JP_CATEGORY_NAMES)

    # Act
    removed = undo_jp_demo(db)

    # Assert
    assert removed == 1
    assert db.query(House).count() == 0
    assert db.query(JpRentalTerms).count() == db.query(JpPropertyInfo).count() == db.query(TransitAccess).count() == 0
    assert db.query(User).filter(User.email == DEMO_HOST_EMAIL).count() == 0
    assert [c.name for c in db.query(Category)] == ["Căn hộ"]


def test_jp_demo_seed_rerun_with_changed_data_updates_rows_and_drops_stale_transit():
    # Arrange
    db = make_sqlite_session()
    stations = seed_station_fixture(db)
    seed_jp_demo(db, [_listing("渋谷A", 120000, "1LDK", [(1130201, 5), (2800105, 6)])])

    # Act
    result = seed_jp_demo(db, [_listing("渋谷A", 135000, "2LDK", [(1130201, 7)])])

    # Assert
    assert (result.houses_created, result.houses_updated) == (0, 1)
    house = db.query(House).one()
    assert (house.price, house.bedrooms) == (135000.0, 2)
    assert int(db.query(JpRentalTerms).one().monthly_rent_jpy) == 135000
    assert db.query(JpPropertyInfo).one().layout == "2LDK"
    rows = db.query(TransitAccess).all()
    assert [(r.station_id, r.walk_min) for r in rows] == [(stations["shibuya_yamanote"], 7)]


@pytest.mark.parametrize(
    ("patch", "match"),
    [
        ({"layout": "5SLDK"}, "layout"),
        ({"transit": []}, "transit"),
        ({"category": "Căn hộ"}, "category"),
    ],
)
def test_jp_demo_seed_invalid_item_raises_value_error_and_writes_nothing(patch, match):
    # Arrange
    db = make_sqlite_session()
    seed_station_fixture(db)
    bad = {**_listing("不正", 100000, "1K", [(1130201, 5)]), **patch}

    # Act + Assert
    with pytest.raises(ValueError, match=match):
        seed_jp_demo(db, [_listing("正常", 90000, "1K", [(1130201, 3)]), bad])
    assert db.query(House).count() == 0
    assert db.query(User).filter(User.email == DEMO_HOST_EMAIL).count() == 0
