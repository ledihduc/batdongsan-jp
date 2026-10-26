"""Tin nhu cầu — "Cần thuê" / "Cần mua" (migration 0076).

Những gì được canh ở đây là những thứ sẽ HỎNG ÂM THẦM nếu sai:

  * tin hết hạn phải BIẾN MẤT khỏi danh sách công khai (hạn tính khi đọc, không
    có cron nào dọn hộ);
  * KHÔNG lộ số điện thoại người đăng — đây là lý do duy nhất khiến người ta
    dám đăng nhu cầu;
  * người lạ không sửa/đóng được tin của người khác;
  * trần số tin đang mở, nếu không một tài khoản chôn sạch danh sách.
"""

from __future__ import annotations

import os
import shutil
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

import app.domain  # noqa: F401 — đăng ký DemandPost lên Base.metadata
import app.models as models  # noqa: F401
from app import auth
from app.api.routes.demand import router as demand_router
from app.database import Base, get_db
from app.domain.demand_post import DemandPost
from app.middleware.rate_limit import limiter
from app.services.demand import MAX_OPEN_PER_USER

# Rate limit 20/giờ là để chặn spam THẬT, không phải để chặn test. Tắt trong
# fixture autouse (lúc thực thi) chứ không ở cấp module — limiter dùng chung cả
# phiên pytest, bật/tắt ở cấp module sẽ đè lên tệp test khác tuỳ thứ tự import.
@pytest.fixture(autouse=True)
def _tat_rate_limit():
    truoc = limiter.enabled
    limiter.enabled = False
    limiter.reset()
    yield
    limiter.enabled = truoc


U1 = 910001
U2 = 910002


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


@pytest.fixture
def client(db) -> Generator[TestClient, None, None]:
    app = FastAPI()
    app.include_router(demand_router)

    def _override_db():
        yield db

    app.dependency_overrides[get_db] = _override_db
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture
def users(db):
    for uid, ten in ((U1, "Người tìm nhà"), (U2, "Người khác")):
        db.add(
            models.User(
                id=uid,
                name=ten,
                email=f"d{uuid.uuid4().hex[:8]}@t.com",
                phone="0900000123",
                password_hash="x",
                role="guest",
            )
        )
    db.add(models.Category(id=1, name="Căn hộ"))
    db.add(models.Category(id=2, name="Phòng trọ"))
    db.commit()


def _headers(uid: int = U1) -> dict:
    token = auth.sign_token(uid, "guest")
    return {"Authorization": f"Bearer {token}"}


def _tao(client, **kw) -> dict:
    body = {"kind": "rent", "province_name": "TP.HCM", **kw}
    r = client.post("/api/demands", json=body, headers=_headers(kw.pop("uid", U1)))
    assert r.status_code == 201, r.text
    return r.json()


class TestDangTin:
    def test_dang_duoc_tin_can_thue(self, client, users):
        d = _tao(
            client,
            category_ids=[1, 2],
            budget_min=5_000_000,
            budget_max=9_000_000,
            needs=["cho_de_xe", "gio_tu_do"],
            note="Cần 2PN gần Q7",
        )
        assert d["kind"] == "rent"
        assert d["status"] == "open"
        assert sorted(d["category_names"]) == ["Căn hộ", "Phòng trọ"]

    def test_phai_dang_nhap(self, client, users):
        r = client.post("/api/demands", json={"kind": "rent"})
        assert r.status_code in (401, 403)

    def test_ngan_sach_nguoc_chieu_bi_chan(self, client, users):
        r = client.post(
            "/api/demands",
            json={"kind": "rent", "budget_min": 9_000_000, "budget_max": 5_000_000},
            headers=_headers(),
        )
        assert r.status_code == 422

    def test_kind_la_khong_hop_le(self, client, users):
        r = client.post("/api/demands", json={"kind": "swap"}, headers=_headers())
        assert r.status_code == 422

    def test_loai_hinh_khong_co_that_bi_bo_qua_chu_khong_chan_tin(
        self, client, users
    ):
        """Client cũ gửi id danh mục đã tắt — nhu cầu vẫn còn nguyên giá trị,
        không có lý do để từ chối cả tin."""
        d = _tao(client, category_ids=[1, 99999])
        assert d["category_ids"] == [1]

    def test_tran_so_tin_dang_mo(self, client, users):
        for _ in range(MAX_OPEN_PER_USER):
            _tao(client)
        r = client.post("/api/demands", json={"kind": "rent"}, headers=_headers())
        assert r.status_code == 429


class TestDanhSach:
    def test_tin_het_han_bien_mat(self, client, db, users):
        d = _tao(client)
        db.get(DemandPost, d["id"]).expires_at = datetime.utcnow() - timedelta(days=1)
        db.commit()

        assert client.get("/api/demands").json() == []

    def test_tin_da_dong_bien_mat(self, client, users):
        d = _tao(client)
        client.patch(
            f"/api/demands/{d['id']}", json={"status": "closed"}, headers=_headers()
        )
        assert client.get("/api/demands").json() == []

    def test_loc_theo_loai_tin_va_loai_hinh(self, client, users):
        _tao(client, category_ids=[1])
        _tao(client, kind="buy", category_ids=[2])

        assert len(client.get("/api/demands?kind=buy").json()) == 1
        assert len(client.get("/api/demands?category_id=1").json()) == 1
        assert len(client.get("/api/demands?category_id=2&kind=rent").json()) == 0

    def test_mine_thay_ca_tin_da_dong(self, client, users):
        d = _tao(client)
        client.patch(
            f"/api/demands/{d['id']}", json={"status": "closed"}, headers=_headers()
        )
        r = client.get("/api/demands/mine", headers=_headers())
        assert [x["status"] for x in r.json()] == ["closed"]

    def test_mine_khong_tra_tin_cua_nguoi_khac(self, client, users):
        _tao(client, uid=U1)
        assert client.get("/api/demands/mine", headers=_headers(U2)).json() == []


class TestRiengTu:
    def test_KHONG_lo_so_dien_thoai_nguoi_dang(self, client, users):
        _tao(client)
        raw = client.get("/api/demands").text
        assert "0900000123" not in raw
        assert "phone" not in raw

    def test_nguoi_la_khong_dong_duoc_tin(self, client, users):
        d = _tao(client, uid=U1)
        r = client.patch(
            f"/api/demands/{d['id']}", json={"status": "closed"}, headers=_headers(U2)
        )
        # 404 chứ không 403: không xác nhận cho người lạ biết tin này tồn tại.
        assert r.status_code == 404
        assert client.get(f"/api/demands/{d['id']}").json()["status"] == "open"


class TestGiaHan:
    def test_gia_han_lam_tin_song_lai(self, client, db, users):
        d = _tao(client)
        db.get(DemandPost, d["id"]).expires_at = datetime.utcnow() - timedelta(days=1)
        db.commit()
        assert client.get("/api/demands").json() == []

        client.patch(
            f"/api/demands/{d['id']}", json={"extend": True}, headers=_headers()
        )
        assert len(client.get("/api/demands").json()) == 1

    def test_gia_han_KHONG_cong_don(self, client, db, users):
        """Cộng dồn cho phép bấm 10 lần để giữ tin nổi mãi."""
        d = _tao(client)
        item = db.get(DemandPost, d["id"])
        item.expires_at = datetime.utcnow() + timedelta(days=200)
        db.commit()

        client.patch(
            f"/api/demands/{d['id']}", json={"extend": True}, headers=_headers()
        )
        db.expire_all()
        con_lai = (db.get(DemandPost, d["id"]).expires_at - datetime.utcnow()).days
        assert con_lai < 31
