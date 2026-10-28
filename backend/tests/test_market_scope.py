"""Tách dữ liệu 2 thị trường bằng code (plan 20261027-1102, Phase 03 — AC17(e), T14).

`/api/categories`, `/api/houses`, `/api/search` kiểm qua route (DB đủ bảng);
`scope_houses` kiểm thêm ở mức query.
"""

from __future__ import annotations

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config import settings
from app.database import get_db
from app.domain.jp.rental_terms import JpRentalTerms
from app.models import Category, House
from app.routers.catalog import router as catalog_router
from app.routers.houses import router as houses_router
from app.routers.search import router as search_router
from app.services.jp.demo_seed import seed_jp_demo
from app.services.market_scope import JP_CATEGORY_NAMES, scope_houses
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_station_fixture

_JP_LISTING = {
    "title": "渋谷 1LDK（デモ）", "description": "（デモデータ）", "city": "渋谷区", "address": "渋谷区神南1丁目",
    "category": "マンション", "rent_jpy": 120000, "layout": "1LDK",
    "transit": [{"station_cd": 1130201, "walk_min": 5}],
}


@pytest.fixture()
def db():
    session = make_sqlite_session(all_tables=True)
    seed_station_fixture(session)
    session.add(Category(name="Căn hộ", is_active=True, sort_order=0))
    session.commit()
    yield session
    session.close()


@pytest.fixture()
def ids(db) -> dict[str, int]:
    seed_jp_demo(db, [_JP_LISTING])
    jp_id = db.query(House).filter(House.title == _JP_LISTING["title"]).one().id
    vn = House(host_id=999, title="Căn hộ 1LDK Quận 1", category_id=1, price=8_000_000, status="published")
    db.add(vn)
    db.flush()
    # Nhiễu cho jp_listing_exists: terms region khác 'jp' và terms chưa gắn tin (NULL).
    db.add_all([
        JpRentalTerms(listing_id=str(vn.id), region="vn", monthly_rent_jpy=1, tax_treatment="included"),
        JpRentalTerms(listing_id=None, region="jp", monthly_rent_jpy=1, tax_treatment="included"),
    ])
    db.commit()
    return {"jp": jp_id, "vn": vn.id}


@pytest.fixture()
def client(db) -> TestClient:
    app = FastAPI()
    for router in (catalog_router, houses_router, search_router):
        app.include_router(router)
    app.dependency_overrides[get_db] = lambda: db
    return TestClient(app)


def _category_names(client: TestClient) -> list[str]:
    res = client.get("/api/categories")
    assert res.status_code == 200
    return [c["name"] for c in res.json()["categories"]]


def test_market_scope_jp_categories_only_japanese_names(client, ids, monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "demo_market_scope", True)
    monkeypatch.setattr(settings, "region", "jp")

    # Act
    names = _category_names(client)

    # Assert
    # seed_jp_demo tạo đủ 5 loại hình JP (sort_order theo JP_CATEGORY_NAMES)
    assert names == list(JP_CATEGORY_NAMES)


def test_market_scope_vn_categories_exclude_japanese_names(client, ids, monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "demo_market_scope", True)
    monkeypatch.setattr(settings, "region", "vn")

    # Act
    names = _category_names(client)

    # Assert
    assert names == ["Căn hộ"]


def test_market_scope_off_keeps_old_categories(client, ids, monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "demo_market_scope", False)
    monkeypatch.setattr(settings, "region", "jp")

    # Act
    names = _category_names(client)

    # Assert
    assert sorted(names) == sorted(["Căn hộ", *JP_CATEGORY_NAMES])


def test_market_scope_jp_houses_only_jp_listings(db, ids):
    # Act
    got = {h.id for h in scope_houses(db.query(House), "jp")}

    # Assert
    assert got == {ids["jp"]}


def test_market_scope_vn_houses_exclude_jp_listings(db, ids):
    # Act
    got = {h.id for h in scope_houses(db.query(House), "vn")}

    # Assert
    assert got == {ids["vn"]}


def _house_ids(client: TestClient, url: str) -> set[int]:
    res = client.get(url)
    assert res.status_code == 200, res.text
    return {h["id"] for h in res.json()["houses"]}


@pytest.mark.parametrize("region", ["jp", "vn"])
def test_market_scope_houses_route_returns_only_current_market(client, ids, monkeypatch, region):
    # Arrange
    monkeypatch.setattr(settings, "demo_market_scope", True)
    monkeypatch.setattr(settings, "region", region)

    # Act
    got = _house_ids(client, "/api/houses?limit=50")

    # Assert
    assert got == {ids[region]}


@pytest.mark.parametrize("region", ["jp", "vn"])
def test_market_scope_search_route_returns_only_current_market(client, ids, monkeypatch, region):
    # Arrange — "1LDK" khớp tiêu đề cả tin JP lẫn tin VN
    monkeypatch.setattr(settings, "demo_market_scope", True)
    monkeypatch.setattr(settings, "region", region)

    # Act
    got = _house_ids(client, "/api/search?q=1LDK")

    # Assert
    assert got == {ids[region]}


def test_market_scope_off_search_route_returns_both_markets(client, ids, monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "demo_market_scope", False)

    # Act
    got = _house_ids(client, "/api/search?q=1LDK")

    # Assert
    assert got == {ids["jp"], ids["vn"]}
