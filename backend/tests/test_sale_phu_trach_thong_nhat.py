"""MỘT quy tắc xác định sale phụ trách, dùng chung mọi nơi.

    sale riêng của PHÒNG  →  sale của TOÀ  →  để TRỐNG
                                              (tuyệt đối không rơi về chủ nhà)

Thứ tự này từng NGƯỢC (toà trước). Sai với thực tế: chủ nhà cho nhiều sale cùng
bán, mỗi người vài phòng — toà thắng thì cả ba phòng của ba sale đều ghi công
cho một người, người đứng tên toà.

Bước cuối là chỗ dễ sai nhất. Rơi về chủ nhà nghe "an toàn" nhưng nó ghi công
bán hàng cho người KHÔNG bán, và làm hỏng đúng con số mà sale ở lại nền tảng vì
nó. Trống là một câu trả lời đúng.
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
from app.services import lich_xem_service, sale_phu_trach

CHU = 950
SALE_TOA = 951
SALE_1, SALE_2, SALE_3 = 952, 953, 954
NGUOI_LA = 955


@pytest.fixture(scope="module")
def engine():
    eng = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}
    )
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


def _nguoi(db: Session, uid: int) -> None:
    if db.get(models.User, uid):
        return
    db.add(
        models.User(
            id=uid,
            name=f"U{uid}",
            email=f"u{uid}_{uuid.uuid4().hex[:4]}@t.com",
            password_hash="x",
            role="guest",
        )
    )
    db.flush()


def _toa_ba_phong(db: Session, sale_toa=SALE_TOA):
    """Toà có BA phòng do BA sale khác nhau phụ trách — ca thật của chủ nhà cho
    nhiều người cùng bán."""
    for u in (CHU, SALE_TOA, SALE_1, SALE_2, SALE_3, NGUOI_LA):
        _nguoi(db, u)
    b = models.Building(
        host_id=CHU, sale_id=sale_toa, name="T", address="x", city="y"
    )
    db.add(b)
    db.flush()
    ps = []
    for i, sale in enumerate((SALE_1, SALE_2, SALE_3)):
        p = models.Room(
            building_id=b.id,
            code=f"P{i}",
            base_price=1,
            status="vacant",
            owner_id=CHU,
            managed_by_sale_id=sale,
        )
        db.add(p)
        db.flush()
        ps.append(p)
    return b, ps


# ── Quy tắc ──────────────────────────────────────────────────────────────────


def test_ba_phong_ba_sale_moi_phong_ghi_cong_DUNG_nguoi(db):
    _, ps = _toa_ba_phong(db)
    assert [sale_phu_trach.sale_cua_phong(db, p) for p in ps] == [
        SALE_1,
        SALE_2,
        SALE_3,
    ], "sale của TOÀ đã nuốt mất sale riêng của từng phòng"


def test_phong_chua_co_sale_rieng_thi_dung_sale_TOA(db):
    b, _ = _toa_ba_phong(db)
    p = models.Room(
        building_id=b.id, code="P9", base_price=1, status="vacant", owner_id=CHU
    )
    db.add(p)
    db.flush()
    assert sale_phu_trach.sale_cua_phong(db, p) == SALE_TOA


def test_khong_co_sale_nao_thi_TRONG_khong_roi_ve_chu_nha(db):
    """Rơi về chủ nhà là ghi công bán hàng cho người KHÔNG bán."""
    _nguoi(db, CHU)
    b = models.Building(host_id=CHU, sale_id=None, name="T", address="x", city="y")
    db.add(b)
    db.flush()
    p = models.Room(
        building_id=b.id, code="P1", base_price=1, status="vacant", owner_id=CHU
    )
    db.add(p)
    db.flush()
    ket = sale_phu_trach.sale_cua_phong(db, p)
    assert ket is None
    assert ket != CHU


def test_tin_sinh_tu_phong_hoi_theo_PHONG_khong_theo_nguoi_dang(db):
    _, ps = _toa_ba_phong(db)
    dm = models.Category(name="C", group_key="stay_long")
    db.add(dm)
    db.flush()
    tin = models.House(
        host_id=CHU,  # chủ nhà tự đăng
        category_id=dm.id,
        title="t",
        description="",
        price=1,
        address="x",
        city="y",
        status="published",
        source_room_id=ps[1].id,
    )
    db.add(tin)
    db.flush()
    assert sale_phu_trach.sale_cua_tin(db, tin) == SALE_2


# ── Mọi nơi phải trả cùng một tên ────────────────────────────────────────────


def test_lich_xem_tra_cung_sale_voi_so_ghi_cong(db):
    """Hai nơi lệch nhau nghĩa là khách nhắn cho một người, công ghi người khác."""
    _, ps = _toa_ba_phong(db)
    p = ps[2]
    neo = lich_xem_service.tra_neo(db, room_id=p.id)
    assert neo.sale_id == sale_phu_trach.sale_cua_phong(db, p) == SALE_3


# ── Quyền thao tác ───────────────────────────────────────────────────────────


def test_sale_cua_TOA_khong_dong_duoc_phong_da_co_sale_rieng(db):
    """Phòng đã có người phụ trách thì đó là hàng của người ta."""
    _, ps = _toa_ba_phong(db)
    assert not sale_phu_trach.duoc_thao_tac_phong(db, ps[0], SALE_TOA)


def test_sale_cua_TOA_thao_tac_duoc_phong_chua_gan_ai(db):
    b, _ = _toa_ba_phong(db)
    p = models.Room(
        building_id=b.id, code="P9", base_price=1, status="vacant", owner_id=CHU
    )
    db.add(p)
    db.flush()
    assert sale_phu_trach.duoc_thao_tac_phong(db, p, SALE_TOA)


def test_sale_khac_khong_dong_duoc_phong_cua_dong_nghiep(db):
    _, ps = _toa_ba_phong(db)
    assert not sale_phu_trach.duoc_thao_tac_phong(db, ps[0], SALE_2)


@pytest.mark.parametrize("uid", [CHU, SALE_1])
def test_chu_nha_va_sale_phu_trach_deu_thao_tac_duoc(db, uid):
    _, ps = _toa_ba_phong(db)
    assert sale_phu_trach.duoc_thao_tac_phong(db, ps[0], uid)


def test_nguoi_la_va_admin(db):
    _, ps = _toa_ba_phong(db)
    assert not sale_phu_trach.duoc_thao_tac_phong(db, ps[0], NGUOI_LA)
    assert sale_phu_trach.duoc_thao_tac_phong(db, ps[0], NGUOI_LA, la_admin=True)
