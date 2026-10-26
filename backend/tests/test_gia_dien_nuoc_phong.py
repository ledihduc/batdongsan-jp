"""Đơn giá điện/nước/dịch vụ: phòng → toà → hằng số.

Trước migration 0104 đơn giá KHÔNG được lưu ở đâu cả — nó là tham số của
`GenerateBatchRequest` với hằng số cứng 3500/15000, nên mỗi lần chốt tiền tháng
chủ nhà gõ lại và **cả lô dùng chung một giá**.

Hai thứ phải giữ bằng test:

1. **`None` khác `0`.** `0` là miễn phí (nhà trọ bao nước), `None` là chưa khai.
   Viết `room.gia_nuoc or toa.gia_nuoc` là phòng bao nước vẫn bị thu tiền nước.
2. **Client cũ không gãy.** Màn chốt lô đang gửi 3500/15000 tường minh; gửi thì
   vẫn phải ghi đè y như trước.
"""

from __future__ import annotations

import os
import uuid
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.models as models  # noqa: F401
from app.database import Base
from app.services import gia_tien_ich, tien_ich_phong

CHU = 801


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


def _toa(db: Session, **gia):
    b = models.Building(
        host_id=CHU,
        claim_code=f"G{uuid.uuid4().hex[:7].upper()}",
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


def _phong(db: Session, b, ma="P01", **gia):
    r = models.Room(building_id=b.id, code=ma, base_price=5_000_000,
                    status="vacant", **gia)
    db.add(r)
    db.flush()
    return r


# ── Ba tầng ưu tiên ──────────────────────────────────────────────────────────


def test_phong_khai_rieng_thi_dung_gia_phong(db):
    b = _toa(db, gia_dien=3800)
    p = _phong(db, b, gia_dien=4500)
    assert gia_tien_ich.gia_dien(db, p) == 4500


def test_phong_chua_khai_thi_lay_theo_toa(db):
    b = _toa(db, gia_dien=3800, gia_nuoc=18000)
    p = _phong(db, b)
    assert gia_tien_ich.gia_dien(db, p) == 3800
    assert gia_tien_ich.gia_nuoc(db, p) == 18000


def test_ca_hai_chua_khai_thi_ve_hang_so(db):
    p = _phong(db, _toa(db))
    assert gia_tien_ich.gia_dien(db, p) == gia_tien_ich.GIA_DIEN_MAC_DINH == 3500
    assert gia_tien_ich.gia_nuoc(db, p) == gia_tien_ich.GIA_NUOC_MAC_DINH == 15000


def test_phi_dich_vu_mac_dinh_la_0_khong_bia_so(db):
    """Thu tiền người thuê vì một khoản chưa ai khai là điều không được phép."""
    p = _phong(db, _toa(db))
    assert gia_tien_ich.phi_dich_vu(db, p) == 0


# ── `0` KHÁC `None` — chỗ dễ viết sai nhất ───────────────────────────────────


def test_phong_bao_nuoc_ra_0_khong_roi_ve_gia_toa(db):
    b = _toa(db, gia_nuoc=18000)
    p = _phong(db, b, gia_nuoc=0)
    # `p.gia_nuoc or b.gia_nuoc` sẽ ra 18000 — đúng cái lỗi này chặn.
    assert gia_tien_ich.gia_nuoc(db, p) == 0


def test_toa_bao_nuoc_ra_0_khong_roi_ve_hang_so(db):
    p = _phong(db, _toa(db, gia_nuoc=0))
    assert gia_tien_ich.gia_nuoc(db, p) == 0


def test_phong_bao_nuoc_van_theo_toa_ve_dien(db):
    """Ghi đè TỪNG cột, không phải cả cụm."""
    b = _toa(db, gia_dien=3800, gia_nuoc=18000)
    p = _phong(db, b, gia_nuoc=0)
    assert gia_tien_ich.gia_nuoc(db, p) == 0
    assert gia_tien_ich.gia_dien(db, p) == 3800


def test_khong_co_phong_thi_ve_hang_so_khong_no(db):
    assert gia_tien_ich.gia_dien(db, None) == 3500


# ── Danh mục key ─────────────────────────────────────────────────────────────


def test_loc_bo_key_la_khong_bao_loi(db):
    """Danh mục còn dài ra; app cũ gửi key server chưa biết không được gãy."""
    assert tien_ich_phong.loc_dich_vu(["gui_xe", "khong_co_that", "rac"]) == [
        "gui_xe",
        "rac",
    ]
    assert tien_ich_phong.loc_do_dac(None) == []
    assert tien_ich_phong.loc_do_dac("may_giat") == []


def test_loc_bo_trung_giu_thu_tu(db):
    assert tien_ich_phong.loc_do_dac(["giuong", "tu_lanh", "giuong"]) == [
        "giuong",
        "tu_lanh",
    ]


def test_hai_danh_muc_khong_dung_chung_key(db):
    """Gộp hai danh sách là mất phân biệt 'trả tiền để lấy gì' vs 'có sẵn gì'."""
    assert not (
        set(tien_ich_phong.DICH_VU_GOM) & set(tien_ich_phong.DO_TRONG_PHONG)
    )


def test_ten_dich_vu_doi_key_sang_tieng_viet(db):
    assert tien_ich_phong.ten_dich_vu(["gui_xe", "rac"]) == ["Gửi xe", "Rác"]
