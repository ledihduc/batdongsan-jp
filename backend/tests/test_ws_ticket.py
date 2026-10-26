"""Vé WebSocket dùng-một-lần.

Bối cảnh: trước đây client mở `/ws?token=<JWT đăng nhập>`. nginx ghi nguyên
query string vào access log → token còn hiệu lực nhiều giờ nằm sẵn trong log.
Đã đo thấy token admin đầy đủ trong `proxy-host-3_access.log` ngày 19/07/2026.

Các bất biến dưới đây giữ cho bản vá không bị gỡ bỏ vô tình, và quan trọng
không kém: giữ cho bản vá KHÔNG mở ra lỗ mới (vé phải vô dụng với API thường).
"""

import time

import pytest
from jose import jwt

from app import auth
from app.config import settings


@pytest.fixture(autouse=True)
def _clear_spent():
    """Chốt dùng-một-lần là state toàn cục — dọn giữa các test."""
    auth._spent_ws_tickets.clear()
    yield
    auth._spent_ws_tickets.clear()


class TestVeHopLe:
    def test_ve_dung_mot_lan_thi_tieu_duoc(self):
        ticket = auth.sign_ws_ticket(7, "host")
        claims = auth.redeem_ws_ticket(ticket)
        assert claims is not None
        assert claims["sub"] == 7
        assert claims["role"] == "host"

    def test_ve_KHONG_dung_lai_duoc(self):
        # Đây là lý do tồn tại của chốt: vé lọt log không được phát lại.
        ticket = auth.sign_ws_ticket(7, "host")
        assert auth.redeem_ws_ticket(ticket) is not None
        assert auth.redeem_ws_ticket(ticket) is None

    def test_ve_song_rat_ngan(self):
        # 30s đủ cho một lần bắt tay, không đủ để hữu ích với người đọc log sau.
        assert auth.WS_TICKET_TTL_SECONDS <= 60
        claims = jwt.decode(
            auth.sign_ws_ticket(1, "guest"), settings.jwt_secret, algorithms=["HS256"]
        )
        assert claims["exp"] - claims["iat"] == auth.WS_TICKET_TTL_SECONDS

    def test_ve_het_han_thi_khong_tieu_duoc(self):
        now = int(time.time())
        expired = jwt.encode(
            {
                "sub": "7",
                "role": "host",
                "typ": "ws",
                "jti": "x" * 12,
                "iat": now - 120,
                "exp": now - 60,
            },
            settings.jwt_secret,
            algorithm="HS256",
        )
        assert auth.redeem_ws_ticket(expired) is None

    def test_moi_ve_co_jti_rieng(self):
        # Trùng jti thì vé thứ hai bị chốt nhầm là "đã dùng".
        a = jwt.decode(auth.sign_ws_ticket(1, "guest"), settings.jwt_secret,
                       algorithms=["HS256"])
        b = jwt.decode(auth.sign_ws_ticket(1, "guest"), settings.jwt_secret,
                       algorithms=["HS256"])
        assert a["jti"] != b["jti"]


class TestKhongMoLoMoi:
    """Phần quan trọng nhất tệp này.

    Chuyển WS sang vé mà quên tách LOẠI token thì vé lại dùng được làm Bearer
    cho API thường — vá một lỗ, mở một lỗ.
    """

    def test_ve_ws_KHONG_dung_lam_bearer_cho_API_thuong(self):
        ticket = auth.sign_ws_ticket(7, "admin")
        assert auth.verify_token(ticket) is None

    def test_JWT_dang_nhap_KHONG_mo_duoc_WebSocket(self):
        # Chiều ngược lại: nếu nhận cả token thường thì bản vá thành vô nghĩa,
        # client cũ vẫn nhét JWT vào URL và log vẫn lộ.
        login = auth.sign_token(7, "admin")
        assert auth.redeem_ws_ticket(login) is None

    def test_token_dang_nhap_cu_KHONG_co_typ_van_dung_binh_thuong(self):
        # Không được làm hỏng phiên của người đang đăng nhập khi deploy.
        claims = auth.verify_token(auth.sign_token(3, "guest"))
        assert claims is not None and claims["sub"] == 3

    def test_chu_ky_sai_thi_tu_choi(self):
        forged = jwt.encode(
            {"sub": "1", "role": "admin", "typ": "ws", "jti": "a" * 12,
             "exp": int(time.time()) + 30},
            "sai-secret",
            algorithm="HS256",
        )
        assert auth.redeem_ws_ticket(forged) is None

    def test_ve_thieu_jti_thi_tu_choi(self):
        # Không có jti thì không chốt được dùng-một-lần → coi như không hợp lệ.
        no_jti = jwt.encode(
            {"sub": "1", "role": "guest", "typ": "ws",
             "exp": int(time.time()) + 30},
            settings.jwt_secret,
            algorithm="HS256",
        )
        assert auth.redeem_ws_ticket(no_jti) is None


class TestDonRac:
    def test_ve_het_han_bi_don_khoi_bo_nho(self):
        # Không dọn thì dict phình vô hạn theo mỗi lần kết nối.
        auth._spent_ws_tickets["cu"] = time.time() - 100
        auth.redeem_ws_ticket(auth.sign_ws_ticket(1, "guest"))
        assert "cu" not in auth._spent_ws_tickets
