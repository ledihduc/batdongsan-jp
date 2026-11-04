"""GET /api/jp/listings + /api/jp/listings/{id} — AC3, AC4 (plan 20261027-1102 Phase 04).

SQLite in-memory + bộ tin AC3 (`seed_search_fixture`); không cần Postgres.
"""

from __future__ import annotations

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

import pytest
from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.testclient import TestClient
from starlette.exceptions import HTTPException as StarletteHTTPException

import app.config
from app.api.routes.jp import listing_search
from app.database import get_db
from app.middleware.error_handler import http_exception_handler, validation_handler
from app.models import User
from app.services.jp.demo_seed import DEMO_HOST_EMAIL
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture

FLUTTER_DETAIL_KEYS = {
    "listing_id", "title", "rental_terms", "property_info", "transit_accesses", "description",
    "image_urls", "host_name", "prefecture", "city", "address", "is_published",
}
SUMMARY_KEYS = {
    "listing_id", "title", "monthly_rent", "layout", "floor_area_m2", "nearest_station_name",
    "nearest_station_walk_min", "thumbnail_url", "city", "is_published",
}


@pytest.fixture()
def db():
    session = make_sqlite_session()
    yield session
    session.close()


@pytest.fixture()
def ids(db) -> dict[str, int]:
    return seed_search_fixture(db)


@pytest.fixture()
def st(ids) -> dict[str, int]:
    return ids


@pytest.fixture()
def client(db, monkeypatch) -> TestClient:
    monkeypatch.setattr(app.config.settings, "region", "jp")
    api = FastAPI()
    api.include_router(listing_search.router)
    api.add_exception_handler(RequestValidationError, validation_handler)
    api.add_exception_handler(StarletteHTTPException, http_exception_handler)
    api.dependency_overrides[get_db] = lambda: db
    return TestClient(api)


def _ids_of(res) -> set[int]:
    return {i["listing_id"] for i in res.json()["items"]}


def test_jp_listing_search_all_conditions_returns_only_matching(client, ids, st):
    # Act
    res = client.get("/api/jp/listings", params={
        "max_rent": 150000, "layouts": "1LDK", "station_id": st["shibuya_yamanote"],
        "max_walk_min": 10, "page_size": 10,
    })
    # Assert
    assert res.status_code == 200
    assert _ids_of(res) == {ids["[SBY-OK1]"], ids["[SBY-OK2]"], ids["[SBY-OK3]"]}
    for i in res.json()["items"]:
        assert SUMMARY_KEYS <= i.keys()
        assert i["monthly_rent"] <= 150000 and i["layout"] == "1LDK"
        assert i["nearest_station_name"] == "渋谷" and i["nearest_station_walk_min"] <= 10
    assert [i["monthly_rent"] for i in res.json()["items"]] == [120000, 145000, 150000]


def test_jp_listing_search_walk_without_station_filters_any_station(client, ids):
    # Act
    res = client.get("/api/jp/listings", params={"max_walk_min": 5, "page_size": 50})
    # Assert
    assert res.status_code == 200
    assert _ids_of(res) == {ids["[SBY-OK1]"], ids["[SBY-NG-LAYOUT]"], ids["[EBS-NG-STATION]"]}
    assert all(i["nearest_station_walk_min"] <= 5 for i in res.json()["items"])


def test_jp_listing_search_no_match_returns_empty_items(client, ids):
    # Act
    res = client.get("/api/jp/listings", params={"max_rent": 1000})
    # Assert
    assert res.status_code == 200
    assert res.json()["items"] == [] and res.json()["total"] == 0


def test_jp_listing_search_no_params_returns_only_published_jp(client, ids):
    # Act
    res = client.get("/api/jp/listings")
    # Assert
    body = res.json()
    assert res.status_code == 200
    assert body["total"] == 7 and body["page"] == 1 and body["page_size"] == 20
    assert ids["[SBY-DRAFT]"] not in _ids_of(res) and ids["[NON-JP]"] not in _ids_of(res)
    assert body["ignored_filters"] == []


def test_jp_listing_search_pagination_splits_pages(client, ids):
    # Act
    first = client.get("/api/jp/listings", params={"page": 1, "page_size": 5})
    second = client.get("/api/jp/listings", params={"page": 2, "page_size": 5})
    # Assert
    assert len(first.json()["items"]) == 5 and len(second.json()["items"]) == 2
    assert first.json()["total"] == second.json()["total"] == 7
    assert not (_ids_of(first) & _ids_of(second))


def test_jp_listing_search_non_integer_max_rent_returns_422(client, ids):
    # Act
    res = client.get("/api/jp/listings", params={"max_rent": "abc"})
    # Assert
    assert res.status_code == 422 and res.json()["error"]["code"] == "VALIDATION_ERROR"


def test_jp_listing_search_unknown_layout_returns_422(client, ids):
    # Act
    res = client.get("/api/jp/listings", params={"layouts": "1LDK,5SLDK"})
    # Assert
    assert res.status_code == 422 and res.json()["error"]["code"] == "VALIDATION_ERROR"
    assert "5SLDK" in res.json()["error"]["message"]


def test_jp_listing_search_page_size_zero_returns_422(client, ids):
    # Act
    res = client.get("/api/jp/listings", params={"page_size": 0})
    # Assert
    assert res.status_code == 422 and res.json()["error"]["code"] == "VALIDATION_ERROR"


def test_jp_listing_search_unsupported_flags_accepted_not_filtered(client, ids):
    # Act
    plain = client.get("/api/jp/listings")
    flagged = client.get("/api/jp/listings", params={"pets_ok": "true"})
    # Assert
    assert flagged.status_code == 200
    assert flagged.json()["total"] == plain.json()["total"]
    assert flagged.json()["ignored_filters"] == ["pets_ok"]


def test_jp_listing_search_region_vn_returns_404(client, ids, monkeypatch):
    # Arrange
    monkeypatch.setattr(app.config.settings, "region", "vn")
    # Act
    res = client.get("/api/jp/listings")
    # Assert
    assert res.status_code == 404


def test_jp_listing_detail_returns_fields_read_by_flutter(client, ids):
    # Act
    res = client.get(f"/api/jp/listings/{ids['[SBY-OK2]']}")
    # Assert
    body = res.json()
    assert res.status_code == 200 and FLUTTER_DETAIL_KEYS <= body.keys()
    assert isinstance(body["listing_id"], int) and isinstance(body["rental_terms"]["monthly_rent"], int)
    assert body["rental_terms"]["monthly_rent"] == 145000 and body["rental_terms"]["tax_included"] is True
    assert {"id", "layout", "floor_area_m2"} <= body["property_info"].keys()
    t = body["transit_accesses"][0]
    assert isinstance(t["listing_id"], int) and {"id", "name"} <= t["station"].keys()
    assert isinstance(t["walk_minutes"], int) and t["station"]["line_name"] == "東京メトロ銀座線"
    assert body["prefecture"] == "東京都" and body["is_published"] is True


def test_jp_listing_detail_omits_host_phone_and_email(client, db, ids):
    # Arrange
    host = db.query(User).filter(User.email == DEMO_HOST_EMAIL).one()
    host.phone = "090-1234-5678"
    db.commit()
    # Act
    res = client.get(f"/api/jp/listings/{ids['[SBY-OK1]']}")
    # Assert
    assert res.status_code == 200
    assert "090-1234-5678" not in res.text and DEMO_HOST_EMAIL not in res.text
    assert not {"host_phone", "host_email", "phone", "email"} & res.json().keys()


@pytest.mark.parametrize("key", ["[SBY-DRAFT]", "[NON-JP]"])
def test_jp_listing_detail_draft_or_non_jp_returns_404(client, ids, key):
    # Act
    res = client.get(f"/api/jp/listings/{ids[key]}")
    # Assert
    assert res.status_code == 404


def test_jp_listing_detail_unknown_id_returns_404(client, ids):
    # Act
    res = client.get("/api/jp/listings/999999")
    # Assert
    assert res.status_code == 404


def test_jp_listing_search_walk_zero_means_no_limit(client, ids):
    # Arrange: drawer Flutter gửi max_walk_min=0 khi chọn 制限なし (QA H1)
    plain = client.get("/api/jp/listings")
    # Act
    res = client.get("/api/jp/listings", params={"max_walk_min": 0})
    # Assert
    assert res.status_code == 200 and res.json()["total"] == plain.json()["total"] == 7


def test_jp_listing_search_walk_above_sixty_returns_422(client, ids):
    # Act
    res = client.get("/api/jp/listings", params={"max_walk_min": 61})
    # Assert
    assert res.status_code == 422 and res.json()["error"]["code"] == "VALIDATION_ERROR"


@pytest.mark.parametrize("page", [1001, "99999999999999999999"])
def test_jp_listing_search_huge_page_returns_422_not_500(client, ids, page):
    # Act (QA M1: OFFSET tràn bigint trên Postgres)
    res = client.get("/api/jp/listings", params={"page": page})
    # Assert
    assert res.status_code == 422


def test_jp_listing_detail_with_duplicate_terms_uses_oldest_row(client, db, ids):
    # Arrange: dòng terms thứ hai cho cùng tin (QA M2 — chưa có unique trên listing_id)
    from app.domain.jp.rental_terms import JpRentalTerms

    db.add(JpRentalTerms(listing_id=str(ids["[SBY-OK1]"]), region="jp", monthly_rent_jpy=99000))
    db.commit()
    # Act
    res = client.get(f"/api/jp/listings/{ids['[SBY-OK1]']}")
    # Assert
    assert res.status_code == 200 and res.json()["rental_terms"]["monthly_rent"] == 120000
