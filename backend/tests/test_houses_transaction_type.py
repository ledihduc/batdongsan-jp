"""Tests for listing v2 — transaction_type, auto-publish, status=approved alias.

Uses SQLite in-memory + TestClient (no real Postgres required).
Mirrors the pattern in tests/api/test_admin_routes.py.
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
import app.models  # noqa: F401 — register ORM classes
from app.routers.houses import router as houses_router
from app.auth import sign_token


def _make_app() -> FastAPI:
    app = FastAPI()
    app.include_router(houses_router)
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
def host_token() -> str:
    return sign_token(user_id=10, role="host")


@pytest.fixture
def guest_token() -> str:
    return sign_token(user_id=20, role="guest")


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _make_category(db: Session) -> int:
    from app.models import Category
    cat = Category(name="Test Category", icon="home")
    db.add(cat)
    db.flush()
    return cat.id


def _make_user(db: Session, role: str = "host", uid: int = 10) -> None:
    """Ensure a user + HostProfile exist (HostProfile prevents buggy auto-create path)."""
    from app.models import User, HostProfile
    existing = db.get(User, uid)
    if not existing:
        u = User(
            id=uid,
            name="Test Host",
            email=f"host_{uid}_{uuid.uuid4().hex[:4]}@test.com",
            password_hash="hashed",
            role=role,
        )
        db.add(u)
        db.flush()
    # Pre-seed HostProfile so repo.get_by_user_id() finds it and skips the buggy create path.
    hp_exists = db.query(HostProfile).filter(HostProfile.user_id == uid).first()
    if not hp_exists:
        hp = HostProfile(user_id=uid)
        db.add(hp)
        db.flush()


def _post_house(client, token: str, extras: dict | None = None) -> dict:
    payload = {
        "title": "Test House",
        "description": "desc",
        "category_id": 1,
        "price": 3_000_000.0,
        "area": 20.0,
        "city": "Hà Nội",
        "address": "123 Phố Huế",
    }
    if extras:
        payload.update(extras)
    return client.post("/api/houses", json=payload, headers=_auth(token))


# ─── Tests ───────────────────────────────────────────────────────────────────


class TestAutoPublish:
    """POST /api/houses without status → status='published'."""

    def test_default_status_is_published(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        resp = _post_house(client, host_token, {"category_id": cat_id})
        assert resp.status_code == 201, resp.text
        data = resp.json()
        assert data["house"]["status"] == "published"

    def test_default_transaction_type_is_rent(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        resp = _post_house(client, host_token, {"category_id": cat_id})
        assert resp.status_code == 201, resp.text
        assert resp.json()["house"]["transaction_type"] == "rent"


class TestTransactionType:
    """POST with transaction_type='sale' → row saved with sale."""

    def test_post_with_sale_type(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        resp = _post_house(client, host_token, {
            "category_id": cat_id,
            "transaction_type": "sale",
        })
        assert resp.status_code == 201, resp.text
        assert resp.json()["house"]["transaction_type"] == "sale"

    def test_post_with_invalid_type_defaults_to_rent(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        resp = _post_house(client, host_token, {
            "category_id": cat_id,
            "transaction_type": "barter",
        })
        assert resp.status_code == 201, resp.text
        assert resp.json()["house"]["transaction_type"] == "rent"


class TestStatusApprovedAlias:
    """GET /api/houses?status=approved returns published rows (D3 alias)."""

    def test_approved_alias_returns_published_rows(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        # Post a house (gets status=published automatically)
        _post_house(client, host_token, {"category_id": cat_id})

        # Query with status=approved → should return published rows
        resp = client.get("/api/houses?status=approved")
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["total"] >= 1
        for h in data["houses"]:
            assert h["status"] == "published"

    def test_status_published_also_works(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        _post_house(client, host_token, {"category_id": cat_id})

        resp = client.get("/api/houses?status=published")
        assert resp.status_code == 200, resp.text
        assert resp.json()["total"] >= 1


class TestTransactionTypeFilter:
    """GET /api/houses?transaction_type=rent returns only rent listings."""

    def test_filter_by_rent(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        _post_house(client, host_token, {"category_id": cat_id, "transaction_type": "rent"})
        _post_house(client, host_token, {"category_id": cat_id, "transaction_type": "sale"})

        resp = client.get("/api/houses?transaction_type=rent")
        assert resp.status_code == 200, resp.text
        houses = resp.json()["houses"]
        assert all(h["transaction_type"] == "rent" for h in houses)

    def test_filter_by_sale(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        _post_house(client, host_token, {"category_id": cat_id, "transaction_type": "sale"})

        resp = client.get("/api/houses?transaction_type=sale")
        assert resp.status_code == 200, resp.text
        houses = resp.json()["houses"]
        assert all(h["transaction_type"] == "sale" for h in houses)

    def test_no_filter_returns_all_published(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        _post_house(client, host_token, {"category_id": cat_id, "transaction_type": "rent"})
        _post_house(client, host_token, {"category_id": cat_id, "transaction_type": "sale"})

        resp = client.get("/api/houses")
        assert resp.status_code == 200, resp.text
        assert resp.json()["total"] >= 2


class TestWardSlug:
    """POST and GET with ward_slug."""

    def test_post_with_ward_slug(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        resp = _post_house(client, host_token, {
            "category_id": cat_id,
            "ward_slug": "phuong-truc-bach",
            "ward_slug_legacy": "phuong-truc-bach-hoan-kiem-ha-noi",
        })
        assert resp.status_code == 201, resp.text
        house = resp.json()["house"]
        assert house["ward_slug"] == "phuong-truc-bach"
        assert house["ward_slug_legacy"] == "phuong-truc-bach-hoan-kiem-ha-noi"

    def test_filter_by_ward_slug(self, client, db_session, host_token):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        _post_house(client, host_token, {
            "category_id": cat_id,
            "ward_slug": "phuong-ba-dinh",
        })
        # Another house without ward
        _post_house(client, host_token, {"category_id": cat_id})

        resp = client.get("/api/houses?ward_slug=phuong-ba-dinh")
        assert resp.status_code == 200, resp.text
        houses = resp.json()["houses"]
        assert len(houses) >= 1
        for h in houses:
            assert h["ward_slug"] == "phuong-ba-dinh" or h.get("ward_slug_legacy") == "phuong-ba-dinh"


class TestPutStatusIgnored:
    """H1 regression: PUT /api/houses/{id} must NOT let the host mutate `status`.

    Status transitions are moderation-only. A host who owns a rejected/hidden
    listing must not be able to re-publish it by sending {"status": "published"}
    in a PUT body — that would silently defeat admin moderation.
    """

    def _create_rejected_house(self, client, db_session, token, cat_id):
        # Create via POST (auto-publish → status='published'), then mutate the
        # ORM row directly to 'rejected' to simulate admin action.
        resp = _post_house(client, token, {"category_id": cat_id})
        assert resp.status_code == 201, resp.text
        house_id = resp.json()["house"]["id"]
        from app.models import House
        row = db_session.get(House, house_id)
        row.status = "rejected"
        db_session.flush()
        db_session.commit()
        return house_id

    def test_put_status_published_on_rejected_is_ignored(
        self, client, db_session, host_token
    ):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        house_id = self._create_rejected_house(client, db_session, host_token, cat_id)

        # Host tries to re-publish via PUT with status='published' in the body.
        resp = client.put(
            f"/api/houses/{house_id}",
            json={"title": "Same title", "status": "published"},
            headers=_auth(host_token),
        )
        assert resp.status_code == 200, resp.text

        from app.models import House
        db_session.expire_all()
        row = db_session.get(House, house_id)
        assert row.status == "rejected", (
            "PUT must not honor client-supplied status — this is the H1 fix."
        )

    def test_put_other_fields_still_editable_on_rejected(
        self, client, db_session, host_token
    ):
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        house_id = self._create_rejected_house(client, db_session, host_token, cat_id)

        resp = client.put(
            f"/api/houses/{house_id}",
            json={"title": "Edited after rejection"},
            headers=_auth(host_token),
        )
        assert resp.status_code == 200, resp.text

        from app.models import House
        db_session.expire_all()
        row = db_session.get(House, house_id)
        assert row.title == "Edited after rejection"
        assert row.status == "rejected"


class TestSalePostModeration:
    """Hậu kiểm tin BÁN (26/07/2026).

    Bug cũ: ngưỡng tiền kiểm 2 tỷ chặn ~100% tin bán thật (giá nhà VN 2–10 tỷ)
    → tin vào hàng chờ, không ai duyệt, chủ nhà tưởng app lỗi. Nay chỉ tiền kiểm
    khi giá >= 50 tỷ HOẶC tài khoản từng có tin bị từ chối.
    """

    def test_sale_gia_thuong_len_ngay(self, client, db_session, host_token):
        """2 tỷ (giá nhà phổ biến) PHẢI published ngay — đây chính là bug cũ."""
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        resp = _post_house(client, host_token, {
            "category_id": cat_id,
            "transaction_type": "sale",
            "price": 2_000_000_000.0,
        })
        assert resp.status_code == 201, resp.text
        assert resp.json()["house"]["status"] == "published"

    def test_sale_gia_di_thuong_vao_hang_cho(self, client, db_session, host_token):
        """>= 50 tỷ → vẫn tiền kiểm (chống tin giá ảo / nhập sai đơn vị)."""
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        resp = _post_house(client, host_token, {
            "category_id": cat_id,
            "transaction_type": "sale",
            "price": 60_000_000_000.0,
        })
        assert resp.status_code == 201, resp.text
        assert resp.json()["house"]["status"] == "pending_review"

    def test_tai_khoan_tung_bi_tu_choi_thi_tien_kiem(
        self, client, db_session, host_token
    ):
        """Tái phạm: đã có tin bị từ chối → tin bán mới phải qua duyệt."""
        from app.models import House
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        db_session.add(House(
            host_id=10, title="tin cũ bị từ chối", description="", category_id=cat_id,
            price=1.0, area=1.0, address="", city="", district="",
            status="rejected", transaction_type="sale",
        ))
        db_session.flush()
        resp = _post_house(client, host_token, {
            "category_id": cat_id,
            "transaction_type": "sale",
            "price": 3_000_000_000.0,
        })
        assert resp.status_code == 201, resp.text
        assert resp.json()["house"]["status"] == "pending_review"

    def test_tin_thue_khong_bi_anh_huong(self, client, db_session, host_token):
        """Tin CHO THUÊ không bao giờ đi qua nhánh tiền kiểm giá."""
        _make_user(db_session, uid=10)
        cat_id = _make_category(db_session)
        resp = _post_house(client, host_token, {
            "category_id": cat_id,
            "transaction_type": "rent",
            "price": 99_000_000_000.0,
        })
        assert resp.status_code == 201, resp.text
        assert resp.json()["house"]["status"] == "published"
