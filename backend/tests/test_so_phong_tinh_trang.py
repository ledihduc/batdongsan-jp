"""Sổ phòng: mỗi phòng đang làm gì NGAY LÚC NÀY — màn "Quản lí phòng".

Điều phải giữ:
  * "Đang thuê" CÙNG MỘT luật với Trang chủ chủ nhà. Trang chủ ghi "3 phòng đã
    thuê" mà bấm vào toà ra 2 là người xem hết tin cả hai màn.
  * Có người ở thắng cờ bảo trì còn sót trên phòng.
  * Tên khách và hạn hợp đồng chỉ cho CHỦ phòng — người khác thấy phòng có
    người, không thấy là ai.
"""

from __future__ import annotations

import os
import uuid
from datetime import timedelta
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models as models  # noqa: F401
from app.auth import sign_token
from app.database import Base, get_db
from app.routers.host_room import router as room_router
from app.services.short_stay_service import local_now

CHU = 1401
KHAC = 1402


@pytest.fixture
def db() -> Generator[Session, None, None]:
    # Engine RIÊNG cho từng test — dùng chung cả module thì dòng của test trước
    # rò sang test sau.
    eng = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=eng)
    s = sessionmaker(bind=eng, autoflush=False, autocommit=False)()
    yield s
    s.close()
    eng.dispose()


@pytest.fixture
def client(db: Session) -> Generator[TestClient, None, None]:
    api = FastAPI()
    api.include_router(room_router)

    def _get_db() -> Generator[Session, None, None]:
        yield db

    api.dependency_overrides[get_db] = _get_db
    with TestClient(api, raise_server_exceptions=True) as c:
        yield c


def _auth(uid: int) -> dict:
    return {"Authorization": f"Bearer {sign_token(user_id=uid, role='guest')}"}


def _ngay(n: int) -> str:
    return (local_now().date() + timedelta(days=n)).isoformat()


def _toa(db, ten="An Cu Garden", host=CHU):
    b = models.Building(
        host_id=host, claim_code=f"S{uuid.uuid4().hex[:7].upper()}",
        name=ten, address="25 Hoang Van Thu", city="Ha Noi", district="Ba Dinh",
        is_public=True,
    )
    db.add(b)
    db.flush()
    return b


def _phong(db, b, ma, kenh=None, status="vacant", **kw):
    r = models.Room(building_id=b.id, code=ma, base_price=5_000_000, status=status, **kw)
    db.add(r)
    db.flush()
    if kenh:
        db.add(models.RoomKenh(room_id=r.id, kenh=kenh, gia=5_000_000,
                               don_vi=models.RoomKenh.DON_VI_MAC_DINH[kenh], dang_bat=True))
        db.flush()
    return r


def _nguon(db):
    n = models.RevenueSource(host_id=CHU, name=f"Nguon {uuid.uuid4().hex[:5]}")
    db.add(n)
    db.flush()
    return n.id


def _hop_dong(db, room, *, het, khach=(("Nguyễn Văn An", True),)):
    c = models.Contract(host_id=CHU, room_id=room.id, source_id=_nguon(db),
                        start_date="2026-01-01", end_date=het,
                        monthly_rent=5_000_000, status="active")
    db.add(c)
    db.flush()
    for ten, chinh in khach:
        t = models.Tenant(host_id=CHU, full_name=ten, phone="0900000000")
        db.add(t)
        db.flush()
        db.add(models.ContractTenant(contract_id=c.id, tenant_id=t.id, is_primary=chinh))
    db.flush()
    return c


def _dang_o(db, room, ten="Lê Minh Hoàng", **kw):
    now = local_now()
    db.add(models.Reservation(host_id=CHU, room_id=room.id, guest_name=ten,
                              check_in_date=now.date().isoformat(),
                              check_out_date=(now.date() + timedelta(days=1)).isoformat(),
                              nights=1, total_amount=300_000, status="checked_in",
                              source_id=_nguon(db), **kw))
    db.flush()


def _so(client, b, uid=CHU) -> dict:
    r = client.get(f"/api/host/buildings/{b.id}/rooms", headers=_auth(uid))
    assert r.status_code == 200, r.text
    return {p["code"]: p for p in r.json()}


def test_tinh_trang_tung_phong_va_ten_khach_cho_chu(client, db):
    b = _toa(db)
    p101 = _phong(db, b, "P101", "dai_han", "occupied")
    p102 = _phong(db, b, "P102", "dai_han", "occupied")
    _phong(db, b, "P103", "dai_han")
    _phong(db, b, "P104", "dai_han", "maintenance",
           maintenance_start="2026-09-01", maintenance_end="2026-09-20")
    _hop_dong(db, p101, het=_ngay(200))
    # Người vào hợp đồng TRƯỚC không phải người đứng tên.
    _hop_dong(db, p102, het=_ngay(10),
              khach=(("Người ở ghép", False), ("Trần Thị Mai", True)))

    so = _so(client, b)
    assert so["P101"]["tinh_trang"] == "dang_o"
    assert so["P101"]["khach_thue"] == "Nguyễn Văn An"
    assert so["P101"]["hop_dong_den"] == _ngay(200)
    assert so["P102"]["tinh_trang"] == "sap_tra"
    assert so["P102"]["khach_thue"] == "Trần Thị Mai"
    assert so["P103"]["tinh_trang"] == "trong"
    assert so["P103"]["khach_thue"] is None
    assert so["P104"]["tinh_trang"] == "bao_tri"
    assert so["P101"]["loai"] == ["dai_han"]
    assert (so["P101"]["gia_kenh"], so["P101"]["don_vi"]) == (5_000_000, "thang")


def test_co_nguoi_o_thang_co_bao_tri_con_sot(client, db):
    b = _toa(db)
    p = _phong(db, b, "P201", "dai_han", "maintenance")
    _hop_dong(db, p, het=_ngay(300))
    assert _so(client, b)["P201"]["tinh_trang"] == "dang_o"


def test_khach_luu_tru_dang_o_va_don_theo_gio_da_xong_la_trong(client, db):
    b = _toa(db, "An Cu Riverside")
    s1 = _phong(db, b, "S1", "ngan_han")
    s2 = _phong(db, b, "S2", "ngan_han")
    now = local_now()
    _dang_o(db, s1, check_out_at=now + timedelta(hours=20))
    db.add(models.Reservation(host_id=CHU, room_id=s2.id, guest_name="B",
                              check_in_date=now.date().isoformat(),
                              check_out_date=(now.date() + timedelta(days=1)).isoformat(),
                              nights=1, total_amount=240_000, status="approved",
                              booking_mode="theo_gio",
                              check_in_at=now - timedelta(hours=5),
                              check_out_at=now - timedelta(hours=2),
                              booking_code=f"AC-{uuid.uuid4().hex[:8]}",
                              source_id=_nguon(db)))
    db.flush()

    so = _so(client, b)
    assert so["S1"]["tinh_trang"] == "dang_o"
    assert so["S1"]["khach_thue"] == "Lê Minh Hoàng"
    assert so["S1"]["tra_phong_luc"] is not None
    assert so["S2"]["tinh_trang"] == "trong"
    # Mọi phòng đang khai thác đều ngắn hạn → toà vận hành như khách sạn.
    assert so["S1"]["loai"] == ["ngan_han", "khach_san"]
    assert so["S1"]["don_vi"] == "dem"


def test_mat_bang_la_kinh_doanh_va_toa_tron_khong_phai_khach_san(client, db):
    b = _toa(db)
    _phong(db, b, "MB1", "mat_bang")
    _phong(db, b, "S1", "ngan_han")
    so = _so(client, b)
    assert so["MB1"]["loai"] == ["kinh_doanh"]
    assert so["MB1"]["don_vi"] == "m2_thang"
    assert so["S1"]["loai"] == ["ngan_han"]


def test_phong_cua_chu_khac_khong_lo_ten_khach(client, db):
    b = _toa(db)
    p = _phong(db, b, "P301", "dai_han", "occupied", owner_id=KHAC)
    _hop_dong(db, p, het=_ngay(100))
    x = _so(client, b)["P301"]
    # Vẫn biết phòng có người — chỉ không biết là ai, hợp đồng tới bao giờ.
    assert x["tinh_trang"] == "dang_o"
    assert x["khach_thue"] is None
    assert x["hop_dong_den"] is None


# NOTE: test_dang_thue_khop_trang_chu removed in JP fork (host_tong_quan router stripped).
