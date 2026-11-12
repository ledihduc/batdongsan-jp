"""Search tin VN cho kênh AI: lọc địa điểm/giá/phòng ngủ, không lẫn tin JP, không lộ liên hệ (Phase 13, T5, T7, AC17d)."""

from __future__ import annotations

import pytest

from tests.vn.vn_fixtures import seed_vn_fixture

from app.models import House
from app.services.ai_chat.listing_cards import CARD_KEYS
from app.services.jp.demo_seed import seed_jp_demo
from app.services.vn_search.listing_search_service import (
    VnListingFilters,
    get_vn_listing_detail,
    search_vn_listings,
)
from tests.jp.search.jp_search_fixtures import _ac3_listing, make_sqlite_session, seed_station_fixture

AC17D = VnListingFilters(location="Quận 1", max_price_vnd=20_000_000, min_bedrooms=2)


@pytest.fixture()
def db():
    session = make_sqlite_session()
    yield session
    session.close()


@pytest.fixture()
def ids(db):
    return seed_vn_fixture(db)


@pytest.fixture()
def jp_id(db, ids):
    seed_station_fixture(db)
    seed_jp_demo(db, [_ac3_listing("[JP-1] 渋谷 1LDK", 120000, "1LDK", [(1130201, 5)])])
    return db.query(House).filter(House.title.startswith("[JP-1]")).one().id


def test_vn_search_q1_price_bedrooms_returns_only_matching(db, ids):
    # Act
    page = search_vn_listings(db, AC17D)
    # Assert
    assert {i["listing_id"] for i in page.items} == {ids["[Q1-OK1]"], ids["[Q1-OK2]"]}
    assert page.total == 2


def test_vn_search_no_filter_excludes_jp_listing(db, ids, jp_id):
    # Act
    page = search_vn_listings(db, VnListingFilters(limit=20))
    # Assert
    assert jp_id not in {i["listing_id"] for i in page.items}
    assert page.total == 20
    prices = [i["price"] for i in page.items]
    assert prices == sorted(prices)


def test_vn_search_location_city_partial_matches_hanoi(db, ids):
    # Act
    page = search_vn_listings(db, VnListingFilters(location="hà nội", limit=20))
    # Assert
    assert page.total == 10
    assert {i["city"] for i in page.items} == {"Hà Nội"}


def test_vn_search_location_quan_1_does_not_match_quan_10(db, ids):
    # Act
    page = search_vn_listings(db, VnListingFilters(location="Quận 1", limit=20))
    # Assert
    assert ids["[Q10-NG-LOC]"] not in {i["listing_id"] for i in page.items}
    assert page.total == 4


def test_vn_search_category_and_sale_filters(db, ids):
    # Act
    mini = search_vn_listings(db, VnListingFilters(category="Chung cư mini", transaction_type="rent", limit=20))
    sale = search_vn_listings(db, VnListingFilters(transaction_type="sale", limit=20))
    # Assert
    assert mini.total == 3
    assert all(db.get(House, i["listing_id"]).transaction_type == "rent" for i in mini.items)
    assert sale.total == 3 and {i["city"] for i in sale.items} == {"Hà Nội"}


def test_vn_search_area_and_min_price_filters(db, ids):
    # Act
    page = search_vn_listings(db, VnListingFilters(min_area_m2=100, min_price_vnd=30_000_000, limit=20))
    # Assert
    assert all(i["area_m2"] >= 100 and i["price"] >= 30_000_000 for i in page.items)
    assert page.total == 2  # nhà Thảo Điền 180 m² 40tr, nhà Tây Hồ 150 m² 35tr


def test_vn_search_items_have_card_keys_and_vnd(db, ids):
    # Act
    item = search_vn_listings(db, AC17D).items[0]
    # Assert
    assert set(item) == set(CARD_KEYS)
    assert item["currency"] == "VND" and item["layout"] is None and item["station_name"] is None
    assert "host_phone" not in item


def test_vn_search_unpublished_listing_excluded(db, ids):
    # Arrange
    db.get(House, ids["[Q1-OK1]"]).status = "hidden"
    db.commit()
    # Act
    page = search_vn_listings(db, AC17D)
    # Assert
    assert {i["listing_id"] for i in page.items} == {ids["[Q1-OK2]"]}


def test_vn_get_listing_detail_has_no_contact_or_exact_address(db, ids):
    # Arrange
    db.get(House, ids["[Q1-OK1]"]).description = "x" * 3000
    db.commit()
    # Act
    detail = get_vn_listing_detail(db, ids["[Q1-OK1]"])
    # Assert
    assert {"address", "host_phone", "host_email"}.isdisjoint(detail)
    assert len(detail["description"]) <= 1500
    assert detail["district"] == "Quận 1" and detail["category"] == "Căn hộ" and detail["currency"] == "VND"


def test_vn_get_listing_detail_jp_listing_returns_none(db, jp_id):
    # Act / Assert
    assert get_vn_listing_detail(db, jp_id) is None


def test_vn_get_listing_detail_unknown_id_returns_none(db, ids):
    # Act / Assert
    assert get_vn_listing_detail(db, 999999) is None


@pytest.mark.parametrize("loc", ["TP. Hồ Chí Minh", "Thành phố Hồ Chí Minh", "TP.HCM", "HCM", "Sài Gòn", "Ho Chi Minh City"])
def test_vn_search_location_hcm_aliases_match_hcm(db, ids, loc):
    # Act
    page = search_vn_listings(db, VnListingFilters(location=loc, limit=20))
    # Assert (QA F1)
    assert page.total == 10 and {i["city"] for i in page.items} == {"Hồ Chí Minh"}


@pytest.mark.parametrize("loc", ["Thành phố Hà Nội", "Hanoi", "Ha Noi"])
def test_vn_search_location_hanoi_aliases_match_hanoi(db, ids, loc):
    # Act / Assert (QA F1)
    assert search_vn_listings(db, VnListingFilters(location=loc, limit=20)).total == 10


@pytest.mark.parametrize("loc", ["Quận 1, Hồ Chí Minh", "Q1", "q.1", "District 1"])
def test_vn_search_location_district_forms_match_quan_1_only(db, ids, loc):
    # Act
    page = search_vn_listings(db, VnListingFilters(location=loc, limit=20))
    # Assert (QA F1) — 4 tin Quận 1, không lẫn Quận 10
    assert page.total == 4 and ids["[Q10-NG-LOC]"] not in {i["listing_id"] for i in page.items}


def test_vn_search_location_district_with_city_suffix_requires_both(db, ids):
    # Act — "Cầu Giấy" thuộc Hà Nội; ghép với HCM ⇒ 0 tin
    page = search_vn_listings(db, VnListingFilters(location="Cầu Giấy, Hồ Chí Minh", limit=20))
    # Assert
    assert page.total == 0


def test_vn_search_location_wildcard_chars_do_not_match_everything(db, ids):
    # Act / Assert (QA F6)
    assert search_vn_listings(db, VnListingFilters(location="%", limit=20)).total == 0
    assert search_vn_listings(db, VnListingFilters(location="_", limit=20)).total == 0
