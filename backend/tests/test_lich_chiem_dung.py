"""R4 · D1 — MỘT dòng thời gian chiếm dụng cho MỌI kênh bán.

Vấn đề gốc: câu "phòng còn trống không" có hai người trả lời không biết nhau —
`reservations` (theo ngày, kênh đêm) và cờ `rooms.status` (vacant/occupied,
không có ngày, kênh tháng). Nên hợp đồng thuê từ 01/10 KHÔNG chặn được ai đặt
đêm 15/10, và chủ nhà không có lịch nào để nhìn, chỉ có một bóng đèn bật/tắt.

Đây là điều kiện CHẶN của việc mở hai kênh cùng lúc trên một phòng.

Test chạy trên SQLite nên không có `EXCLUDE USING gist`; nó canh **lớp truy
vấn** trong service. Lớp DB là lớp thứ hai, chỉ nó chặn được hai request đồng
thời — hai lớp cố ý trùng nhau.
"""

from __future__ import annotations

import os
from datetime import date, timedelta
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.models as models  # noqa: F401
from app.database import Base
from app.services import chiem_dung_service as cd

D = date(2026, 10, 1)


def ngay(n: int) -> date:
    return D + timedelta(days=n)


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


@pytest.fixture
def phong(db: Session) -> models.Room:
    toa = models.Building(host_id=1, name="T", address="x", city="y")
    db.add(toa)
    db.flush()
    p = models.Room(building_id=toa.id, code="P01", base_price=1, status="vacant")
    db.add(p)
    db.flush()
    return p


def test_ghi_duoc_khoang_dau_tien(db, phong):
    k = cd.ghi(db, room_id=phong.id, tu_ngay=ngay(0), den_ngay=ngay(10))
    assert k.id is not None


def test_hop_dong_dai_han_CHAN_don_dat_dem_giua_ky(db, phong):
    """Đây chính là lỗ hổng đang mở nếu bật hai kênh: hai bảng không biết nhau."""
    cd.ghi(
        db,
        room_id=phong.id,
        tu_ngay=ngay(0),
        den_ngay=ngay(180),
        kenh="dai_han",
        nguon=models.RoomChiemDung.CONTRACT,
        nguon_id=1,
    )
    with pytest.raises(cd.TrungLich):
        cd.ghi(
            db,
            room_id=phong.id,
            tu_ngay=ngay(14),
            den_ngay=ngay(17),
            kenh="ngan_han",
            nguon=models.RoomChiemDung.RESERVATION,
            nguon_id=2,
        )


def test_tra_sang_nay_nhan_chieu_nay_KHONG_coi_la_trung(db, phong):
    """`den_ngay` là ngày TRẢ phòng, không tính — nửa khoảng `[)`."""
    cd.ghi(db, room_id=phong.id, tu_ngay=ngay(0), den_ngay=ngay(5))
    k = cd.ghi(db, room_id=phong.id, tu_ngay=ngay(5), den_ngay=ngay(9))
    assert k.id is not None


@pytest.mark.parametrize(
    "tu,den",
    [
        (2, 4),    # nằm gọn bên trong
        (-2, 3),   # trùm đầu
        (8, 12),   # trùm đuôi
        (-1, 11),  # bao trọn
    ],
)
def test_moi_tu_the_chong_lan_deu_bi_chan(db, phong, tu, den):
    """Bốn tư thế chồng lấn — liệt kê tay thì lần nào cũng sót đúng một cái."""
    cd.ghi(db, room_id=phong.id, tu_ngay=ngay(0), den_ngay=ngay(10))
    with pytest.raises(cd.TrungLich):
        cd.ghi(db, room_id=phong.id, tu_ngay=ngay(tu), den_ngay=ngay(den))


def test_phong_KHAC_khong_anh_huong(db, phong):
    toa = db.get(models.Building, phong.building_id)
    p2 = models.Room(building_id=toa.id, code="P02", base_price=1, status="vacant")
    db.add(p2)
    db.flush()
    cd.ghi(db, room_id=phong.id, tu_ngay=ngay(0), den_ngay=ngay(10))
    assert cd.ghi(db, room_id=p2.id, tu_ngay=ngay(0), den_ngay=ngay(10)).id is not None


def test_ngay_tra_truoc_ngay_nhan_bi_chan(db, phong):
    """Khoảng rỗng lọt qua phép chồng lấn (rỗng không chồng ai) nhưng vô nghĩa."""
    with pytest.raises(cd.TrungLich):
        cd.ghi(db, room_id=phong.id, tu_ngay=ngay(5), den_ngay=ngay(5))


def test_ghi_lai_cung_NGUON_la_cap_nhat_khong_phai_them_dong(db, phong):
    """Gia hạn hợp đồng không được đẻ ra dòng thứ hai chồng lên dòng cũ."""
    cd.ghi(
        db,
        room_id=phong.id,
        tu_ngay=ngay(0),
        den_ngay=ngay(10),
        nguon=models.RoomChiemDung.CONTRACT,
        nguon_id=7,
    )
    cd.ghi(
        db,
        room_id=phong.id,
        tu_ngay=ngay(0),
        den_ngay=ngay(30),
        nguon=models.RoomChiemDung.CONTRACT,
        nguon_id=7,
    )
    ds = cd.lich(db, phong.id, ngay(-1), ngay(60))
    assert len(ds) == 1
    assert ds[0].den_ngay == ngay(30)


def test_go_theo_NGUON_khong_trung_khoang_ke_ben(db, phong):
    """Gỡ theo ngày thì một đơn bị huỷ sẽ xoá trúng khoảng của hợp đồng sát cạnh."""
    cd.ghi(
        db,
        room_id=phong.id,
        tu_ngay=ngay(0),
        den_ngay=ngay(5),
        nguon=models.RoomChiemDung.RESERVATION,
        nguon_id=11,
    )
    cd.ghi(
        db,
        room_id=phong.id,
        tu_ngay=ngay(5),
        den_ngay=ngay(40),
        nguon=models.RoomChiemDung.CONTRACT,
        nguon_id=12,
    )
    assert cd.go(db, models.RoomChiemDung.RESERVATION, 11) == 1
    con_lai = cd.lich(db, phong.id, ngay(-1), ngay(60))
    assert len(con_lai) == 1
    assert con_lai[0].nguon == models.RoomChiemDung.CONTRACT


def test_phong_ban_tra_dung_tap_phong(db, phong):
    toa = db.get(models.Building, phong.building_id)
    p2 = models.Room(building_id=toa.id, code="P02", base_price=1, status="vacant")
    db.add(p2)
    db.flush()
    cd.ghi(db, room_id=phong.id, tu_ngay=ngay(0), den_ngay=ngay(10))
    assert cd.phong_ban(db, [phong.id, p2.id], ngay(1), ngay(2)) == {phong.id}
    assert cd.phong_ban(db, [phong.id, p2.id], ngay(20), ngay(22)) == set()
    assert cd.phong_ban(db, [], ngay(1), ngay(2)) == set()
