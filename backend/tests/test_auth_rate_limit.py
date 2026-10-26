"""Giới hạn tần suất trên các endpoint xác thực.

Vì sao quan trọng: trước đây tầng ứng dụng KHÔNG giới hạn gì, nginx chỉ chặn ở
mức 100 req/s — tức vẫn cho dò hàng nghìn mật khẩu mỗi phút. Test này khoá lại
hành vi chặn để không ai gỡ decorator mà không ai biết.
"""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import app.models  # noqa: F401
from app.database import Base, get_db
from app.middleware.rate_limit import limiter
from app.routers.auth_router import router as auth_router


@pytest.fixture
def client():
    e = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=e)
    conn = e.connect()
    s = sessionmaker(bind=conn, autoflush=False, autocommit=False)()

    api = FastAPI()
    # Phải gắn limiter + handler như main.py, nếu không slowapi không có state
    # để đếm và decorator sẽ ném lỗi thay vì trả 429.
    api.state.limiter = limiter
    api.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    api.include_router(auth_router)
    def _get_db():
        yield s

    api.dependency_overrides[get_db] = _get_db

    # Bộ test khác tắt limiter (dùng chung tiến trình) → bật lại cho đúng phạm vi.
    truoc = limiter.enabled
    limiter.enabled = True
    limiter.reset()
    yield TestClient(api, raise_server_exceptions=False)
    limiter.enabled = truoc
    limiter.reset()
    s.close()
    conn.close()
    e.dispose()


def test_dang_nhap_bi_chan_sau_nhieu_lan_thu(client):
    """Dò mật khẩu phải bị chặn — giới hạn 10/phút."""
    ma = [
        client.post(
            "/api/auth/login",
            json={"email": "dothu@example.com", "password": f"sai{i}"},
        ).status_code
        for i in range(14)
    ]
    assert 429 in ma, f"không có lần nào bị chặn: {ma}"
    # Những lần đầu vẫn phải được xử lý bình thường (401), không chặn ngay từ đầu.
    assert ma[0] == 401


def test_dang_ky_bi_chan_sau_nhieu_lan(client):
    """Chống tạo tài khoản hàng loạt — giới hạn 5/phút."""
    ma = [
        client.post(
            "/api/auth/register",
            json={
                "name": "N",
                "email": f"spam{i}@example.com",
                "password": "MatKhau123",
            },
        ).status_code
        for i in range(9)
    ]
    assert 429 in ma, f"không có lần nào bị chặn: {ma}"
