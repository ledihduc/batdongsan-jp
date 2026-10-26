"""Chặn người dùng (Apple Guideline 1.2 — UGC).

Kiểm: chặn/bỏ chặn/danh sách + không tự chặn mình + 404 người lạ + yêu cầu
đăng nhập. Dùng sqlite in-memory nên LUÔN chạy.
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
from app.database import Base, get_db
from app.middleware.rate_limit import limiter
from app.routers.auth_router import router as auth_router
from app.routers.blocks import router as blocks_router


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
    api.include_router(blocks_router)

    def _get_db():
        yield db

    api.dependency_overrides[get_db] = _get_db
    return TestClient(api, raise_server_exceptions=False)


def _reg(client, email):
    r = client.post(
        "/api/auth/register",
        json={"name": "U", "email": email, "password": "MatKhau123"},
    )
    assert r.status_code == 201, r.text
    return r.json()["token"], r.json()["user"]["id"]


def test_chan_bo_chan_va_danh_sach(client):
    tok_a, _ = _reg(client, "a@ex.com")
    _, id_b = _reg(client, "b@ex.com")
    h = {"Authorization": f"Bearer {tok_a}"}

    r = client.post(f"/api/social/blocks/{id_b}", headers=h)
    assert r.status_code == 201 and r.json()["blocked"] is True

    lst = client.get("/api/social/blocks", headers=h)
    assert lst.status_code == 200
    assert any(x["user_id"] == id_b for x in lst.json()["blocked"])

    # Idempotent — chặn lại không lỗi.
    assert client.post(f"/api/social/blocks/{id_b}", headers=h).status_code == 201

    r = client.delete(f"/api/social/blocks/{id_b}", headers=h)
    assert r.status_code == 200 and r.json()["blocked"] is False
    assert client.get("/api/social/blocks", headers=h).json()["blocked"] == []


def test_khong_the_tu_chan_minh(client):
    tok_a, id_a = _reg(client, "self@ex.com")
    r = client.post(
        f"/api/social/blocks/{id_a}", headers={"Authorization": f"Bearer {tok_a}"}
    )
    assert r.status_code == 400


def test_chan_nguoi_khong_ton_tai_404(client):
    tok_a, _ = _reg(client, "x@ex.com")
    r = client.post(
        "/api/social/blocks/999999", headers={"Authorization": f"Bearer {tok_a}"}
    )
    assert r.status_code == 404


def test_chan_yeu_cau_dang_nhap(client):
    assert client.post("/api/social/blocks/1").status_code == 401
