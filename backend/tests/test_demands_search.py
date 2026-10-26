"""Tìm kiếm trong danh sách tin NHU CẦU (GET /api/demands?q=).

Ô tìm ở tab "Tìm khách" trước đây gõ gì cũng không đổi kết quả vì API không có
tham số tìm. Test khoá lại ba điều: tìm được theo KHU VỰC, theo GHI CHÚ, và
KHÔNG phá các bộ lọc khác khi dùng chung.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.database import Base, get_db
import app.models  # noqa: F401
from app.domain.demand_post import DemandPost


def _make_app() -> FastAPI:
    from app.api.routes.demand import router

    app = FastAPI()
    app.include_router(router)
    return app


@pytest.fixture(scope="module")
def engine():
    e = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=e)
    yield e
    e.dispose()


@pytest.fixture
def db(engine) -> Generator[Session, None, None]:
    conn = engine.connect()
    tx = conn.begin()
    s = sessionmaker(bind=conn, autoflush=False, autocommit=False)()
    yield s
    s.close()
    tx.rollback()
    conn.close()


@pytest.fixture
def client(db) -> Generator[TestClient, None, None]:
    app = _make_app()
    def _override() -> Generator[Session, None, None]:
        yield db

    app.dependency_overrides[get_db] = _override
    with TestClient(app) as c:
        yield c


def _seed(db: Session) -> None:
    from app.models import User

    u = User(
        id=1,
        name="A",
        email=f"a_{uuid.uuid4().hex[:6]}@t.com",
        password_hash="x",
        role="guest",
    )
    db.add(u)
    db.flush()

    now = datetime.utcnow()
    for kind, tinh, khu, note in [
        ("rent", "Thanh Hóa", "Sầm Sơn, Thanh Hóa", "Cần gần biển, có chỗ để xe"),
        ("rent", "Hà Nội", "Cầu Giấy, Hà Nội", "Nuôi một mèo nhỏ, ở sạch sẽ"),
        ("buy", "Đà Nẵng", "Hải Châu, Đà Nẵng", "Mua để ở lâu dài, sổ hồng riêng"),
    ]:
        db.add(
            DemandPost(
                user_id=1,
                kind=kind,
                province_name=tinh,
                area_label=khu,
                note=note,
                status="open",
                expires_at=now + timedelta(days=30),
                created_at=now,
            )
        )
    db.flush()


def _labels(resp) -> list[str]:
    return [r["area_label"] for r in resp.json()]


def test_khong_truyen_q_thi_tra_het(client, db):
    _seed(db)
    r = client.get("/api/demands")
    assert r.status_code == 200
    assert len(r.json()) == 3


def test_tim_theo_khu_vuc(client, db):
    _seed(db)
    r = client.get("/api/demands", params={"q": "Sầm Sơn"})
    assert _labels(r) == ["Sầm Sơn, Thanh Hóa"]


def test_tim_theo_ghi_chu(client, db):
    _seed(db)
    r = client.get("/api/demands", params={"q": "mèo"})
    assert _labels(r) == ["Cầu Giấy, Hà Nội"]


def test_tim_cong_don_voi_loc_theo_loai(client, db):
    _seed(db)
    # "Đà Nẵng" khớp 1 tin CẦN MUA; lọc kind=rent phải ra rỗng chứ không bỏ qua.
    r = client.get("/api/demands", params={"q": "Đà Nẵng", "kind": "rent"})
    assert r.json() == []

    r2 = client.get("/api/demands", params={"q": "Đà Nẵng", "kind": "buy"})
    assert len(r2.json()) == 1


def test_khong_khop_thi_rong_chu_khong_loi(client, db):
    _seed(db)
    r = client.get("/api/demands", params={"q": "khong-co-gi-khop-xyz"})
    assert r.status_code == 200
    assert r.json() == []
