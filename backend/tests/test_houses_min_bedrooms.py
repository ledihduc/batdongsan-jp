"""Lọc tin theo SỐ PHÒNG NGỦ tối thiểu (GET /api/houses?minBedrooms=N).

Chip "Phòng ngủ" trên màn Bộ lọc nâng cao trước đây là no-op: FE set state
nhưng không gửi lên, backend cũng không có tham số. Test khoá lại cả hai điều
dễ hỏng: filter phải là ">= N" (không phải "= N") và phải CỘNG DỒN với các
filter khác chứ không thay thế chúng.

SQLite in-memory + TestClient, theo đúng khuôn test_houses_transaction_type.py.
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
import app.models  # noqa: F401 — đăng ký ORM classes


def _make_app() -> FastAPI:
    from app.routers.houses import router as houses_router

    app = FastAPI()
    app.include_router(houses_router)
    return app


@pytest.fixture(scope="module")
def sqlite_engine():
    _engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}
    )
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


def _seed(db: Session) -> None:
    from app.models import Category, User, HostProfile, House

    cat = Category(name="Nhà phố", icon="home")
    db.add(cat)
    db.flush()

    u = User(
        id=10,
        name="Host",
        email=f"h_{uuid.uuid4().hex[:6]}@t.com",
        password_hash="x",
        role="host",
    )
    db.add(u)
    db.flush()
    db.add(HostProfile(user_id=10))
    db.flush()

    for beds, area in ((0, 20.0), (1, 30.0), (2, 40.0), (4, 90.0)):
        db.add(
            House(
                host_id=10,
                title=f"Nhà {beds} PN",
                description="d",
                category_id=cat.id,
                price=1_000_000.0,
                area=area,
                city="Hà Nội",
                district="Hoàn Kiếm",
                address="1 Phố Huế",
                bedrooms=beds,
                bathrooms=1,
                status="published",
                available_units=1,
                transaction_type="rent",
            )
        )
    db.flush()


def _beds(resp) -> list[int]:
    data = resp.json()
    items = data["houses"] if isinstance(data, dict) else data
    return sorted(h["bedrooms"] for h in items)


def test_khong_truyen_thi_giu_nguyen_hanh_vi_cu(client, db_session):
    _seed(db_session)
    r = client.get("/api/houses")
    assert r.status_code == 200
    assert _beds(r) == [0, 1, 2, 4]


def test_loc_lon_hon_hoac_bang_chu_khong_phai_bang(client, db_session):
    _seed(db_session)
    r = client.get("/api/houses", params={"minBedrooms": 2})
    assert r.status_code == 200
    # 2 và 4 — nếu ai đó đổi thành "== 2" thì test này đỏ.
    assert _beds(r) == [2, 4]


def test_chip_4_cong_bao_gom_ca_tin_nhieu_phong_hon(client, db_session):
    _seed(db_session)
    r = client.get("/api/houses", params={"minBedrooms": 4})
    assert _beds(r) == [4]


def test_khong_ghi_de_filter_khac_ma_cong_don(client, db_session):
    _seed(db_session)
    # minBedrooms=1 giữ lại 1/2/4; minArea=50 chỉ còn tin 90m² (4 PN).
    r = client.get("/api/houses", params={"minBedrooms": 1, "minArea": 50})
    assert _beds(r) == [4]


def test_gia_tri_0_coi_nhu_khong_loc(client, db_session):
    _seed(db_session)
    r = client.get("/api/houses", params={"minBedrooms": 0})
    assert _beds(r) == [0, 1, 2, 4]
