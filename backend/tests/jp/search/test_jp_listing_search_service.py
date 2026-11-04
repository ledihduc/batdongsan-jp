"""search_listings / get_listing_detail gọi thẳng service (kênh MCP/chat dùng ở Phase 05+).

Phủ các bộ lọc và nhánh mà test REST không chạm (code review 261102 phase 04 M1, M2).
"""

from __future__ import annotations

import os
from datetime import date

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

import pytest

from app.domain.jp.rental_terms import JpRentalTerms
from app.models import House
from app.services.jp.demo_seed import seed_jp_demo
from app.services.jp_search.listing_search_service import (
    JpListingFilters,
    get_listing_detail,
    search_listings,
)
from app.services.jp_search.station_resolver import resolve_station_ids, search_stations
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture

AC3_TOTAL = 7


@pytest.fixture()
def db():
    session = make_sqlite_session()
    yield session
    session.close()


@pytest.fixture()
def ids(db) -> dict[str, int]:
    return seed_search_fixture(db)


def _titles(page) -> set[str]:
    return {i["title"].split(" ", 1)[0] for i in page.items}


def test_jp_search_service_min_rent_excludes_cheaper(db, ids):
    # Act
    page = search_listings(db, JpListingFilters(min_rent=145000))
    # Assert
    assert _titles(page) == {"[SBY-OK2]", "[SBY-OK3]", "[SBY-NG-RENT]"}


@pytest.mark.parametrize(("lo", "hi", "expected"), [(35.0, 36.0, AC3_TOTAL), (36.0, None, 0), (None, 35.0, 0)])
def test_jp_search_service_area_range_filters(db, ids, lo, hi, expected):
    # Act (mọi tin fixture 35.2 m²)
    page = search_listings(db, JpListingFilters(min_area=lo, max_area=hi))
    # Assert
    assert page.total == expected


def test_jp_search_service_building_age_boundary(db, ids):
    # Arrange (mọi tin fixture xây 2015)
    age = date.today().year - 2015
    # Act
    keep = search_listings(db, JpListingFilters(max_building_age=age))
    drop = search_listings(db, JpListingFilters(max_building_age=age - 1))
    # Assert
    assert keep.total == AC3_TOTAL and drop.total == 0


def test_jp_search_service_multiple_layouts_match_any(db, ids):
    # Act
    page = search_listings(db, JpListingFilters(layouts=("1K", "2LDK")))
    # Assert
    assert _titles(page) == {"[SBY-NG-LAYOUT]"}


def test_jp_search_service_station_name_resolves_like_station_id(db, ids):
    # Act
    by_name = search_listings(db, JpListingFilters(station_name="渋谷駅", max_walk_min=10, max_rent=150000,
                                                   layouts=("1LDK",)))
    # Assert
    assert _titles(by_name) == {"[SBY-OK1]", "[SBY-OK2]", "[SBY-OK3]"}


@pytest.mark.parametrize("blank", ["", "  ", "駅"])
def test_jp_search_service_blank_station_name_means_no_station_filter(db, ids, blank):
    # Act
    page = search_listings(db, JpListingFilters(station_name=blank))
    # Assert
    assert resolve_station_ids(db, station_name=blank) is None and page.total == AC3_TOTAL


def test_jp_search_service_walk_zero_and_page_clamps_in_service(db, ids):
    # Act (gọi thẳng service, không qua validate của route)
    page = search_listings(db, JpListingFilters(max_walk_min=0, page=0, page_size=500))
    # Assert
    assert page.total == AC3_TOTAL and page.page == 1 and page.page_size == 50


def test_jp_search_service_nearest_station_is_among_filtered_stations(db, ids):
    # Arrange: 1 tin 2 ga — 恵比寿 3 phút, 渋谷 8 phút
    listing = {
        "title": "[TWO-ST] 2駅", "city": "渋谷区", "category": "マンション", "rent_jpy": 110000, "layout": "1DK",
        "floor_area_sqm": 30, "building_year": 2015,
        "transit": [{"station_cd": 1130208, "walk_min": 3}, {"station_cd": 1130201, "walk_min": 8}],
    }
    seed_jp_demo(db, [listing])
    # Act
    filtered = search_listings(db, JpListingFilters(station_name="渋谷", layouts=("1DK",)))
    unfiltered = search_listings(db, JpListingFilters(layouts=("1DK",)))
    # Assert
    assert (filtered.items[0]["nearest_station_name"], filtered.items[0]["nearest_station_walk_min"]) == ("渋谷", 8)
    assert (unfiltered.items[0]["nearest_station_name"], unfiltered.items[0]["nearest_station_walk_min"]) == ("恵比寿", 3)


def test_jp_search_service_listing_without_info_or_transit_uses_fallbacks(db, ids):
    # Arrange: tin JP chỉ có terms (không property_info, không transit)
    base = db.get(House, ids["[SBY-OK1]"])
    bare = House(host_id=base.host_id, title="[BARE] 最小", category_id=base.category_id, price=90000,
                 status="published", images=[], amenities=[])
    db.add(bare)
    db.flush()
    db.add(JpRentalTerms(listing_id=str(bare.id), region="jp", monthly_rent_jpy=90000))
    db.commit()
    # Act
    page = search_listings(db, JpListingFilters(max_rent=90000))
    detail = get_listing_detail(db, bare.id)
    walk_only = search_listings(db, JpListingFilters(max_walk_min=60))
    # Assert
    item = page.items[0]
    assert item["layout"] == "" and item["floor_area_m2"] == 0.0 and item["nearest_station_name"] is None
    assert detail["property_info"] == {"id": 0, "layout": "", "floor_area_m2": 0} and detail["prefecture"] is None
    assert bare.id not in {i["listing_id"] for i in walk_only.items}


def test_jp_search_service_search_stations_escapes_like_wildcards(db, ids):
    # Act / Assert
    assert search_stations(db, "%") == [] and search_stations(db, "_") == []
    assert len(search_stations(db, "渋", limit=500)) == 2
