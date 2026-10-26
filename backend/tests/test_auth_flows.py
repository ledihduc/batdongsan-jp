"""Xác thực: đăng ký · đăng nhập · quên mật khẩu.

Vì sao có tệp này: trước đây auth chỉ có `test_auth_register_role_whitelist.py`,
mà cả 3 test trong đó đều `skipif` khi thiếu `SMOKE_DATABASE_URL` → trong lần
chạy bình thường auth có **0 test thực sự chạy**, dù đây là cổng vào cả hệ
thống. Bộ test này dùng sqlite trong bộ nhớ nên LUÔN chạy.
"""

from __future__ import annotations

import os
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.models  # noqa: F401
from app import auth, models
from app.database import Base, get_db
from app.middleware.rate_limit import limiter
from app.routers.auth_router import router as auth_router

# TẮT rate limit cho bộ test này: mọi request từ TestClient dùng chung một "IP"
# nên giới hạn 5-10 req/phút sẽ chặn ngay từ test thứ vài, làm test đỏ vì lý do
# không liên quan tới thứ đang kiểm. Hành vi giới hạn kiểm riêng ở
# test_auth_rate_limit.py.
#
# Đặt trong fixture autouse (chạy lúc THỰC THI) chứ không ở cấp module (chạy
# lúc IMPORT): limiter là đối tượng dùng chung cả phiên pytest, tệp test khác
# bật/tắt nó sẽ đè lên nhau tuỳ thứ tự import — đã làm 7 test đỏ khi chạy full
# suite dù xanh khi chạy riêng.
@pytest.fixture(autouse=True)
def _tat_rate_limit():
    truoc = limiter.enabled
    limiter.enabled = False
    limiter.reset()
    yield
    limiter.enabled = truoc


@pytest.fixture(scope="module")
def engine():
    e = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=e)
    yield e
    e.dispose()


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
def client(db) -> TestClient:
    api = FastAPI()
    api.include_router(auth_router)

    def _get_db():
        yield db

    api.dependency_overrides[get_db] = _get_db
    # raise_server_exceptions=False để thấy 500 thật thay vì vỡ test runner.
    return TestClient(api, raise_server_exceptions=False)


def _dang_ky(client: TestClient, email: str, mk: str = "MatKhau123", **extra):
    body = {"name": "Nguoi Dung", "email": email, "password": mk}
    body.update(extra)
    return client.post("/api/auth/register", json=body)


# ── Đăng ký ───────────────────────────────────────────────────────────────────

def test_dang_ky_thanh_cong_tra_token_va_role_guest_customer(client):
    r = _dang_ky(client, "a@example.com")
    assert r.status_code == 201, r.text
    data = r.json()
    assert data["token"]
    assert data["user"]["role"] == "guest"
    assert data["user"]["account_type"] == "customer"
    assert data["user"]["login_account_types"] == ["customer", "sale", "owner"]


@pytest.mark.parametrize("role_gui", ["admin", "host"])
def test_dang_ky_KHONG_the_tu_phong_role(client, role_gui):
    """Chốt an toàn: gửi role=admin/host khi đăng ký vẫn phải ra 'guest'."""
    r = _dang_ky(client, f"{role_gui}@example.com", role=role_gui)
    assert r.status_code == 201, r.text
    assert r.json()["user"]["role"] == "guest"


def test_dang_ky_trung_email_bi_tu_choi(client):
    assert _dang_ky(client, "trung@example.com").status_code == 201
    r = _dang_ky(client, "trung@example.com")
    assert r.status_code == 409


def test_dang_ky_mat_khau_qua_ngan_bi_tu_choi(client):
    r = _dang_ky(client, "ngan@example.com", mk="12345")
    assert r.status_code == 400


def test_dang_ky_email_sai_dinh_dang_bi_tu_choi(client):
    r = _dang_ky(client, "khong-phai-email")
    assert r.status_code == 400


def test_dang_ky_thieu_thong_tin_bi_tu_choi(client):
    r = client.post("/api/auth/register", json={"email": "x@example.com"})
    assert r.status_code == 400


def test_mat_khau_KHONG_luu_dang_tho(client, db):
    _dang_ky(client, "hash@example.com", mk="MatKhau123")
    u = db.query(models.User).filter(models.User.email == "hash@example.com").first()
    assert u is not None
    assert u.password_hash != "MatKhau123"
    assert u.password_hash.startswith("$2")  # bcrypt


# ── Đăng nhập ─────────────────────────────────────────────────────────────────

def test_dang_nhap_dung_tra_token(client):
    _dang_ky(client, "login@example.com", mk="MatKhau123")
    r = client.post(
        "/api/auth/login",
        json={"email": "login@example.com", "password": "MatKhau123"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["token"]


def test_dang_nhap_sai_mat_khau_bi_tu_choi(client):
    _dang_ky(client, "sai@example.com", mk="MatKhau123")
    r = client.post(
        "/api/auth/login",
        json={"email": "sai@example.com", "password": "SaiBetNhe"},
    )
    assert r.status_code == 401


def test_thong_bao_loi_KHONG_phan_biet_email_sai_hay_mat_khau_sai(client):
    """Chống dò tài khoản: hai ca phải trả về y hệt nhau, nếu khác thì kẻ tấn
    công biết được email nào đã đăng ký."""
    _dang_ky(client, "co-that@example.com", mk="MatKhau123")
    sai_mk = client.post(
        "/api/auth/login",
        json={"email": "co-that@example.com", "password": "SaiBetNhe"},
    )
    khong_co = client.post(
        "/api/auth/login",
        json={"email": "khong-ton-tai@example.com", "password": "SaiBetNhe"},
    )
    assert sai_mk.status_code == khong_co.status_code == 401
    assert sai_mk.json() == khong_co.json()


def test_dang_nhap_email_khong_phan_biet_hoa_thuong(client):
    _dang_ky(client, "hoa@example.com", mk="MatKhau123")
    r = client.post(
        "/api/auth/login",
        json={"email": "HOA@Example.COM", "password": "MatKhau123"},
    )
    assert r.status_code == 200, r.text


# ── Quên mật khẩu (ĐÃ TẮT) ────────────────────────────────────────────────────

@pytest.mark.parametrize("role,business_type,selected", [
    ("guest", "customer", "customer"),
    ("guest", "customer", "sale"),
    ("guest", "customer", "owner"),
    ("guest", "sale", "sale"),
    ("guest", "owner", "owner"),
    ("host", "customer", "owner"),  # legacy host with no assets yet
    ("host", "owner", "customer"),  # choosing customer must not change JWT role
    ("admin", "customer", "admin"),
    ("admin", "customer", "sale"),
    ("admin", "customer", "owner"),
])
def test_login_selected_role_uses_existing_capabilities(client, db, role, business_type, selected):
    _dang_ky(client, "roles@example.com")
    user = db.query(models.User).filter_by(email="roles@example.com").one()
    user.role, user.account_type = role, business_type
    db.commit()

    response = client.post("/api/auth/login", json={
        "dinh_danh": user.email, "password": "MatKhau123", "login_account_type": selected,
    })
    assert response.status_code == 200, response.text
    data = response.json()
    assert selected in data["user"]["login_account_types"]
    assert data["user"]["role"] == role
    assert data["user"]["account_type"] == business_type
    assert auth.verify_token(data["token"])["role"] == role
    assert user.role == role and user.account_type == business_type


@pytest.mark.parametrize("selected", ["admin"])
def test_login_denied_role_never_signs_token(client, db, monkeypatch, selected):
    _dang_ky(client, "no-access@example.com")
    signed = []
    monkeypatch.setattr(auth, "sign_token", lambda *args: signed.append(args))
    response = client.post("/api/auth/login", json={
        "email": "no-access@example.com", "password": "MatKhau123", "login_account_type": selected,
    })
    assert response.status_code == 403, response.text
    assert "token" not in response.json()
    assert signed == []
    user = db.query(models.User).filter_by(email="no-access@example.com").one()
    assert (user.role, user.account_type) == ("guest", "customer")


def test_business_admin_label_does_not_grant_system_admin(client, db):
    _dang_ky(client, "label@example.com")
    user = db.query(models.User).filter_by(email="label@example.com").one()
    user.account_type = "admin"
    db.commit()
    response = client.post("/api/auth/login", json={
        "email": user.email, "password": "MatKhau123", "login_account_type": "admin",
    })
    assert response.status_code == 403
    assert "token" not in response.json()


@pytest.mark.parametrize("ownership", ["building", "room"])
def test_profile_and_ownership_allow_multiple_roles_and_survive_me(client, db, ownership):
    _dang_ky(client, "multi@example.com")
    user = db.query(models.User).filter_by(email="multi@example.com").one()
    db.add(models.SaleProfile(user_id=user.id, sale_code="SL-TEST-MULTI"))
    building = models.Building(host_id=user.id if ownership == "building" else 999, name="Test")
    db.add(building)
    db.flush()
    if ownership == "room":
        db.add(models.Room(building_id=building.id, code="P01", owner_id=user.id))
    db.commit()

    for selected in ("customer", "sale", "owner"):
        response = client.post("/api/auth/login", json={
            "email": user.email, "password": "MatKhau123", "login_account_type": selected,
        })
        assert response.status_code == 200, response.text
        data = response.json()
        assert data["user"]["login_account_types"] == ["customer", "sale", "owner"]
        assert auth.verify_token(data["token"])["role"] == "guest"
        me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {data['token']}"})
        assert me.status_code == 200, me.text
        assert me.json()["user"]["login_account_types"] == data["user"]["login_account_types"]


@pytest.mark.parametrize("selected", ["root", "host", "", ["admin"], 42])
def test_login_rejects_invalid_selector(client, monkeypatch, selected):
    signed = []
    monkeypatch.setattr(auth, "sign_token", lambda *args: signed.append(args))
    response = client.post("/api/auth/login", json={
        "email": "unknown@example.com", "password": "MatKhau123", "login_account_type": selected,
    })
    assert response.status_code == 422
    assert "token" not in response.json()
    assert signed == []


def test_bad_password_and_unknown_account_same_error_even_with_admin_selector(client):
    _dang_ky(client, "exists@example.com")
    responses = [client.post("/api/auth/login", json={
        "email": email, "password": "wrong-password", "login_account_type": "admin",
    }) for email in ("exists@example.com", "unknown@example.com")]
    assert responses[0].status_code == responses[1].status_code == 401
    assert responses[0].json() == responses[1].json()


@pytest.mark.parametrize("selected", ["customer", "sale", "owner", "admin"])
def test_disabled_account_cannot_select_any_mode(client, db, selected):
    _dang_ky(client, "disabled@example.com")
    user = db.query(models.User).filter_by(email="disabled@example.com").one()
    user.is_active = False
    db.commit()
    response = client.post("/api/auth/login", json={
        "email": user.email, "password": "MatKhau123", "login_account_type": selected,
    })
    assert response.status_code == 401
    assert "token" not in response.json()


def test_register_ignores_login_selection_and_business_role(client):
    response = _dang_ky(client, "register-role@example.com", account_type="admin", login_account_type="admin")
    assert response.status_code == 201
    assert response.json()["user"]["role"] == "guest"
    assert response.json()["user"]["account_type"] == "customer"


def test_legacy_host_login_and_activity_agree_on_owner_access(client, db):
    from app.services.manage_read_model import available_modes

    _dang_ky(client, "legacy-host@example.com")
    user = db.query(models.User).filter_by(email="legacy-host@example.com").one()
    user.role = "host"
    db.commit()
    response = client.post("/api/auth/login", json={
        "email": user.email, "password": "MatKhau123", "login_account_type": "owner",
    })
    assert response.status_code == 200
    assert response.json()["user"]["login_account_types"] == available_modes(db, user)


def test_quen_mat_khau_KHONG_BAO_GIO_tra_mat_khau(client):
    """Bản cũ đổi mật khẩu nạn nhân rồi TRẢ CHÍNH mật khẩu đó trong response —
    ai biết email là chiếm được tài khoản.

    Endpoint nay chỉ báo nhận yêu cầu (200) thay vì 410: màn quên-mật-khẩu ở FE
    gọi qua `ApiClient`, mà lớp đó ném `ApiException` với MỌI mã non-2xx, nên
    410 làm người dùng thấy màn báo lỗi thay vì hướng dẫn. Đổi mã trạng thái
    KHÔNG nới lỏng gì — điều phải giữ là ba khẳng định dưới đây, và chúng mới là
    thứ test này canh.

    Trước đây test khoá cứng con số 410; khi ai đó đổi sang 200 thì nó đỏ, bị
    coi là "lỗi tồn đọng" rồi bỏ qua — lan can gãy đúng lúc cần nhất.
    """
    r = client.post("/api/auth/forgot-password", json={"email": "a@example.com"})
    assert r.status_code == 200
    # 1) Không rò mật khẩu dưới BẤT KỲ tên trường nào.
    assert "temp_password" not in r.text
    assert "password" not in r.json()


def test_quen_mat_khau_KHONG_lam_lo_email_nao_da_dang_ky(client):
    """2) Email có thật / không có phải trả GIỐNG HỆT nhau — cả mã lẫn thân."""
    _dang_ky(client, "ton-tai@example.com")
    co = client.post("/api/auth/forgot-password", json={"email": "ton-tai@example.com"})
    khong = client.post("/api/auth/forgot-password", json={"email": "zzz@example.com"})
    assert co.status_code == khong.status_code == 200
    assert co.json() == khong.json()


def test_quen_mat_khau_KHONG_doi_mat_khau_cua_ai(client, db):
    """Chốt quan trọng nhất: gọi endpoint này KHÔNG được đụng vào mật khẩu."""
    _dang_ky(client, "nguyen-ven@example.com", mk="MatKhau123")
    truoc = (
        db.query(models.User)
        .filter(models.User.email == "nguyen-ven@example.com")
        .first()
        .password_hash
    )
    client.post("/api/auth/forgot-password", json={"email": "nguyen-ven@example.com"})
    db.expire_all()
    sau = (
        db.query(models.User)
        .filter(models.User.email == "nguyen-ven@example.com")
        .first()
        .password_hash
    )
    assert truoc == sau
    # Và mật khẩu cũ vẫn đăng nhập được.
    r = client.post(
        "/api/auth/login",
        json={"email": "nguyen-ven@example.com", "password": "MatKhau123"},
    )
    assert r.status_code == 200


# ── Giới hạn độ dài mật khẩu (bcrypt cắt ngầm quá 72 byte) ────────────────────

def test_dang_ky_mat_khau_qua_72_byte_bi_tu_choi(client):
    r = _dang_ky(client, "dai@example.com", mk="a" * 73)
    assert r.status_code == 400
    assert "72" in r.json().get("detail", "")


def test_mat_khau_dung_72_byte_van_duoc_chap_nhan(client):
    r = _dang_ky(client, "vua-du@example.com", mk="a" * 72)
    assert r.status_code == 201, r.text


def test_gioi_han_tinh_theo_BYTE_khong_phai_ky_tu(client):
    """Tiếng Việt có dấu tốn 2-3 byte/ký tự — 40 ký tự "ệ" đã vượt 72 byte dù
    nhìn ngắn hơn nhiều so với 72 ký tự latin."""
    mk = "ệ" * 40
    assert len(mk) < 72 and len(mk.encode("utf-8")) > 72
    r = _dang_ky(client, "tieng-viet@example.com", mk=mk)
    assert r.status_code == 400


# ── Đổi mật khẩu làm chết token cũ ────────────────────────────────────────────

def test_doi_mat_khau_vo_hieu_hoa_token_CU(client):
    """Ca thực tế: nghi bị lộ tài khoản -> đổi mật khẩu -> kẻ đang giữ token cũ
    phải bị đuổi NGAY, không được dùng tiếp tới khi token hết hạn (7 ngày)."""
    r = _dang_ky(client, "doi-mk@example.com", mk="MatKhau123")
    token_cu = r.json()["token"]
    dau = {"Authorization": f"Bearer {token_cu}"}

    doi = client.post(
        "/api/auth/change-password",
        json={"old_password": "MatKhau123", "new_password": "MatKhauMoi456"},
        headers=dau,
    )
    assert doi.status_code == 200, doi.text

    # Token CŨ phải chết.
    lai = client.post(
        "/api/auth/change-password",
        json={"old_password": "MatKhauMoi456", "new_password": "ThuLanNua789"},
        headers=dau,
    )
    assert lai.status_code == 401


def test_doi_mat_khau_tra_token_MOI_de_chinh_minh_khong_bi_dang_xuat(client):
    r = _dang_ky(client, "token-moi@example.com", mk="MatKhau123")
    dau = {"Authorization": f"Bearer {r.json()['token']}"}
    doi = client.post(
        "/api/auth/change-password",
        json={"old_password": "MatKhau123", "new_password": "MatKhauMoi456"},
        headers=dau,
    )
    assert doi.status_code == 200
    token_moi = doi.json().get("token")
    assert token_moi, "phải cấp token mới, nếu không người vừa đổi bị đăng xuất theo"
    # Token mới dùng được ngay.
    tiep = client.post(
        "/api/auth/change-password",
        json={"old_password": "MatKhauMoi456", "new_password": "MatKhauBa789"},
        headers={"Authorization": f"Bearer {token_moi}"},
    )
    assert tiep.status_code == 200, tiep.text


# ── Xoá tài khoản (Apple 5.1.1(v) + Google Play bắt buộc) ─────────────────────

def test_xoa_tai_khoan_dung_mat_khau_an_danh_hoa_va_vo_hieu(client, db):
    r = _dang_ky(client, "xoa@example.com", mk="MatKhau123")
    dau = {"Authorization": f"Bearer {r.json()['token']}"}
    uid = r.json()["user"]["id"]

    xoa = client.post(
        "/api/auth/delete-account",
        json={"password": "MatKhau123"},
        headers=dau,
    )
    assert xoa.status_code == 200, xoa.text

    u = db.get(models.User, uid)
    assert u.is_active is False
    assert u.name == "Người dùng đã xoá"
    assert u.email != "xoa@example.com"   # email cá nhân đã bị xoá
    assert u.phone == "" and u.id_number is None

    # Không thể đăng nhập lại bằng thông tin cũ.
    login = client.post(
        "/api/auth/login",
        json={"email": "xoa@example.com", "password": "MatKhau123"},
    )
    assert login.status_code == 401


def test_xoa_tai_khoan_sai_mat_khau_bi_tu_choi(client, db):
    r = _dang_ky(client, "xoa-sai@example.com", mk="MatKhau123")
    dau = {"Authorization": f"Bearer {r.json()['token']}"}
    xoa = client.post(
        "/api/auth/delete-account",
        json={"password": "SAI-mat-khau"},
        headers=dau,
    )
    assert xoa.status_code == 401
    # Vẫn còn hoạt động — không bị xoá nhầm.
    u = db.query(models.User).filter(models.User.email == "xoa-sai@example.com").first()
    assert u is not None and u.is_active is True


def test_xoa_tai_khoan_chua_dang_nhap_bi_tu_choi(client):
    xoa = client.post("/api/auth/delete-account", json={"password": "x"})
    assert xoa.status_code == 401
