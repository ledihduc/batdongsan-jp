"""Phân loại TIN theo pipeline — đọc cột, KHÔNG đoán từ chuỗi.

Bản cũ đoán bằng cách khớp CHUỖI CON trên `product_type`:

    'homestay' hoặc 'short' trong product_type → ngan_han
    còn lại                                    → dai_han

Hai hậu quả:
1. `product_type` là mã LOẠI BĐS (`apartment`, `house`, `land`…), không phải
   kênh khai thác. Đổi tên danh mục là đổi nghiệp vụ một cách âm thầm.
2. **Mặt bằng rơi hết vào `dai_han`** — nên chốt một mặt bằng sẽ đóng nhầm tin
   căn hộ cho thuê của cùng phòng, và ngược lại.

Bất biến quan trọng nhất ở đây: **tin CHO THUÊ không bao giờ đóng kênh BÁN.**
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
from app.services import khai_thac_service as kt

CHU = 960
SALE = 961


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


def _tin(db: Session, **kw) -> models.House:
    for uid in (CHU, SALE):
        if not db.get(models.User, uid):
            db.add(
                models.User(
                    id=uid,
                    name=f"U{uid}",
                    email=f"u{uid}_{uuid.uuid4().hex[:4]}@t.com",
                    password_hash="x",
                    role="guest",
                )
            )
    dm = db.query(models.Category).first()
    if dm is None:
        dm = models.Category(name="C", group_key="stay_long")
        db.add(dm)
    db.flush()
    goc = dict(
        host_id=SALE,
        category_id=dm.id,
        title="t",
        description="",
        price=1,
        address="x",
        city="y",
        status="published",
        transaction_type="rent",
    )
    goc.update(kw)
    h = models.House(**goc)
    db.add(h)
    db.flush()
    return h


# ── Đọc cột, không đoán ──────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "kenh", ["ngan_han", "dai_han", "mat_bang"]
)
def test_tin_thue_tra_dung_kenh_da_ghi(db, kenh):
    assert kt.kenh_cua_tin(_tin(db, kenh=kenh)) == kenh


def test_tin_BAN_luon_la_kenh_ban_du_cot_kenh_ghi_gi(db):
    """`transaction_type` là trục giao dịch — nó thắng mọi thứ."""
    h = _tin(db, transaction_type="sale", kenh="dai_han")
    assert kt.kenh_cua_tin(h) == "ban"


def test_KHONG_con_doan_tu_product_type(db):
    """Đây là ca bản cũ trả 'ngan_han'. Nay `product_type` không còn tiếng nói."""
    h = _tin(db, product_type="homestay_apartment", kenh="dai_han")
    assert kt.kenh_cua_tin(h) == "dai_han"


def test_kenh_la_hoac_rong_thi_ve_dai_han(db):
    for xau in ("", "thue_tau_vu_tru", "ban"):
        assert kt.kenh_cua_tin(_tin(db, kenh=xau)) == "dai_han"


# ── Bất biến: tin CHO THUÊ không bao giờ đóng kênh BÁN ───────────────────────


def _phong_hai_kenh(db: Session):
    toa = models.Building(host_id=CHU, sale_id=SALE, name="T", address="x", city="y")
    db.add(toa)
    db.flush()
    p = models.Room(
        building_id=toa.id, code="P01", base_price=1, status="vacant", owner_id=CHU
    )
    db.add(p)
    db.flush()
    for k in ("dai_han", "mat_bang", "ban"):
        db.add(
            models.RoomKenh(
                room_id=p.id,
                kenh=k,
                gia=1,
                don_vi=models.RoomKenh.DON_VI_MAC_DINH[k],
            )
        )
    db.flush()
    return p


@pytest.mark.parametrize("kenh_chot", ["dai_han", "mat_bang"])
def test_chot_kenh_THUE_khong_bao_gio_dong_tin_BAN(db, kenh_chot):
    p = _phong_hai_kenh(db)
    tin_ban = _tin(db, transaction_type="sale", kenh="ban", source_room_id=p.id)
    tin_thue = _tin(db, kenh=kenh_chot, source_room_id=p.id)

    kt.chot_kenh(
        db, room=p, kenh=kenh_chot, trang_thai=models.RoomKenh.DA_CHO_THUE
    )
    db.refresh(tin_ban)
    db.refresh(tin_thue)
    assert tin_ban.status == "published", "chốt THUÊ đã gỡ mất tin BÁN"
    assert tin_thue.status == "closed"


def test_chot_MAT_BANG_khong_dong_tin_thue_DAI_HAN(db):
    """Bản cũ gộp cả hai vào 'dai_han' nên chốt cái này đóng nhầm cái kia."""
    p = _phong_hai_kenh(db)
    dai_han = _tin(db, kenh="dai_han", source_room_id=p.id)
    mat_bang = _tin(db, kenh="mat_bang", source_room_id=p.id)

    kt.chot_kenh(
        db, room=p, kenh="mat_bang", trang_thai=models.RoomKenh.DA_CHO_THUE
    )
    db.refresh(dai_han)
    db.refresh(mat_bang)
    assert mat_bang.status == "closed"
    assert dai_han.status == "published", "chốt MẶT BẰNG đóng nhầm tin dài hạn"


def test_chot_BAN_van_quet_sach_moi_kenh(db):
    """Chiều ngược lại KHÔNG đối xứng — bán rồi thì không cho thuê được nữa."""
    p = _phong_hai_kenh(db)
    ds = [
        _tin(db, transaction_type="sale", kenh="ban", source_room_id=p.id),
        _tin(db, kenh="dai_han", source_room_id=p.id),
        _tin(db, kenh="mat_bang", source_room_id=p.id),
    ]
    kt.chot_kenh(db, room=p, kenh="ban", trang_thai=models.RoomKenh.DA_BAN)
    for h in ds:
        db.refresh(h)
        assert h.status == "closed"
