"""Thông báo THẬT — trong app luôn có, FCM đi qua hàng đợi.

Gọi FCM thẳng trong hàm xử lý hỏng theo hai chiều:
  * FCM lỗi/chậm → kéo đổ hoặc kéo chậm giao dịch nghiệp vụ. Bán một căn hộ
    thất bại vì Google trả 503 là vô lý.
  * Gọi TRƯỚC commit → có thể báo "phòng đã bán" rồi giao dịch rollback, tức
    báo cho người ta về một việc chưa từng xảy ra.

Mẫu outbox: ghi ý định gửi CÙNG transaction nghiệp vụ. Hai thứ cùng sống hoặc
cùng chết. Tiến trình khác rút hàng và gửi.
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
from app.services.notification import hang_doi_push as hd

CHU = 970
SALE_A = 971
SALE_B = 972


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


def _phong(db: Session):
    for u in (CHU, SALE_A, SALE_B):
        _nguoi(db, u)
    toa = models.Building(host_id=CHU, sale_id=SALE_A, name="T", address="x", city="y")
    db.add(toa)
    db.flush()
    p = models.Room(
        building_id=toa.id, code="P01", base_price=1, status="vacant", owner_id=CHU
    )
    db.add(p)
    db.flush()
    db.add(models.RoomKenh(room_id=p.id, kenh="ban", gia=1, don_vi="tong"))
    db.flush()
    return p


def _tin(db: Session, p, host_id: int, i: int):
    dm = db.query(models.Category).first()
    if dm is None:
        dm = models.Category(name="C", group_key="stay_long")
        db.add(dm)
        db.flush()
    h = models.House(
        host_id=host_id,
        category_id=dm.id,
        title=f"tin {i}",
        description="",
        price=1,
        address="x",
        city="y",
        status="published",
        transaction_type="rent",
        kenh="dai_han",
        source_room_id=p.id,
    )
    db.add(h)
    db.flush()
    return h


# ── Trong app vẫn đầy đủ ─────────────────────────────────────────────────────


def test_moi_tin_bi_dong_deu_co_MOT_dong_trong_app(db):
    """Người ta cần biết TIN NÀO chết, nên trong app là một dòng mỗi tin."""
    p = _phong(db)
    for i in range(3):
        _tin(db, p, SALE_B, i)
    kt.chot_kenh(db, room=p, kenh="ban", trang_thai=models.RoomKenh.DA_BAN)

    n = (
        db.query(models.Notification)
        .filter(
            models.Notification.user_id == SALE_B,
            models.Notification.type == "tin_da_dong",
        )
        .count()
    )
    assert n == 3


# ── Push thì gộp ─────────────────────────────────────────────────────────────


def test_ba_tin_cung_dong_chi_MOT_push(db):
    """Rung ba lần thì lần thứ ba người ta tắt thông báo của cả ứng dụng."""
    p = _phong(db)
    for i in range(3):
        _tin(db, p, SALE_B, i)
    kt.chot_kenh(db, room=p, kenh="ban", trang_thai=models.RoomKenh.DA_BAN)

    n = (
        db.query(models.PushOutbox)
        .filter(models.PushOutbox.user_id == SALE_B)
        .count()
    )
    assert n == 1


def test_hai_nguoi_khac_nhau_van_moi_nguoi_mot_push(db):
    p = _phong(db)
    _tin(db, p, SALE_A, 1)
    _tin(db, p, SALE_B, 2)
    kt.chot_kenh(db, room=p, kenh="ban", trang_thai=models.RoomKenh.DA_BAN)

    ai = {m.user_id for m in db.query(models.PushOutbox).all()}
    assert ai == {SALE_A, SALE_B}


def test_su_kien_KHAC_phong_thi_van_gui_rieng(db):
    """Gộp theo phòng, không gộp theo người — hai phòng là hai việc."""
    p1 = _phong(db)
    p2 = _phong(db)
    for p in (p1, p2):
        _tin(db, p, SALE_B, 1)
        kt.chot_kenh(db, room=p, kenh="ban", trang_thai=models.RoomKenh.DA_BAN)
    assert (
        db.query(models.PushOutbox)
        .filter(models.PushOutbox.user_id == SALE_B)
        .count()
        == 2
    )


# ── Hàng đợi ─────────────────────────────────────────────────────────────────


def test_xep_hang_khong_gui_ngay_chi_ghi_hang_doi(db):
    p = _phong(db)
    _tin(db, p, SALE_B, 1)
    kt.chot_kenh(db, room=p, kenh="ban", trang_thai=models.RoomKenh.DA_BAN)
    m = db.query(models.PushOutbox).filter(models.PushOutbox.user_id == SALE_B).one()
    assert m.gui_luc is None, "đã đánh dấu gửi trong khi chưa ai gửi"
    assert m.so_lan_thu == 0


def test_rut_hang_lay_cu_truoc(db):
    _nguoi(db, SALE_A)
    for i in range(3):
        hd.xep_hang(
            db,
            user_id=SALE_A,
            title=f"t{i}",
            body="b",
            loai="x",
            khoa_gom=f"x:{i}",
        )
    ds = hd.cho_gui(db)
    assert [m.title for m in ds] == ["t0", "t1", "t2"]


def test_gui_hong_thi_GIU_LAI_de_thu_lai_khong_xoa(db):
    """Xoá là mất luôn thông tin 'người này lẽ ra phải được báo'."""
    _nguoi(db, SALE_A)
    hd.xep_hang(db, user_id=SALE_A, title="t", body="b", loai="x", khoa_gom="x:1")
    m = db.query(models.PushOutbox).one()
    hd.danh_dau_hong(db, m, "FCM 503")
    db.flush()
    assert m.so_lan_thu == 1
    assert m.gui_luc is None
    assert "503" in m.loi_cuoi
    assert hd.cho_gui(db) == [m], "mục hỏng phải còn trong hàng đợi"


def test_thu_qua_nhieu_lan_thi_thoi(db):
    """Token của một máy đã gỡ app hỏng vĩnh viễn — thử mãi là đốt hạn mức."""
    _nguoi(db, SALE_A)
    hd.xep_hang(db, user_id=SALE_A, title="t", body="b", loai="x", khoa_gom="x:1")
    m = db.query(models.PushOutbox).one()
    m.so_lan_thu = hd.SO_LAN_TOI_DA
    db.flush()
    assert hd.cho_gui(db) == []


def test_gui_xong_thi_ra_khoi_hang_doi_va_mo_lai_khoa_gom(db):
    _nguoi(db, SALE_A)
    assert hd.xep_hang(
        db, user_id=SALE_A, title="t", body="b", loai="x", khoa_gom="x:1"
    )
    # Còn chờ → không xếp thêm.
    assert not hd.xep_hang(
        db, user_id=SALE_A, title="t2", body="b", loai="x", khoa_gom="x:1"
    )
    m = db.query(models.PushOutbox).one()
    hd.danh_dau_da_gui(db, m)
    db.flush()
    assert hd.cho_gui(db) == []
    # Đã gửi xong thì sự kiện tương tự lần sau vẫn gửi được.
    assert hd.xep_hang(
        db, user_id=SALE_A, title="t3", body="b", loai="x", khoa_gom="x:1"
    )


def test_khong_co_nguoi_nhan_thi_bo_qua(db):
    assert not hd.xep_hang(
        db, user_id=None, title="t", body="b", loai="x", khoa_gom="x:1"
    )
    assert db.query(models.PushOutbox).count() == 0
