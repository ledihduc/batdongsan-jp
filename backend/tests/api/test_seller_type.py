"""Tự khai vai trò người đăng tin (migration 0075).

Nguyên tắc quan trọng nhất được canh ở đây: **không suy diễn**. Tin cũ chưa
từng được hỏi thì trả rỗng, và rỗng KHÔNG được biến thành "chủ nhà" ở bất kỳ
tầng nào — gán nhãn "chính chủ" cho tin không biết còn nguy hiểm hơn không nói
gì, vì khách sẽ tin ở mức cao hơn thực tế.
"""

from __future__ import annotations

import os
import shutil
import uuid
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.models as models  # noqa: F401
from app import helpers
from app.database import Base, get_db
from app.routers import hosts_public
from app.routers.hosts_public import router as hosts_router

HOST_ID = 830001


@pytest.fixture(scope="module")
def db_template(tmp_path_factory) -> str:
    path = str(tmp_path_factory.mktemp("tpl") / "t.db")
    e = create_engine(f"sqlite:///{path}")
    Base.metadata.create_all(bind=e)
    e.dispose()
    return path


@pytest.fixture
def db(tmp_path, db_template) -> Generator[Session, None, None]:
    target = tmp_path / "test.db"
    shutil.copyfile(db_template, target)
    engine = create_engine(
        f"sqlite:///{target}", connect_args={"check_same_thread": False}
    )
    s = sessionmaker(bind=engine, autoflush=False)()
    yield s
    s.close()
    engine.dispose()


@pytest.fixture(autouse=True)
def _clear_cache():
    hosts_public._featured_cache.clear()
    yield
    hosts_public._featured_cache.clear()


@pytest.fixture
def client(db) -> Generator[TestClient, None, None]:
    app = FastAPI()
    app.include_router(hosts_router)

    def _override_db():
        yield db

    app.dependency_overrides[get_db] = _override_db
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture
def host(db):
    db.add(models.User(
        id=HOST_ID, name="Người bán", email=f"s{uuid.uuid4().hex[:6]}@t.com",
        phone="0900000009", password_hash="x", role="host",
    ))
    db.commit()


def _them_tin(db, seller_type: str, title: str = "Nhà"):
    h = models.House(
        host_id=HOST_ID, title=title, description="d", address="a",
        district="q1", city="hcm", price=1, category_id=1,
        status="published", seller_type=seller_type,
    )
    db.add(h)
    db.commit()
    return h


class TestNhanVaiTro:
    def test_chua_khai_thi_KHONG_doan_la_chu_nha(self, client, db, host):
        _them_tin(db, "")
        assert client.get(f"/api/hosts/{HOST_ID}").json()["seller_kind"] == ""

    def test_moi_tin_deu_khai_chu_nha(self, client, db, host):
        _them_tin(db, "owner")
        _them_tin(db, "owner")
        assert client.get(f"/api/hosts/{HOST_ID}").json()["seller_kind"] == "owner"

    def test_co_MOT_tin_dang_ho_thi_la_moi_gioi(self, client, db, host):
        """Đăng hộ dù một căn thì ở căn đó họ vẫn là trung gian — gọi họ là chủ
        nhà mới là điều nguy hiểm."""
        _them_tin(db, "owner")
        _them_tin(db, "broker")
        assert client.get(f"/api/hosts/{HOST_ID}").json()["seller_kind"] == "broker"

    def test_tin_da_an_khong_tinh(self, client, db, host):
        _them_tin(db, "owner")
        h = _them_tin(db, "broker")
        h.status = "hidden"
        db.commit()
        assert client.get(f"/api/hosts/{HOST_ID}").json()["seller_kind"] == "owner"


    def test_featured_cung_tra_nhan_vai_tro(self, client, db, host):
        """Trang chủ tách "Môi giới giỏi" khỏi "Chủ nhà" dựa trên nhãn này —
        thiếu nhãn ở /featured thì mọi người bán rơi hết vào một nhóm."""
        _them_tin(db, "broker")
        hosts = client.get("/api/hosts/featured").json()["hosts"]
        moi = {h["id"]: h.get("seller_kind") for h in hosts}
        assert moi.get(HOST_ID) == "broker"


class TestHouseToDict:
    def test_tra_seller_type(self, db, host):
        h = _them_tin(db, "broker")
        assert helpers.house_to_dict(db, h)["seller_type"] == "broker"

    def test_tin_cu_tra_chuoi_rong_khong_phai_None(self, db, host):
        """Client dùng chuỗi để so; None sẽ làm vỡ mọi so sánh phía Dart."""
        h = _them_tin(db, "")
        assert helpers.house_to_dict(db, h)["seller_type"] == ""


class TestGiaTriLa:
    def test_gia_tri_ngoai_danh_sach_bi_bo(self):
        """Router chỉ nhận 'owner'|'broker'; thứ khác → rỗng, KHÔNG lưu bừa."""
        from app.routers.houses import _VALID_SELLER_TYPES

        assert set(_VALID_SELLER_TYPES) == {"owner", "broker"}
