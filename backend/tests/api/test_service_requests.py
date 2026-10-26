"""Cụm DỊCH VỤ độc lập (migration 0079) — thay cho luồng mượn hạ tầng thi công.

Canh những thứ hỏng thì không ai biết:
  * khách vãng lai đặt được (không ép đăng nhập) nhưng phản hồi KHÔNG lộ SĐT;
  * bấm hai lần không đẻ hai yêu cầu — admin sẽ gọi khách hai lần;
  * chỉ admin xem được danh sách kèm SĐT;
  * Telegram chết không được làm hỏng việc gửi.
"""

from __future__ import annotations

import os
import shutil
import uuid
from datetime import datetime, timedelta
from typing import Generator
from unittest.mock import patch

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.domain  # noqa: F401 — đăng ký Service/ServiceRequest lên Base.metadata
import app.models as models  # noqa: F401
from app import auth
from app.api.routes.services import router as services_router
from app.database import Base, get_db
from app.domain.service_request import Service, ServiceRequest
from app.middleware.rate_limit import limiter

ADMIN_ID = 930001


@pytest.fixture(autouse=True)
def _tat_rate_limit():
    truoc = limiter.enabled
    limiter.enabled = False
    limiter.reset()
    yield
    limiter.enabled = truoc


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
    app.include_router(services_router)

    def _override_db():
        yield db

    app.dependency_overrides[get_db] = _override_db
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture
def data(db):
    db.add(models.User(
        id=ADMIN_ID, name="Quản trị", email=f"a{uuid.uuid4().hex[:8]}@t.com",
        phone="0900000001", password_hash="x", role="admin",
    ))
    db.add(Service(id=1, slug="electric", name="Sửa điện", sort_order=10))
    db.add(Service(id=2, slug="unclog", name="Thông tắc", sort_order=12))
    db.add(Service(id=3, slug="an", name="Đã tắt", sort_order=99, is_active=False))
    db.commit()


def _admin() -> dict:
    token = auth.sign_token(ADMIN_ID, "admin")
    return {"Authorization": f"Bearer {token}"}


def _gui(client, slug="electric", phone="0912345678", **kw) -> dict:
    body = {"service_slug": slug, "name": "Khách thử", "phone": phone,
            "description": "Aptomat nhảy liên tục", **kw}
    r = client.post("/api/services/requests", json=body)
    assert r.status_code == 201, r.text
    return r.json()


class TestDanhMuc:
    def test_chi_tra_dich_vu_dang_bat(self, client, data):
        rows = client.get("/api/services").json()
        assert [r["slug"] for r in rows] == ["electric", "unclog"]

    def test_KHONG_con_phu_thuoc_duong_dan_thi_cong(self, client, data):
        """Cụm dịch vụ phải đứng một mình — đây là lý do nó được tách ra."""
        assert client.get("/api/services").status_code == 200


class TestGuiYeuCau:
    def test_khach_vang_lai_gui_duoc(self, client, db, data):
        d = _gui(client)
        assert d["status"] == "new"
        assert db.query(ServiceRequest).count() == 1

    def test_phan_hoi_KHONG_lo_ten_va_sdt(self, client, data):
        raw = str(_gui(client))
        assert "0912345678" not in raw
        assert "Khách thử" not in raw

    def test_so_dien_thoai_sai_bi_chan(self, client, data):
        r = client.post("/api/services/requests", json={
            "service_slug": "electric", "name": "A", "phone": "abc123"})
        assert r.status_code == 422

    def test_dich_vu_khong_co_that_bi_chan(self, client, data):
        r = client.post("/api/services/requests", json={
            "service_slug": "khong-co", "name": "A", "phone": "0912345678"})
        assert r.status_code == 404

    def test_gui_hai_lan_lien_tiep_chi_MOT_yeu_cau(self, client, db, data):
        a = _gui(client)
        b = _gui(client)
        assert a["id"] == b["id"]
        assert db.query(ServiceRequest).count() == 1

    def test_qua_cua_so_thi_la_yeu_cau_moi(self, client, db, data):
        a = _gui(client)
        row = db.get(ServiceRequest, a["id"])
        row.created_at = datetime.utcnow() - timedelta(minutes=10)
        db.commit()
        assert _gui(client)["id"] != a["id"]


class TestBaoAdmin:
    def test_telegram_nhan_kem_sdt_de_goi_lai(self, client, data):
        with patch("app.services.notification.telegram_service.gui_admin") as gui:
            _gui(client)
        assert gui.call_count == 1
        assert "0912345678" in gui.call_args[0][0]
        assert "Sửa điện" in gui.call_args[0][0]

    def test_telegram_chet_KHONG_lam_hong_viec_gui(self, client, data):
        with patch("app.services.notification.telegram_service.gui_admin",
                   side_effect=RuntimeError("mạng hỏng")):
            r = client.post("/api/services/requests", json={
                "service_slug": "electric", "name": "A", "phone": "0912345678"})
        assert r.status_code == 201

    def test_admin_co_thong_bao_trong_app(self, client, db, data):
        _gui(client)
        n = db.query(models.Notification).filter(
            models.Notification.type == "service_request").all()
        assert [x.user_id for x in n] == [ADMIN_ID]


class TestAdminXuLy:
    def test_admin_xem_duoc_kem_sdt_va_ten_dich_vu(self, client, data):
        _gui(client)
        r = client.get("/api/services/requests", headers=_admin())
        assert r.status_code == 200
        rows = r.json()["requests"]
        assert rows[0]["phone"] == "0912345678"
        assert rows[0]["service_name"] == "Sửa điện"

    def test_nguoi_la_KHONG_xem_duoc(self, client, data):
        _gui(client)
        assert client.get("/api/services/requests").status_code in (401, 403)

    def test_tim_theo_so_dien_thoai(self, client, data):
        _gui(client, phone="0912345678")
        _gui(client, phone="0987654321", slug="unclog")
        r = client.get("/api/services/requests?q=0987", headers=_admin()).json()
        assert [x["phone"] for x in r["requests"]] == ["0987654321"]

    def test_moc_lien_he_ghi_tu_dong_MOT_lan(self, client, db, data):
        d = _gui(client)
        client.patch(f"/api/services/requests/{d['id']}",
                     json={"status": "contacted"}, headers=_admin())
        db.expire_all()
        moc = db.get(ServiceRequest, d["id"]).contacted_at
        assert moc is not None

        client.patch(f"/api/services/requests/{d['id']}",
                     json={"status": "done"}, headers=_admin())
        db.expire_all()
        assert db.get(ServiceRequest, d["id"]).contacted_at == moc

    def test_xep_lich_va_ghi_chu(self, client, db, data):
        d = _gui(client)
        hen = (datetime.utcnow() + timedelta(days=1)).replace(microsecond=0)
        r = client.patch(
            f"/api/services/requests/{d['id']}",
            json={"status": "scheduled", "scheduled_at": hen.isoformat(),
                  "admin_note": "Khách hẹn 9h sáng"},
            headers=_admin(),
        )
        assert r.status_code == 200
        db.expire_all()
        row = db.get(ServiceRequest, d["id"])
        assert row.scheduled_at == hen
        assert row.admin_note == "Khách hẹn 9h sáng"

    def test_trang_thai_la_bi_chan(self, client, data):
        d = _gui(client)
        r = client.patch(f"/api/services/requests/{d['id']}",
                         json={"status": "xong_roi_nhe"}, headers=_admin())
        assert r.status_code == 422
