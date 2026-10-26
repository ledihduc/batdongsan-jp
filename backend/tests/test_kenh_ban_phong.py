"""KÊNH BÁN của phòng — cổng chặn đặt theo đêm sai kênh.

Lỗi đã xảy ra trên staging: căn hộ cho thuê 5.500.000đ/THÁNG đặt được theo ĐÊM,
màn đặt phòng nhân giá tháng với số đêm → 3 đêm = 16.500.000đ. Đây là lỗi TÍNH
TIỀN, nên cổng phải nằm ở BACKEND, không chỉ ẩn nút ở app.
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
from sqlalchemy.orm import Session, sessionmaker

import app.models as models  # noqa: F401
from app.auth import sign_token
from app.database import Base, get_db
from app.routers.guest_reservation import router as res_router

KHACH = 120
CHU = 121
#: Sale phụ trách toà. Từ 14/09/2026 khách chỉ đặt được qua sale, nên phòng
#: trong các test này phải có sale — không thì bị cổng sale chặn trước khi tới
#: cổng kênh mà test đang muốn kiểm.
SALE = 122


@pytest.fixture(scope="module")
def engine():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=eng)
    yield eng
    eng.dispose()


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
def client(db: Session) -> Generator[TestClient, None, None]:
    api = FastAPI()
    api.include_router(res_router)

    def _get_db() -> Generator[Session, None, None]:
        yield db

    api.dependency_overrides[get_db] = _get_db
    with TestClient(api, raise_server_exceptions=False) as c:
        yield c


def _auth(uid: int = KHACH) -> dict:
    return {"Authorization": f"Bearer {sign_token(user_id=uid, role='guest')}"}


def _phong(db: Session, gia: float = 5_500_000) -> models.Room:
    b = models.Building(
        host_id=CHU,
        claim_code=f"BG-{uuid.uuid4().hex[:6].upper()}",
        name="Toa A",
        address="x",
        city="y",
        sale_id=SALE,
    )
    db.add(b)
    db.flush()
    r = models.Room(building_id=b.id, code="P01", base_price=gia, status="vacant")
    db.add(r)
    db.flush()
    return r


def _bat_kenh(db: Session, room_id: int, kenh: str, gia: float, toi_thieu=None):
    k = models.RoomKenh(
        room_id=room_id,
        kenh=kenh,
        gia=gia,
        don_vi=models.RoomKenh.DON_VI_MAC_DINH[kenh],
        toi_thieu=toi_thieu,
        dang_bat=True,
    )
    db.add(k)
    db.flush()
    return k


def _dat(client, room_id: int, nhan="2026-10-01", tra="2026-10-04"):
    return client.post(
        "/api/guest/reservations",
        json={
            "room_id": room_id,
            "check_in_date": nhan,
            "check_out_date": tra,
            "guest_name": "Khach Thu",
            "guest_phone": "0900000000",
        },
        headers=_auth(),
    )


def test_phong_CHI_dai_han_thi_KHONG_dat_duoc_theo_dem(client, db):
    """Đây là bug 16.500.000đ. Phòng chỉ bật kênh dài hạn → phải từ chối."""
    r = _phong(db, gia=5_500_000)
    _bat_kenh(db, r.id, models.RoomKenh.DAI_HAN, 5_500_000)

    kq = _dat(client, r.id)
    assert kq.status_code == 409, kq.text
    assert "không cho thuê theo đêm" in kq.json()["detail"]


def test_phong_KHONG_bat_kenh_nao_cung_bi_tu_choi(client, db):
    # Không cấu hình gì = chưa rao bán kiểu nào; mặc định phải là ĐÓNG.
    r = _phong(db)
    kq = _dat(client, r.id)
    assert kq.status_code == 409


def test_phong_co_kenh_ngan_han_thi_dat_duoc(client, db):
    r = _phong(db, gia=350_000)
    _bat_kenh(db, r.id, models.RoomKenh.NGAN_HAN, 350_000)
    kq = _dat(client, r.id)
    assert kq.status_code in (200, 201), kq.text


def test_kenh_ngan_han_TAT_thi_khong_dat_duoc(client, db):
    """`dang_bat=False` để tạm ngưng mà không mất cấu hình giá."""
    r = _phong(db)
    k = _bat_kenh(db, r.id, models.RoomKenh.NGAN_HAN, 350_000)
    k.dang_bat = False
    db.flush()
    assert _dat(client, r.id).status_code == 409


def test_phong_bat_CA_HAI_kenh_van_dat_duoc_theo_dem(client, db):
    """Vừa cho thuê tháng vừa chạy homestay lúc trống — hợp lệ."""
    r = _phong(db)
    _bat_kenh(db, r.id, models.RoomKenh.DAI_HAN, 5_500_000)
    _bat_kenh(db, r.id, models.RoomKenh.NGAN_HAN, 350_000)
    assert _dat(client, r.id).status_code in (200, 201)


def test_ton_trong_so_dem_toi_thieu_cua_KENH(client, db):
    r = _phong(db)
    _bat_kenh(db, r.id, models.RoomKenh.NGAN_HAN, 350_000, toi_thieu=3)
    # 1 đêm < 3 → chặn
    assert _dat(client, r.id, "2026-10-01", "2026-10-02").status_code == 422
    # 3 đêm → qua
    assert _dat(client, r.id, "2026-11-01", "2026-11-04").status_code in (200, 201)
