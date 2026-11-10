"""Thẻ tin của chat: chỉ tin do tool trả, dạng trung tính thị trường (Phase 08, AC7, T15)."""

from __future__ import annotations

from app.services.ai_chat.listing_cards import (
    CARD_KEYS,
    detail_to_item,
    extract_cited_ids,
    select_cards,
    to_card,
)


def test_ai_chat_cards_cited_ids_keep_only_tool_returned():
    # Arrange
    items = [{"listing_id": 1, "title": "a"}, {"listing_id": 2, "title": "b"}]
    # Act
    cards = select_cards("おすすめ [#2] と [#999]", items, items)
    # Assert
    assert [c["listing_id"] for c in cards] == [2]


def test_ai_chat_cards_no_citation_falls_back_to_last_search():
    # Arrange
    tool_items = [{"listing_id": 1}, {"listing_id": 2}, {"listing_id": 3}]
    last_search = [{"listing_id": 2}, {"listing_id": 3}]
    # Act
    cards = select_cards("条件に合う物件が見つかりました。", tool_items, last_search)
    # Assert
    assert cards == last_search


def test_ai_chat_cards_extract_cited_ids_dedupes_in_order():
    # Act / Assert
    assert extract_cited_ids("[#3][#1][#3]") == [3, 1]


def test_ai_chat_cards_cited_order_follows_reply_and_dedupes_items():
    # Arrange — cùng tin xuất hiện ở search lẫn get_listing
    items = [{"listing_id": 1}, {"listing_id": 2}, {"listing_id": 1, "title": "detail"}]
    # Act
    cards = select_cards("[#2] [#1]", items, [])
    # Assert
    assert [c["listing_id"] for c in cards] == [2, 1]


def test_ai_chat_cards_jp_item_mapped_to_neutral_card():
    # Arrange
    item = {"listing_id": 1, "title": "t", "monthly_rent": 120000, "layout": "1LDK", "floor_area_m2": 30,
            "nearest_station_name": "渋谷", "nearest_station_walk_min": 5, "thumbnail_url": None,
            "city": "渋谷区", "is_published": True}
    # Act
    card = to_card(item)
    # Assert
    assert set(card) == set(CARD_KEYS)
    assert (card["price"], card["currency"], card["station_name"], card["walk_min"]) == (120000, "JPY", "渋谷", 5)
    assert card["area_m2"] == 30 and card["bedrooms"] is None and card["layout"] == "1LDK"


def test_ai_chat_cards_item_with_currency_keeps_card_keys_only():
    # Arrange — dạng VN (Phase 13) đã có sẵn khoá trung tính
    item = {"listing_id": 9, "price": 5_000_000, "currency": "VND", "bedrooms": 2, "secret": "x"}
    # Act
    card = to_card(item)
    # Assert
    assert set(card) == set(CARD_KEYS)
    assert (card["price"], card["currency"], card["bedrooms"], card["title"]) == (5_000_000, "VND", 2, None)


def test_ai_chat_cards_listing_detail_flattened_to_summary_item():
    # Arrange — payload `get_listing` lồng nhau
    detail = {"listing_id": 4, "title": "d", "rental_terms": {"monthly_rent": 99000},
              "property_info": {"layout": "1K", "floor_area_m2": 22.5},
              "transit_accesses": [{"station": {"name": "新宿"}, "walk_minutes": 7}],
              "image_urls": ["https://x/1.jpg"], "city": "新宿区"}
    # Act
    card = to_card(detail_to_item(detail))
    # Assert
    assert (card["listing_id"], card["price"], card["layout"], card["area_m2"]) == (4, 99000, "1K", 22.5)
    assert (card["station_name"], card["walk_min"], card["thumbnail_url"]) == ("新宿", 7, "https://x/1.jpg")
