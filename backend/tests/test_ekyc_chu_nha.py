"""eKYC CHỦ NHÀ (mig 0140) — CCCD hai mặt + chân dung + GPKD, link, admin duyệt.

Điều phải giữ:
  * link `/ekyc?t=` mở ĐÚNG hồ sơ eKYC của người tạo, không đăng nhập; token
    lạ 401, hết hạn 410; token KHÔNG tạo được link mới;
  * chỉ nhận ảnh thật (magic bytes), CCCD/chân dung không nhận PDF;
  * thiếu gì nộp không được và nói rõ thiếu gì;
  * nộp → vào hàng đợi KYC sẵn có (operator_business_profiles 'pending', có ảnh
    chân dung); duyệt → host_profiles.verified + báo; từ chối → lý do về app,
    sửa được và nộp lại.
"""

from __future__ import annotations

import base64
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

import app.models as models  # noqa: F401
import app.domain.delegation  # noqa: F401,E402
import app.domain.owner_death  # noqa: F401,E402
from app.api.routes.ekyc import router as ekyc_router
from app.auth import sign_token
from app.database import Base, get_db
from app.domain.operator_business import OperatorBusinessProfile
from app.models.host import EkycChuNha, EkycLink, HostProfile
from app.services import sensitive_file_service
from app.services.kyc import operator_business_service

CHU, ADMIN = 1901, 1902
PNG = base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"0" * 64).decode()
PDF = base64.b64encode(b"%PDF-1.4 x").decode()


@pytest.fixture
def db(tmp_path, monkeypatch) -> Generator[Session, None, None]:
    monkeypatch.setattr(sensitive_file_service, "_BASE_DIR", tmp_path)
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=eng)
    conn = eng.connect()
    tx = conn.begin()
    s = sessionmaker(bind=conn, autoflush=False, autocommit=False)()
    for uid in (CHU, ADMIN):
        s.add(models.User(id=uid, name=f"U{uid}", email=f"u{uid}{uuid.uuid4().hex[:4]}@t.com",
                          phone=f"09000{uid}", password_hash="x", role="guest"))
    s.commit()
    yield s
    s.close()
    tx.rollback()
    conn.close()
    eng.dispose()


@pytest.fixture
def client(db: Session) -> Generator[TestClient, None, None]:
    api = FastAPI()
    api.include_router(ekyc_router)
    api.dependency_overrides[get_db] = lambda: db
    with TestClient(api, raise_server_exceptions=True) as c:
        yield c


def _dn(uid: int = CHU) -> dict:
    return {"Authorization": f"Bearer {sign_token(user_id=uid, role='guest')}"}


def _du(client, h: dict) -> None:
    r = client.put("/api/ekyc/thong-tin", headers=h, json={
        "ho_ten": "Nguyễn Văn An", "so_cccd": "031 234 567 890",
        "ten_kinh_doanh": "Hộ KD Nhà trọ An Cư", "so_gpkd": "02A8001234"})
    assert r.status_code == 200, r.text
    for loai in ("cccd_truoc", "cccd_sau", "chan_dung", "gpkd"):
        r = client.post(f"/api/ekyc/anh/{loai}", headers=h, json={"anh_base64": PNG})
        assert r.status_code == 200, r.text


def test_link_mo_dung_ho_so_khong_can_dang_nhap(client, db):
    r = client.post("/api/ekyc/link", headers=_dn())
    assert r.status_code == 201, r.text
    token = r.json()["url"].split("t=", 1)[1]
    h = {"X-Ekyc-Token": token}
    assert client.get("/api/ekyc/ho-so", headers=h).json()["trang_thai"] == "nhap"
    # Token không tạo được link mới (không phải đăng nhập).
    assert client.post("/api/ekyc/link", headers=h).status_code == 401
    assert client.get("/api/ekyc/ho-so", headers={"X-Ekyc-Token": "sai"}).status_code == 401
    db.query(EkycLink).update({EkycLink.het_han: datetime.utcnow() - timedelta(minutes=1)})
    db.commit()
    assert client.get("/api/ekyc/ho-so", headers=h).status_code == 410


def test_chi_nhan_anh_that(client):
    h = _dn()
    assert client.post("/api/ekyc/anh/cccd_truoc", headers=h, json={"anh_base64": PDF}).status_code == 422
    rac = base64.b64encode(b"khong-phai-anh-nao").decode()
    assert client.post("/api/ekyc/anh/chan_dung", headers=h, json={"anh_base64": rac}).status_code == 422
    assert client.post("/api/ekyc/anh/gpkd", headers=h, json={"anh_base64": PDF}).status_code == 200
    assert client.post("/api/ekyc/anh/khac", headers=h, json={"anh_base64": PNG}).status_code == 422


def test_thieu_thi_khong_nop_duoc_va_noi_ro(client):
    h = _dn()
    client.post("/api/ekyc/anh/cccd_truoc", headers=h, json={"anh_base64": PNG})
    r = client.post("/api/ekyc/nop", headers=h)
    assert r.status_code == 422 and "CCCD mặt sau" in r.json()["detail"]


def test_chi_can_cccd_khong_can_chan_dung_gpkd_bo_trong_thi_canh_bao(client, db):
    """Chủ dự án 14/10: CCCD chỉ để tự xác thực, không eKYC; GPKD bỏ trống được."""
    h = _dn()
    r = client.put("/api/ekyc/thong-tin", headers=h, json={
        "ho_ten": "Trần Thị Bình", "so_cccd": "031234567890", "ten_kinh_doanh": "", "so_gpkd": ""})
    assert r.status_code == 200, r.text
    for loai in ("cccd_truoc", "cccd_sau"):
        d = client.post(f"/api/ekyc/anh/{loai}", headers=h, json={"anh_base64": PNG}).json()
    assert d["thieu"] == [] and "Chưa có ảnh giấy phép kinh doanh" in d["canh_bao"]
    assert client.post("/api/ekyc/nop", headers=h).status_code == 200
    p = db.query(OperatorBusinessProfile).filter_by(user_id=CHU).one()
    assert p.verification_status == "pending" and "chưa có GPKD" in p.business_name
    assert p.gpkd_document_path == "" and p.legal_representative_selfie_path is None


def test_nop_vao_hang_doi_kyc_roi_admin_duyet(client, db):
    h = _dn()
    _du(client, h)
    d = client.post("/api/ekyc/nop", headers=h).json()
    assert d["trang_thai"] == "cho_duyet" and d["sua_duoc"] is False
    p = db.query(OperatorBusinessProfile).filter_by(user_id=CHU).one()
    assert p.verification_status == "pending" and p.legal_representative_selfie_path
    assert p.business_registration_number == "02A8001234"
    # Đang chờ duyệt thì không sửa được.
    assert client.post("/api/ekyc/anh/gpkd", headers=h, json={"anh_base64": PNG}).status_code == 409

    operator_business_service.admin_approve_business(p.id, ADMIN, db)
    db.commit()
    assert db.query(HostProfile).filter_by(user_id=CHU).one().verified is True
    assert db.query(EkycChuNha).filter_by(user_id=CHU).one().trang_thai == "da_duyet"
    assert db.query(models.Notification).filter_by(user_id=CHU, type="ekyc_chu_nha").count() == 1


def test_tu_choi_co_ly_do_sua_roi_nop_lai(client, db):
    h = _dn()
    _du(client, h)
    client.post("/api/ekyc/nop", headers=h)
    p = db.query(OperatorBusinessProfile).filter_by(user_id=CHU).one()
    operator_business_service.admin_reject_business(p.id, ADMIN, "Ảnh CCCD bị mờ", db)
    db.commit()
    d = client.get("/api/ekyc/ho-so", headers=h).json()
    assert d["trang_thai"] == "tu_choi" and d["ly_do_tu_choi"] == "Ảnh CCCD bị mờ" and d["sua_duoc"]
    assert client.post("/api/ekyc/anh/cccd_truoc", headers=h, json={"anh_base64": PNG}).json()["trang_thai"] == "nhap"
    assert client.post("/api/ekyc/nop", headers=h).status_code == 200
    db.refresh(p)
    assert p.verification_status == "pending"


def test_kyc_doanh_nghiep_khong_qua_ekyc_thi_khong_dong_bo(db):
    """Operator nộp KYC doanh nghiệp theo đường cũ — không có bản eKYC, không đụng."""
    p = OperatorBusinessProfile(user_id=ADMIN, business_name="Cty", business_registration_number="0101",
                                gpkd_document_path="gpkd/x.pdf", gpkd_issued_at=datetime.utcnow(),
                                legal_representative_name="A", legal_representative_phone="09",
                                verification_status="pending")
    db.add(p)
    db.commit()
    operator_business_service.admin_approve_business(p.id, CHU, db)
    assert db.query(HostProfile).filter_by(user_id=ADMIN).count() == 0
