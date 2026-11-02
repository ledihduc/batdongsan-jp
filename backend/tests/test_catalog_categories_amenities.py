"""Tests for GET /api/categories + GET /api/amenities (app.routers.catalog).

App gọi 2 route này lúc mở feed (`house_provider.fetchInitialData`) và form đăng
tin / nhu cầu; đọc `response['categories']` / `response['amenities']`, mỗi phần
tử dùng `id`, `name`, `icon`, `group_key`.

Uses SQLite in-memory + TestClient (no real Postgres required).
"""

from __future__ import annotations

import os
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app import models
from app.database import Base, get_db
from app.routers.catalog import router as catalog_router


@pytest.fixture()
def db() -> Generator[Session, None, None]:
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture()
def client(db: Session) -> TestClient:
    app = FastAPI()
    app.include_router(catalog_router)
    app.dependency_overrides[get_db] = lambda: db
    return TestClient(app)


def test_catalog_categories_returns_only_active_sorted_by_sort_order(db, client):
    # Arrange
    db.add_all([
        models.Category(id=1, name="Căn hộ", icon="apartment", group_key="stay_long", sort_order=2),
        models.Category(id=2, name="Villa", icon="villa", group_key="stay_short", sort_order=1),
        models.Category(id=3, name="Penthouse", icon="x", group_key="stay_long", sort_order=0, is_active=False),
    ])
    db.commit()

    # Act
    res = client.get("/api/categories")

    # Assert
    assert res.status_code == 200
    cats = res.json()["categories"]
    assert [c["id"] for c in cats] == [2, 1]
    assert cats[0] == {"id": 2, "name": "Villa", "icon": "villa", "group_key": "stay_short", "sort_order": 1}


def test_catalog_categories_empty_table_returns_empty_list(client):
    # Act
    res = client.get("/api/categories")

    # Assert
    assert res.status_code == 200
    assert res.json() == {"categories": []}


def test_catalog_amenities_returns_all_sorted_by_id(db, client):
    # Arrange
    db.add_all([
        models.Amenity(id=2, name="Hồ bơi", icon="pool"),
        models.Amenity(id=1, name="Wifi 5G", icon="wifi"),
    ])
    db.commit()

    # Act
    res = client.get("/api/amenities")

    # Assert
    assert res.status_code == 200
    assert res.json() == {"amenities": [
        {"id": 1, "name": "Wifi 5G", "icon": "wifi"},
        {"id": 2, "name": "Hồ bơi", "icon": "pool"},
    ]}


def test_catalog_amenities_empty_table_returns_empty_list(client):
    # Act
    res = client.get("/api/amenities")

    # Assert
    assert res.status_code == 200
    assert res.json() == {"amenities": []}
