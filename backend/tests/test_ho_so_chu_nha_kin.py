"""R2 — hồ sơ CHỦ NHÀ chỉ mở cho chính họ, sale phụ trách, và admin.

Luật nghiệp vụ: sale bỏ công tìm ra chủ nhà, nên quan hệ đó là thứ HỌ SỞ HỮU.
Nếu ai cũng mở được `/api/hosts/{id}` của một chủ nhà thì sale khác chỉ cần quét
id là dựng được danh sách chủ nhà rồi gọi thẳng — và sale không còn lý do đưa
chủ nhà lên nền tảng.

Nhận diện chủ nhà bằng BẰNG CHỨNG, không bằng `role`: cột `role='host'` mang
nghĩa "được vào khu quản lý" và có lịch sử lẫn lộn (nhiều tài khoản bán hàng
thường mang nó chỉ vì từng bấm nhầm một nút). Chặn theo role thì trang bán hàng
hợp lệ của họ tắt ngóm — mà đó không phải người R2 bảo vệ.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime
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
from app.routers import hosts_public
from app.routers.hosts_public import router as hosts_router

SALE = 400
SALE_KHAC = 401
CHU_NHA = 402
NGUOI_BAN_THUONG = 403
ADMIN = 404

TEN_CHU_NHA = "Chu Nha Kin Dao"


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


@pytest.fixture(autouse=True)
def _xoa_cache():
    hosts_public._featured_cache.clear()
    yield
    hosts_public._featured_cache.clear()


@pytest.fixture
def client(db: Session) -> Generator[TestClient, None, None]:
    api = FastAPI()
    api.include_router(hosts_router)

    def _get_db() -> Generator[Session, None, None]:
        yield db

    api.dependency_overrides[get_db] = _get_db
    with TestClient(api, raise_server_exceptions=True) as c:
        yield c


def _auth(uid: int, role: str = "guest") -> dict:
    return {"Authorization": f"Bearer {sign_token(user_id=uid, role=role)}"}


def _nguoi(db: Session, uid: int, ten: str, role: str = "guest", kieu: str = "customer"):
    u = db.get(models.User, uid)
    if u:
        return u
    u = models.User(
        id=uid,
        name=ten,
        email=f"u{uid}_{uuid.uuid4().hex[:4]}@t.com",
        password_hash="x",
        role=role,
        account_type=kieu,
        is_active=True,
    )
    db.add(u)
    db.flush()
    return u


def _boi_canh(db: Session):
    _nguoi(db, SALE, "Sale Van", kieu="sale")
    _nguoi(db, SALE_KHAC, "Sale Khac", kieu="sale")
    _nguoi(db, CHU_NHA, TEN_CHU_NHA, role="host", kieu="owner")
    _nguoi(db, NGUOI_BAN_THUONG, "Nguoi Ban", role="host", kieu="owner")
    _nguoi(db, ADMIN, "Admin", role="admin", kieu="admin")
    # BẰNG CHỨNG: toà đã bàn giao cho CHU_NHA, sale phụ trách là SALE.
    db.add(
        models.Building(
            host_id=CHU_NHA,
            sale_id=SALE,
            claimed_at=datetime.utcnow(),
            name="Toa Hoa Sua",
            address="x",
            city="Hai Phong",
        )
    )
    db.flush()


def test_khach_vang_lai_KHONG_xem_duoc_ho_so_chu_nha(client, db):
    _boi_canh(db)
    r = client.get(f"/api/hosts/{CHU_NHA}")
    # 404 chứ không 403 — 403 xác nhận tài khoản này tồn tại và là chủ nhà.
    assert r.status_code == 404
    assert TEN_CHU_NHA not in r.text


def test_sale_KHAC_cung_khong_xem_duoc(client, db):
    """Đây mới là mối đe doạ thật: người biết dùng hệ thống, không phải khách."""
    _boi_canh(db)
    assert client.get(f"/api/hosts/{CHU_NHA}", headers=_auth(SALE_KHAC)).status_code == 404


def test_sale_PHU_TRACH_xem_duoc(client, db):
    _boi_canh(db)
    r = client.get(f"/api/hosts/{CHU_NHA}", headers=_auth(SALE))
    assert r.status_code == 200, r.text
    assert r.json()["name"] == TEN_CHU_NHA


def test_chinh_chu_xem_duoc_trang_minh(client, db):
    _boi_canh(db)
    assert client.get(f"/api/hosts/{CHU_NHA}", headers=_auth(CHU_NHA, "host")).status_code == 200


def test_admin_xem_duoc(client, db):
    _boi_canh(db)
    assert client.get(f"/api/hosts/{CHU_NHA}", headers=_auth(ADMIN, "admin")).status_code == 200


def test_lien_ket_cu_chua_co_toa_khong_cap_quyen(client, db):
    """Liên kết cũ chưa xác định toà không được mở quyền xem chủ nhà."""
    _nguoi(db, SALE_KHAC, "Sale Khac", kieu="sale")
    chu = _nguoi(db, 405, "Chu Chua Co Toa", role="host", kieu="owner")
    db.add(
        models.SaleOwnerLink(sale_id=SALE_KHAC, owner_id=chu.id, status="active")
    )
    db.flush()
    assert client.get(f"/api/hosts/{chu.id}").status_code == 404
    assert client.get(f"/api/hosts/{chu.id}", headers=_auth(SALE_KHAC)).status_code == 404


def test_nguoi_ban_role_host_NHUNG_khong_phai_chu_nha_van_mo(client, db):
    """Chặn theo `role` sẽ giết trang bán hàng hợp lệ của nhóm này."""
    _boi_canh(db)
    r = client.get(f"/api/hosts/{NGUOI_BAN_THUONG}")
    assert r.status_code == 200, "chặn nhầm người bán thường"


def test_nhan_xet_cung_bi_chan(client, db):
    """Bỏ sót ở đây thì vẫn dò ra chủ nhà qua nhận xét trên tin của họ."""
    _boi_canh(db)
    assert client.get(f"/api/hosts/{CHU_NHA}/reviews").status_code == 404
    assert client.get(f"/api/hosts/{CHU_NHA}/reviews", headers=_auth(SALE)).status_code == 200


def test_chu_nha_khong_lot_vao_danh_sach_tieu_bieu(client, db):
    """Danh sách công khai là một cửa hậu khác của cùng thông tin."""
    _boi_canh(db)
    # Cho chủ nhà một tin đang hiển thị — điều kiện lọt danh sách.
    dm = models.Category(name="Can ho", group_key="stay_long")
    db.add(dm)
    db.flush()
    db.add(
        models.House(
            host_id=CHU_NHA,
            category_id=dm.id,
            title="Tin cua chu nha",
            description="",
            price=1,
            address="x",
            city="Hai Phong",
            status="published",
        )
    )
    db.flush()
    r = client.get("/api/hosts/featured")
    assert TEN_CHU_NHA not in r.text
    assert CHU_NHA not in [h["id"] for h in r.json()["hosts"]]
