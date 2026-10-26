"""Đăng ký / đăng nhập bằng EMAIL **hoặc** SỐ ĐIỆN THOẠI — một ô duy nhất.

Người Việt nhớ số của mình chắc hơn nhớ email, và nhiều người bán chỉ dùng Zalo.
Bắt buộc email lúc đăng ký là một rào chắn ngay ở cửa vào.

Cho đăng nhập bằng SĐT nghĩa là `users.phone` thành **khoá định danh**. Ba thứ
phải giữ, và cả ba đều là chỗ đã làm hỏng sản phẩm thật ở nơi khác:

  1. **Chuẩn hoá.** `+84912345678` và `0912345678` phải là MỘT người, không thì
     đăng ký được hai lần rồi lần sau không ai đăng nhập nổi.
  2. **Ô rỗng không được khớp ai.** Cả `email` lẫn `phone` dùng `''` cho "không
     có"; truy vấn thiếu `<> ''` là gõ chuỗi rỗng đăng nhập trúng người khác.
  3. **Lỗi phải mơ hồ.** Nói rõ "số này chưa đăng ký" là biến ô đăng nhập thành
     công cụ dò danh sách tài khoản.
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
from app.database import Base, get_db
from app.middleware.rate_limit import limiter
from app.routers.auth_router import router as auth_router
from app.services import dinh_danh


# Giới hạn tần suất đăng ký (5/phút) là thật và cần thiết ở prod, nhưng ở đây
# một tệp test tạo hàng chục tài khoản từ cùng một "IP" nên nó chặn hết.
#
# Đặt trong fixture autouse (chạy lúc THỰC THI) chứ không ở cấp module (chạy
# lúc IMPORT): `limiter` dùng chung cả phiên pytest, bật/tắt ở cấp module sẽ đè
# lên nhau tuỳ thứ tự import. Cùng lý do đã ghi ở `test_auth_flows.py`.
@pytest.fixture(autouse=True)
def _tat_rate_limit():
    truoc = limiter.enabled
    limiter.enabled = False
    limiter.reset()
    yield
    limiter.enabled = truoc


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
def client(db: Session) -> Generator[TestClient, None, None]:
    api = FastAPI()
    api.include_router(auth_router)

    def _get_db() -> Generator[Session, None, None]:
        yield db

    api.dependency_overrides[get_db] = _get_db
    with TestClient(api, raise_server_exceptions=True) as c:
        yield c


MK = "Matkhau.123"


def _dang_ky(client, **kw):
    body = {"name": "Người thử", "password": MK}
    body.update(kw)
    return client.post("/api/auth/register", json=body)


def _dang_nhap(client, dinh_danh_raw: str, mk: str = MK):
    return client.post(
        "/api/auth/login", json={"dinh_danh": dinh_danh_raw, "password": mk}
    )


def _email() -> str:
    return f"u{uuid.uuid4().hex[:8]}@test.com"


def _loi(r) -> str:
    """Thông báo lỗi, bất kể vỏ nào.

    App thật bọc lỗi thành `{"error": {"code", "message"}}` bằng handler đăng ký
    ở `main.py`; app rút gọn trong test này không có handler đó nên nhận vỏ mặc
    định `{"detail": …}`. Đọc cả hai để test canh đúng NỘI DUNG chứ không canh
    vỏ — đổi vỏ là việc của tầng khác.
    """
    d = r.json()
    if isinstance(d.get("error"), dict):
        return str(d["error"].get("message", ""))
    return str(d.get("detail", ""))


# ── Chuẩn hoá số ─────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "vao,ra",
    [
        ("0912345678", "0912345678"),
        ("+84912345678", "0912345678"),
        ("84912345678", "0912345678"),
        ("0912 345 678", "0912345678"),
        ("0912.345.678", "0912345678"),
        ("+84 912 345 678", "0912345678"),
        ("0812345678", "0812345678"),
    ],
)
def test_moi_cach_viet_ve_MOT_dang(vao, ra):
    assert dinh_danh.chuan_hoa_sdt(vao) == ra


@pytest.mark.parametrize(
    "xau",
    [
        "0212345678",   # số bàn — không ai đăng nhập bằng số văn phòng dùng chung
        "8478553330",   # dữ liệu cũ lệch chuẩn: KHÔNG đoán bừa
        "091234567",    # thiếu chữ số
        "09123456789",  # thừa chữ số
        "abc",
        "",
        None,
    ],
)
def test_khong_doan_bua_so_la(xau):
    assert dinh_danh.chuan_hoa_sdt(xau) == ""


# ── Đăng ký ──────────────────────────────────────────────────────────────────


def test_dang_ky_chi_bang_EMAIL(client):
    assert _dang_ky(client, email=_email()).status_code == 201


def test_dang_ky_chi_bang_SDT(client):
    r = _dang_ky(client, phone="0912345678")
    assert r.status_code == 201, r.text
    assert r.json()["user"]["email"] == ""


def test_dang_ky_KHONG_co_gi_thi_chan(client):
    r = _dang_ky(client)
    assert r.status_code == 400
    assert "email hoặc số điện thoại" in _loi(r).lower()


def test_so_luu_ve_DANG_CHUAN_du_go_kieu_gi(client, db):
    _dang_ky(client, phone="+84 912 345 678")
    u = db.query(models.User).filter(models.User.phone != "").first()
    assert u.phone == "0912345678"


def test_so_SAI_thi_bao_ngay_khong_lang_le_bo_di(client):
    """Bỏ lặng thì người dùng tưởng đã đăng ký bằng số đó, lần sau không vào được."""
    r = _dang_ky(client, email=_email(), phone="0212345678")
    assert r.status_code == 400
    assert "điện thoại" in _loi(r).lower()


def test_so_TRUNG_bi_chan(client):
    _dang_ky(client, phone="0912345678")
    r = _dang_ky(client, phone="0912345678")
    assert r.status_code == 409


def test_so_trung_o_DANG_KHAC_cung_bi_chan(client):
    """`+84…` và `0…` là một người — chuẩn hoá trước rồi mới kiểm trùng."""
    _dang_ky(client, phone="0912345678")
    r = _dang_ky(client, phone="+84912345678")
    assert r.status_code == 409


def test_HAI_nguoi_khong_co_email_deu_dang_ky_duoc(client):
    """`''` là "không có", không phải một giá trị bị chiếm chỗ."""
    assert _dang_ky(client, phone="0912345678").status_code == 201
    assert _dang_ky(client, phone="0987654321").status_code == 201


# ── Đăng nhập ────────────────────────────────────────────────────────────────


def test_dang_nhap_bang_email(client):
    em = _email()
    _dang_ky(client, email=em)
    assert _dang_nhap(client, em).status_code == 200


def test_dang_nhap_bang_EMAIL_VIET_HOA(client):
    em = _email()
    _dang_ky(client, email=em)
    assert _dang_nhap(client, em.upper()).status_code == 200


def test_dang_nhap_bang_sdt(client):
    _dang_ky(client, phone="0912345678")
    assert _dang_nhap(client, "0912345678").status_code == 200


def test_dang_nhap_bang_sdt_go_kieu_KHAC(client):
    """Đăng ký `0912…`, đăng nhập `+84912…` — vẫn phải vào được."""
    _dang_ky(client, phone="0912345678")
    assert _dang_nhap(client, "+84 912 345 678").status_code == 200


def test_nguoi_co_CA_HAI_dang_nhap_duoc_bang_ca_hai(client):
    em = _email()
    _dang_ky(client, email=em, phone="0912345678")
    assert _dang_nhap(client, em).status_code == 200
    assert _dang_nhap(client, "0912345678").status_code == 200


def test_o_RONG_khong_khop_ai(client):
    """Thiếu `<> ''` trong truy vấn thì chuỗi rỗng khớp mọi tài khoản chưa có
    email — và người đầu tiên trong nhóm đó bị đăng nhập nhờ."""
    _dang_ky(client, phone="0912345678")  # tài khoản này có email = ''
    assert _dang_nhap(client, "").status_code == 401


def test_sai_mat_khau_va_khong_ton_tai_bao_GIONG_NHAU(client):
    """Khác thông báo là dò được ai đã đăng ký."""
    em = _email()
    _dang_ky(client, email=em)
    a = _dang_nhap(client, em, "SaiBet.999")
    b = _dang_nhap(client, _email(), MK)
    c = _dang_nhap(client, "khong-phai-gi-ca", MK)
    assert a.status_code == b.status_code == c.status_code == 401
    assert _loi(a) == _loi(b) == _loi(c)


def test_khoa_cu_email_van_chay(client):
    """App bản cũ trên máy người dùng vẫn gửi khoá `email` — không được gãy
    giữa lúc deploy."""
    em = _email()
    _dang_ky(client, email=em)
    r = client.post("/api/auth/login", json={"email": em, "password": MK})
    assert r.status_code == 200
