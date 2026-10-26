"""Tests for PATCH /api/admin/houses/{id}/trusted endpoint.

Uses SQLite in-memory + TestClient. Mirrors pattern from test_admin_routes.py.
"""

from __future__ import annotations

import os
import uuid
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from app.database import Base, get_db
import app.models  # noqa: F401
from app.routers.houses import router as houses_router
from app.routers.admin_houses import router as admin_houses_router
from app.auth import sign_token


def _make_app() -> FastAPI:
    app = FastAPI()
    app.include_router(houses_router)
    app.include_router(admin_houses_router)
    return app


@pytest.fixture(scope="module")
def sqlite_engine():
    _engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=_engine)
    yield _engine
    _engine.dispose()


@pytest.fixture
def db_session(sqlite_engine) -> Generator[Session, None, None]:
    connection = sqlite_engine.connect()
    transaction = connection.begin()
    _Session = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = _Session()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session: Session) -> Generator[TestClient, None, None]:
    _app = _make_app()

    def _override_db() -> Generator[Session, None, None]:
        yield db_session

    _app.dependency_overrides[get_db] = _override_db
    with TestClient(_app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture
def admin_token() -> str:
    return sign_token(user_id=999, role="admin")


@pytest.fixture
def host_token() -> str:
    return sign_token(user_id=10, role="host")


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _make_user(db: Session, uid: int, role: str = "host") -> None:
    from app.models import User, HostProfile
    existing = db.get(User, uid)
    if not existing:
        u = User(
            id=uid,
            name=f"User {uid}",
            email=f"user_{uid}_{uuid.uuid4().hex[:4]}@test.com",
            password_hash="hashed",
            role=role,
        )
        db.add(u)
        db.flush()
    # Pre-seed HostProfile to skip buggy auto-create path in POST /api/houses.
    hp_exists = db.query(HostProfile).filter(HostProfile.user_id == uid).first()
    if not hp_exists:
        hp = HostProfile(user_id=uid)
        db.add(hp)
        db.flush()


def _make_category(db: Session) -> int:
    from app.models import Category
    cat = Category(name="Test Category", icon="home")
    db.add(cat)
    db.flush()
    return cat.id


def _seed_house(db: Session, host_id: int) -> int:
    """Directly insert a house into DB (bypassing HTTP for isolation)."""
    from app.models import House
    _make_user(db, uid=host_id)
    cat_id = _make_category(db)
    h = House(
        host_id=host_id,
        title="Test House for Trusted",
        description="desc",
        category_id=cat_id,
        price=5_000_000.0,
        area=25.0,
        city="Hà Nội",
        status="published",
    )
    db.add(h)
    db.flush()
    return h.id


# ─── Tests ───────────────────────────────────────────────────────────────────


class TestAdminTrustedAuth:
    """Endpoint requires admin role."""

    def test_non_admin_returns_403(self, client, db_session, host_token):
        house_id = _seed_house(db_session, host_id=10)
        resp = client.patch(
            f"/api/admin/houses/{house_id}/trusted",
            json={"is_trusted": True},
            headers=_auth(host_token),
        )
        assert resp.status_code == 403, resp.text

    def test_unauthenticated_returns_401(self, client, db_session):
        house_id = _seed_house(db_session, host_id=10)
        resp = client.patch(
            f"/api/admin/houses/{house_id}/trusted",
            json={"is_trusted": True},
        )
        assert resp.status_code == 401, resp.text


class TestAdminTrustedToggle:
    """Admin can toggle is_trusted; sets/clears trusted_at and trusted_by_admin_id."""

    def test_false_to_true_sets_trusted_at_and_admin_id(
        self, client, db_session, admin_token
    ):
        house_id = _seed_house(db_session, host_id=10)
        resp = client.patch(
            f"/api/admin/houses/{house_id}/trusted",
            json={"is_trusted": True},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["id"] == house_id
        assert data["is_trusted"] is True
        assert data["trusted_at"] is not None
        assert data["trusted_by_admin_id"] == 999  # admin JWT sub

    def test_true_to_false_clears_trusted_fields(
        self, client, db_session, admin_token
    ):
        house_id = _seed_house(db_session, host_id=10)
        # First set trusted
        client.patch(
            f"/api/admin/houses/{house_id}/trusted",
            json={"is_trusted": True},
            headers=_auth(admin_token),
        )
        # Then unset
        resp = client.patch(
            f"/api/admin/houses/{house_id}/trusted",
            json={"is_trusted": False},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["is_trusted"] is False
        assert data["trusted_at"] is None
        assert data["trusted_by_admin_id"] is None

    def test_missing_is_trusted_field_returns_422(
        self, client, db_session, admin_token
    ):
        house_id = _seed_house(db_session, host_id=10)
        resp = client.patch(
            f"/api/admin/houses/{house_id}/trusted",
            json={"some_other": True},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 422, resp.text

    def test_not_found_returns_404(self, client, db_session, admin_token):
        resp = client.patch(
            "/api/admin/houses/99999/trusted",
            json={"is_trusted": True},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 404, resp.text


class TestIsTrustedFilter:
    """GET /api/houses?is_trusted=true returns only trusted listings."""

    def test_filter_trusted_true(self, client, db_session, admin_token, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        from app.models import House

        # Create two houses
        h1 = House(
            host_id=10, title="Trusted House", category_id=cat_id,
            price=4_000_000, area=20, status="published", is_trusted=True,
        )
        h2 = House(
            host_id=10, title="Normal House", category_id=cat_id,
            price=3_000_000, area=18, status="published", is_trusted=False,
        )
        db_session.add(h1)
        db_session.add(h2)
        db_session.flush()

        resp = client.get("/api/houses?is_trusted=true")
        assert resp.status_code == 200, resp.text
        houses = resp.json()["houses"]
        assert all(h["is_trusted"] is True for h in houses)
        assert any(h["title"] == "Trusted House" for h in houses)

    def test_filter_trusted_false(self, client, db_session):
        resp = client.get("/api/houses?is_trusted=false")
        assert resp.status_code == 200, resp.text
        houses = resp.json()["houses"]
        assert all(h["is_trusted"] is False for h in houses)
