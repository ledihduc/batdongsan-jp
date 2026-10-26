from typing import Generator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.models as models
from app.auth import sign_token
from app.config import settings
from app.database import Base, get_db
from app.routers.money_ledger_v2 import router

ADMIN, USER = 8201, 8202


@pytest.fixture(scope="module")
def engine():
    value = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(value); yield value; value.dispose()


@pytest.fixture
def db(engine) -> Generator[Session, None, None]:
    conn = engine.connect(); tx = conn.begin(); session = sessionmaker(bind=conn)()
    session.add_all([models.User(id=ADMIN, name="Admin", email="ledger-admin@test.vn", phone="", password_hash="x", role="admin"), models.User(id=USER, name="User", email="ledger-user@test.vn", phone="", password_hash="x", role="guest")]); session.commit()
    yield session; session.close(); tx.rollback(); conn.close()


@pytest.fixture
def client(db, monkeypatch):
    monkeypatch.setattr(settings, "money_ledger_v2_enabled", True)
    api = FastAPI(); api.include_router(router)
    def override(): yield db
    api.dependency_overrides[get_db] = override
    with TestClient(api) as value: yield value


def headers(uid=ADMIN, role="admin", key=None):
    result = {"Authorization": f"Bearer {sign_token(uid, role)}"}
    if key: result["Idempotency-Key"] = key
    return result


def payment_body(allocations=None):
    return {"source_type": "INVOICE", "source_id": 99, "payer_user_id": USER, "amount": 1_000_000, "method": "MANUAL_PROOF", "external_reference": "BANK-REF-99", "paid_at": "2026-09-22T10:00:00", "allocations": allocations or [{"allocation_type": "OWNER_NET", "beneficiary_user_id": USER, "amount": 900_000}, {"allocation_type": "PLATFORM_FEE", "amount": 100_000, "rule_version": "v1"}]}


def test_allocation_must_balance_and_command_is_idempotent(client, db):
    bad = payment_body([{"allocation_type": "OWNER_NET", "amount": 900_000}])
    assert client.post("/api/v2/money-ledger/payments", json=bad, headers=headers(key="money-bad-0001")).status_code == 422
    first = client.post("/api/v2/money-ledger/payments", json=payment_body(), headers=headers(key="money-good-0001"))
    replay = client.post("/api/v2/money-ledger/payments", json=payment_body(), headers=headers(key="money-good-0001"))
    assert first.status_code == 201 and first.json()["balanced"] is True
    assert replay.json()["idempotent_replay"] is True
    assert db.query(models.PlatformPayment).count() == 1


def test_refund_appends_and_never_erases_original(client, db):
    payment = client.post("/api/v2/money-ledger/payments", json={**payment_body(), "source_id": 100, "external_reference": "BANK-REF-100"}, headers=headers(key="money-good-0100")).json()
    response = client.post(f"/api/v2/money-ledger/payments/{payment['id']}/refunds", json={"amount": 250_000, "reason_code": "CUSTOMER_CANCELLED"}, headers=headers(key="refund-good-0100"))
    assert response.status_code == 201 and response.json()["amount"] == 1_000_000
    assert response.json()["refunded_amount"] == 250_000
    assert client.post(f"/api/v2/money-ledger/payments/{payment['id']}/refunds", json={"amount": 800_000, "reason_code": "OTHER"}, headers=headers(key="refund-too-high")).status_code == 422


def test_admin_only_and_reconciliation_balances(client):
    assert client.get("/api/v2/money-ledger/reconciliation", headers=headers(USER, "guest")).status_code == 403
    result = client.get("/api/v2/money-ledger/reconciliation", headers=headers()).json()
    assert result["balanced"] is True and result["transfer_execution"] == "DISABLED"


def test_payment_evidence_accepts_only_internal_upload_or_https(client):
    body = {**payment_body(), "source_id": 201, "external_reference": "BANK-REF-201", "evidence_urls": ["http://unsafe.test/proof.jpg"]}
    assert client.post("/api/v2/money-ledger/payments", json=body, headers=headers(key="money-unsafe-201")).status_code == 422
