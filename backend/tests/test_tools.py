"""Tests cho buyer tools: loan calculator (toán thuần) + compare (validation).

SQLite in-memory + TestClient — không cần Postgres. Mirror pattern
tests/test_houses_transaction_type.py.
"""

from __future__ import annotations

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
import app.models  # noqa: F401 — register ORM classes
from app.routers.tools import router as tools_router


@pytest.fixture(scope="module")
def client():
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}
    )
    Base.metadata.create_all(bind=engine)
    TestingSession = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def _override_db():
        db = TestingSession()
        try:
            yield db
        finally:
            db.close()

    app = FastAPI()
    app.include_router(tools_router)
    app.dependency_overrides[get_db] = _override_db
    yield TestClient(app)
    engine.dispose()


# ── Loan calculator ───────────────────────────────────────────────────────────
def test_loan_reducing_math(client):
    r = client.post(
        "/api/tools/loan-calculator",
        json={"amount_vnd": 1_000_000_000, "annual_rate_pct": 12,
              "term_months": 120, "method": "reducing"},
    )
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["method"] == "reducing"
    assert d["monthly_principal"] == round(1_000_000_000 / 120)
    # total_interest = r*P*(n+1)/2 = 0.01*1e9*60.5
    assert d["total_interest"] == round(0.01 * 1_000_000_000 * 121 / 2)
    # tháng đầu trả nhiều hơn tháng cuối (dư nợ giảm dần)
    assert d["first_month_payment"] > d["last_month_payment"]
    assert len(d["schedule_preview"]) == 3


def test_loan_annuity_positive(client):
    r = client.post(
        "/api/tools/loan-calculator",
        json={"amount_vnd": 500_000_000, "annual_rate_pct": 10,
              "term_months": 60, "method": "annuity"},
    )
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["method"] == "annuity"
    assert d["monthly_payment"] > 0
    assert d["total_payment"] > 500_000_000  # có lãi
    assert d["total_interest"] == d["total_payment"] - d["principal_vnd"]


def test_loan_zero_rate(client):
    r = client.post(
        "/api/tools/loan-calculator",
        json={"amount_vnd": 1_200_000, "annual_rate_pct": 0,
              "term_months": 12, "method": "annuity"},
    )
    assert r.status_code == 200
    d = r.json()
    assert d["monthly_payment"] == 100_000
    assert d["total_interest"] == 0


def test_loan_price_with_downpayment(client):
    r = client.post(
        "/api/tools/loan-calculator",
        json={"price_vnd": 2_000_000_000, "down_payment_pct": 30,
              "annual_rate_pct": 11, "term_months": 240},
    )
    assert r.status_code == 200
    assert r.json()["principal_vnd"] == round(2_000_000_000 * 0.7)


def test_loan_requires_amount_or_price(client):
    r = client.post("/api/tools/loan-calculator",
                    json={"annual_rate_pct": 10, "term_months": 120})
    assert r.status_code == 422


# ── Compare (validation, không phụ thuộc dữ liệu House thật) ───────────────────
def test_compare_empty_ids(client):
    assert client.get("/api/tools/compare?ids=").status_code == 422


def test_compare_invalid_id(client):
    assert client.get("/api/tools/compare?ids=abc").status_code == 422


def test_compare_too_many(client):
    assert client.get("/api/tools/compare?ids=1,2,3,4,5").status_code == 422


# Ghi chú: nhánh fetch DB (db.get + house_to_dict) là code sẵn có; test dữ liệu
# thật cần dựng bảng houses/PostGIS nên để integration/e2e xử lý, không unit ở đây.
