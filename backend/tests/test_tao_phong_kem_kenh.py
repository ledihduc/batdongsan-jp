"""Tạo phòng phải mở luôn KÊNH KHAI THÁC đầu tiên.

Trước migration 0104, `RoomRepository.create()` không sinh dòng `room_kenh` nào
— phòng tạo qua form không thuộc kênh nào nên **không ra chợ được**, trong khi
phòng sinh từ đường gán-tin (`host_building.py`) lại có kênh. Hai đường tạo
phòng cho ra hai kết quả khác nhau và chỉ một trong hai bán được hàng.

`duplicate()` cũng bỏ quên kênh — "nhân bản" cho ra một phòng không bán được,
đúng thứ người bấm nút không ngờ tới nhất.
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
from app.routers.host_room import router as room_router

CHU = 811
SALE = 812
NGUOI_LA = 813


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
    api.include_router(room_router)

    def _get_db() -> Generator[Session, None, None]:
        yield db

    api.dependency_overrides[get_db] = _get_db
    with TestClient(api, raise_server_exceptions=True) as c:
        yield c


def _auth(uid: int) -> dict:
    return {"Authorization": f"Bearer {sign_token(user_id=uid, role='guest')}"}


def _toa(db: Session, *, host_id=CHU, sale_id=None, **gia):
    b = models.Building(
        host_id=host_id,
        sale_id=sale_id,
        claim_code=f"K{uuid.uuid4().hex[:7].upper()}",
        name="Toa thu",
        address="1 Le Loi",
        city="Tp Hai Phong",
        district="Hong Bang",
        is_public=True,
        **gia,
    )
    db.add(b)
    db.flush()
    return b


def _tao(client, toa, uid=CHU, **body):
    body.setdefault("code", "P01")
    body.setdefault("base_price", 5_000_000)
    return client.post(
        f"/api/host/buildings/{toa.id}/rooms", json=body, headers=_auth(uid)
    )


def _kenh(db: Session, room_id: int) -> list[models.RoomKenh]:
    return (
        db.query(models.RoomKenh)
        .filter(models.RoomKenh.room_id == room_id)
        .order_by(models.RoomKenh.id)
        .all()
    )


# ── Kênh sinh cùng phòng ─────────────────────────────────────────────────────


def test_tao_phong_dai_han_mo_dung_mot_kenh(client, db):
    r = _tao(client, _toa(db), kenh="dai_han", toi_thieu=6, dat_coc=1)
    assert r.status_code == 201, r.text

    ds = _kenh(db, r.json()["id"])
    assert len(ds) == 1
    k = ds[0]
    assert (k.kenh, k.don_vi, k.gia) == ("dai_han", "thang", 5_000_000)
    assert (k.toi_thieu, k.dat_coc, k.dang_bat) == (6, 1, True)


def test_mat_bang_lay_don_vi_m2_thang_va_giu_ky_mien_phi(client, db):
    r = _tao(client, _toa(db), kenh="mat_bang", mien_phi_thang=3)
    k = _kenh(db, r.json()["id"])[0]
    assert k.don_vi == "m2_thang"
    assert k.mien_phi_thang == 3


def test_kenh_khac_mat_bang_bi_bo_ky_mien_phi(client, db):
    """Kỳ miễn tiền sửa là điều khoản của thuê thương mại, không của nhà ở."""
    r = _tao(client, _toa(db), kenh="dai_han", mien_phi_thang=3)
    assert _kenh(db, r.json()["id"])[0].mien_phi_thang is None


def test_ngan_han_va_ban_lay_dung_don_vi(client, db):
    toa = _toa(db)
    a = _tao(client, toa, code="P0A", kenh="ngan_han")
    b = _tao(client, toa, code="P0B", kenh="ban")
    assert _kenh(db, a.json()["id"])[0].don_vi == "dem"
    assert _kenh(db, b.json()["id"])[0].don_vi == "tong"


def test_app_ban_cu_khong_gui_kenh_van_tao_duoc(client, db):
    """Ép 422 ở đây là cả một bản app trong cache không tạo nổi phòng nào."""
    r = _tao(client, _toa(db))
    assert r.status_code == 201, r.text
    ds = _kenh(db, r.json()["id"])
    assert len(ds) == 1 and ds[0].kenh == "dai_han"


def test_kenh_la_thi_tu_choi(client, db):
    assert _tao(client, _toa(db), kenh="cho_muon").status_code == 422


def test_gia_kenh_bang_gia_phong_khong_lech(client, db):
    """Hai chỗ giữ cùng một số — lệch nhau là app và hoá đơn nói hai giá."""
    r = _tao(client, _toa(db), kenh="dai_han", base_price=7_200_000)
    assert r.json()["base_price"] == 7_200_000
    assert _kenh(db, r.json()["id"])[0].gia == 7_200_000


# ── Giá tiện ích + hai danh sách ─────────────────────────────────────────────


def test_luu_gia_tien_ich_va_tra_ve_gia_hieu_luc(client, db):
    toa = _toa(db, gia_dien=3800, gia_nuoc=18000)
    d = _tao(client, toa, kenh="dai_han", gia_dien=4500).json()

    # Cột thô: chỉ phòng nào ghi đè mới có số → app biết ô nhập nên để trống.
    assert d["gia_dien"] == 4500
    assert d["gia_nuoc"] is None
    # Số hiệu lực: đã giải quyết sẵn, app khỏi tự suy.
    assert d["gia_dien_hieu_luc"] == 4500
    assert d["gia_nuoc_hieu_luc"] == 18000


def test_phong_de_0_la_mien_phi(client, db):
    """`0` là miễn phí, không được rơi về giá toà."""
    toa = _toa(db, gia_nuoc=18000)
    d = _tao(client, toa, kenh="dai_han", gia_nuoc=0).json()
    assert d["gia_nuoc_hieu_luc"] == 0


def test_key_la_bi_loai_khong_bao_loi(client, db):
    d = _tao(
        client,
        _toa(db),
        kenh="dai_han",
        dich_vu_gom=["gui_xe", "khong_co_that"],
        do_trong_phong=["giuong", "xe_may"],
    ).json()
    assert d["dich_vu_gom"] == ["gui_xe"]
    assert d["do_trong_phong"] == ["giuong"]


def test_gia_am_bi_tu_choi(client, db):
    assert _tao(client, _toa(db), kenh="dai_han", gia_dien=-1).status_code == 422


# ── Quyền: sale khai được giá quảng cáo ──────────────────────────────────────


def test_sale_phu_trach_tao_duoc_phong_kem_gia_dien(client, db):
    """Giá điện là giá QUẢNG CÁO (mọi tin thuê ở VN đều ghi), không phải tài
    chính. Sale vẫn không chốt hoá đơn, không xem công nợ."""
    toa = _toa(db, host_id=CHU, sale_id=SALE)
    r = _tao(client, toa, uid=SALE, kenh="dai_han", gia_dien=4200)
    assert r.status_code == 201, r.text
    assert r.json()["gia_dien"] == 4200


def test_nguoi_la_khong_tao_duoc(client, db):
    assert _tao(client, _toa(db), uid=NGUOI_LA).status_code == 404


# ── Nhân bản ─────────────────────────────────────────────────────────────────


def test_nhan_ban_chep_ca_kenh_va_gia_tien_ich(client, db):
    goc = _tao(
        client,
        _toa(db),
        kenh="mat_bang",
        mien_phi_thang=2,
        gia_dien=4500,
        do_trong_phong=["giuong", "dieu_hoa"],
    ).json()

    r = client.post(f"/api/host/rooms/{goc['id']}/duplicate", headers=_auth(CHU))
    assert r.status_code == 201, r.text
    ban_sao = r.json()

    assert ban_sao["gia_dien"] == 4500
    assert ban_sao["do_trong_phong"] == ["giuong", "dieu_hoa"]
    ds = _kenh(db, ban_sao["id"])
    assert len(ds) == 1
    assert (ds[0].kenh, ds[0].don_vi, ds[0].mien_phi_thang) == (
        "mat_bang",
        "m2_thang",
        2,
    )


def test_nhan_ban_KHONG_chep_trang_thai_da_chot(client, db):
    """Bản gốc đã bán; bản sao là hàng mới nên phải đang rao."""
    goc = _tao(client, _toa(db), kenh="ban").json()
    k = _kenh(db, goc["id"])[0]
    k.trang_thai = "da_ban"
    db.flush()

    r = client.post(f"/api/host/rooms/{goc['id']}/duplicate", headers=_auth(CHU))
    assert _kenh(db, r.json()["id"])[0].trang_thai == "dang_rao"


# ── Xoá phòng: ba cổng chặn ──────────────────────────────────────────────────
#
# Tới trước hôm nay KHÔNG có đường xoá nào: phòng gõ nhầm mã, phòng dựng thử,
# phòng của toà đã bán — đều nằm lại vĩnh viễn trong sổ và trên chợ. Nhưng xoá
# bừa thì hoá đơn và công nợ của người thuê mất chỗ bám, và khách đang cầm một
# mã đặt phòng có thật.


def _nguon_thu(db: Session, host_id=CHU) -> int:
    n = (
        db.query(models.RevenueSource)
        .filter(models.RevenueSource.host_id == host_id)
        .first()
    )
    if n is None:
        n = models.RevenueSource(host_id=host_id, name="Truc tiep")
        db.add(n)
        db.flush()
    return n.id


def test_xoa_duoc_phong_chua_dinh_gi(client, db):
    r = _tao(client, _toa(db), kenh="dai_han")
    pid = r.json()["id"]
    assert client.delete(f"/api/host/rooms/{pid}", headers=_auth(CHU)).status_code == 204
    assert db.get(models.Room, pid) is None
    # Kênh đi theo phòng, không để lại dòng mồ côi.
    assert _kenh(db, pid) == []


def test_phong_co_HOP_DONG_thi_khong_xoa_duoc(client, db):
    toa = _toa(db)
    pid = _tao(client, toa, kenh="dai_han").json()["id"]
    db.add(
        models.Contract(
            host_id=CHU,
            room_id=pid,
            source_id=_nguon_thu(db),
            start_date="2026-01-01",
            end_date="2026-12-31",
            monthly_rent=5_000_000,
            status="active",
        )
    )
    db.flush()
    r = client.delete(f"/api/host/rooms/{pid}", headers=_auth(CHU))
    assert r.status_code == 409
    assert "hợp đồng" in r.text
    assert db.get(models.Room, pid) is not None


def test_phong_co_DON_DAT_thi_khong_xoa_duoc(client, db):
    toa = _toa(db)
    pid = _tao(client, toa, kenh="ngan_han", code="P0N").json()["id"]
    db.add(
        models.Reservation(
            host_id=CHU,
            room_id=pid,
            guest_name="Khach",
            check_in_date="2026-10-01",
            check_out_date="2026-10-03",
            nights=2,
            total_amount=1_000_000,
            status="approved",
            source_id=_nguon_thu(db),
        )
    )
    db.flush()
    r = client.delete(f"/api/host/rooms/{pid}", headers=_auth(CHU))
    assert r.status_code == 409
    assert "đơn đặt" in r.text


def test_phong_dang_co_LICH_thi_khong_xoa_duoc(client, db):
    from datetime import date

    toa = _toa(db)
    pid = _tao(client, toa, kenh="dai_han").json()["id"]
    db.add(
        models.RoomChiemDung(
            room_id=pid,
            tu_ngay=date(2026, 10, 1),
            den_ngay=date(2026, 10, 5),
            kenh="dai_han",
            nguon="thu_cong",
        )
    )
    db.flush()
    r = client.delete(f"/api/host/rooms/{pid}", headers=_auth(CHU))
    assert r.status_code == 409
    assert "lịch" in r.text


def test_nguoi_la_khong_xoa_duoc(client, db):
    pid = _tao(client, _toa(db), kenh="dai_han").json()["id"]
    # 404 chứ không 403 — 403 xác nhận phòng tồn tại, đủ để dò id.
    assert (
        client.delete(f"/api/host/rooms/{pid}", headers=_auth(NGUOI_LA)).status_code
        == 404
    )
    assert db.get(models.Room, pid) is not None
