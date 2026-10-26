"""Lead 'gọi lại' nhẹ — POST /api/leads (không cần login) + GET /api/admin/leads.

Bất biến: khách vãng lai (không token) tạo được lead; SĐT sai → 422; admin xem
được danh sách; non-admin bị chặn.
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
from app.auth import sign_token
from app.database import Base, get_db
from app.routers.leads import router as leads_router


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
    app = FastAPI()
    app.include_router(leads_router)

    def _get_db():
        yield db

    app.dependency_overrides[get_db] = _get_db
    return TestClient(app)


def _tok(uid: int, role: str = "guest") -> dict:
    return {"Authorization": f"Bearer {sign_token(uid, role)}"}


def test_khach_khong_login_tao_duoc_lead(client):
    r = client.post("/api/leads", json={
        "name": "Nguyễn A", "phone": "0912345678",
        "source": "save_home", "world": "realestate",
    })
    assert r.status_code == 201, r.text
    assert r.json()["status"] == "new"


def test_sdt_sai_tra_422(client):
    r = client.post("/api/leads", json={"name": "A", "phone": "abc"})
    assert r.status_code == 422


def test_admin_xem_duoc_lead_non_admin_bi_chan(client):
    client.post("/api/leads", json={
        "name": "Chị B", "phone": "0900000000", "source": "provider_interest",
    })
    # non-admin (guest) bị chặn
    assert client.get("/api/admin/leads", headers=_tok(1, "guest")).status_code == 403
    # admin xem được
    r = client.get("/api/admin/leads", headers=_tok(9, "admin"))
    assert r.status_code == 200, r.text
    leads = r.json()["leads"]
    assert any(x["phone"] == "0900000000" and x["source"] == "provider_interest"
               for x in leads)
