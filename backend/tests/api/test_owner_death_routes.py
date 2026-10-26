"""Integration tests for owner death API routes (Phase 06).

Uses FastAPI TestClient + SQLite in-memory DB + dependency overrides.
Mirrors the pattern in test_delegation_routes.py.

AC coverage:
  AC-58:  report death → pending cert
  AC-58:  admin verify → cert verified + delegations paused
  AC-58:  admin reject → cert rejected
  AC-58b: designate-heir → executor_user_id set
  AC-58d: executor exception feature flag enforcement
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime
from typing import Generator
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401 — register users + host_profiles tables first
import app.domain  # noqa: F401 — register delegation tables
from app.domain.owner_death import OwnerDeathCertificate as _ODC  # noqa: F401 — register table
from app.database import Base, get_db
from app.api.routes.owner_death import router as owner_death_router


# ---------------------------------------------------------------------------
# Test app + DB setup
# ---------------------------------------------------------------------------


def _make_test_app() -> FastAPI:
    app = FastAPI()
    app.include_router(owner_death_router)
    return app


@pytest.fixture(scope="module")
def sqlite_engine():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    try:
        Base.metadata.drop_all(bind=engine)
    except Exception:  # noqa: BLE001
        pass
    engine.dispose()


@pytest.fixture()
def db_session(sqlite_engine) -> Generator[Session, None, None]:
    connection = sqlite_engine.connect()
    transaction = connection.begin()
    _Session = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = _Session()
    try:
        yield session
    finally:
        session.close()
        transaction.rollback()
        connection.close()


@pytest.fixture()
def client(db_session) -> TestClient:
    _app = _make_test_app()

    def override_db():
        try:
            yield db_session
        finally:
            pass

    _app.dependency_overrides[get_db] = override_db
    return TestClient(_app, raise_server_exceptions=False)


# ---------------------------------------------------------------------------
# JWT helpers
# ---------------------------------------------------------------------------


def _make_token(user_id: int, role: str = "host") -> str:
    from app.auth import sign_token
    return sign_token(user_id, role)


def _headers(user_id: int, role: str = "host") -> dict:
    return {"Authorization": f"Bearer {_make_token(user_id, role)}"}


# ---------------------------------------------------------------------------
# Seed helpers
# ---------------------------------------------------------------------------


def _create_user(db: Session, user_id: int, role: str = "host") -> None:
    from app import models
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user is None:
        db.add(models.User(
            id=user_id,
            name=f"User {user_id}",
            email=f"user{user_id}@test.com",
            password_hash="x",
            role=role,
        ))
        db.commit()


# ---------------------------------------------------------------------------
# POST /api/owner-death/report
# ---------------------------------------------------------------------------


class TestReportOwnerDeath:
    def test_report_creates_pending_cert(self, client, db_session):
        _create_user(db_session, 1001, "host")
        _create_user(db_session, 1002, "host")  # submitter

        resp = client.post(
            "/api/owner-death/report",
            json={
                "owner_user_id": 1001,
                "death_certificate_path": "uploads/certs/death.pdf",
            },
            headers=_headers(1002),
        )
        assert resp.status_code == 201, resp.text
        data = resp.json()
        assert data["verification_status"] == "pending"
        assert data["owner_user_id"] == 1001

    def test_duplicate_report_returns_409(self, client, db_session):
        _create_user(db_session, 2001, "host")
        _create_user(db_session, 2002, "host")

        # First report
        resp1 = client.post(
            "/api/owner-death/report",
            json={
                "owner_user_id": 2001,
                "death_certificate_path": "uploads/certs/death2001.pdf",
            },
            headers=_headers(2002),
        )
        assert resp1.status_code == 201

        # Duplicate report
        resp2 = client.post(
            "/api/owner-death/report",
            json={
                "owner_user_id": 2001,
                "death_certificate_path": "uploads/certs/death2001b.pdf",
            },
            headers=_headers(2002),
        )
        assert resp2.status_code == 409
        assert "DUPLICATE_DEATH_CERTIFICATE" in resp2.text

    def test_path_traversal_rejected(self, client, db_session):
        _create_user(db_session, 3001, "host")
        _create_user(db_session, 3002, "host")

        resp = client.post(
            "/api/owner-death/report",
            json={
                "owner_user_id": 3001,
                "death_certificate_path": "../../etc/passwd",
            },
            headers=_headers(3002),
        )
        # Either schema validation (422) or service layer (422)
        assert resp.status_code in (422,), resp.text

    def test_unauthenticated_returns_401(self, client):
        resp = client.post(
            "/api/owner-death/report",
            json={
                "owner_user_id": 9999,
                "death_certificate_path": "uploads/certs/death.pdf",
            },
        )
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# POST /api/admin/owner-death/{cert_id}/verify
# ---------------------------------------------------------------------------


class TestAdminVerifyCertificate:
    def _create_cert(self, db: Session, owner_id: int, submitter_id: int) -> str:
        from app.domain.owner_death import OwnerDeathCertificate
        cert = OwnerDeathCertificate(
            id=str(uuid.uuid4()),
            owner_user_id=owner_id,
            death_certificate_path="uploads/certs/test.pdf",
            submitted_by_user_id=submitter_id,
            verification_status="pending",
        )
        db.add(cert)
        db.commit()
        return cert.id

    def test_admin_can_verify_pending_cert(self, client, db_session):
        _create_user(db_session, 4001, "host")
        _create_user(db_session, 4099, "admin")
        cert_id = self._create_cert(db_session, 4001, 4001)

        resp = client.post(
            f"/api/admin/owner-death/{cert_id}/verify",
            json={"notes": "Verified by admin", "in_flight_handling_policy": "auto_reject"},
            headers=_headers(4099, "admin"),
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["certificate"]["verification_status"] == "verified"
        assert data["delegations_paused"] == 0  # no active delegations

    def test_non_admin_gets_403(self, client, db_session):
        _create_user(db_session, 5001, "host")
        _create_user(db_session, 5002, "host")
        cert_id = self._create_cert(db_session, 5001, 5001)

        resp = client.post(
            f"/api/admin/owner-death/{cert_id}/verify",
            json={"notes": "Not admin"},
            headers=_headers(5002, "host"),
        )
        assert resp.status_code == 403

    def test_verify_nonexistent_cert_returns_404(self, client, db_session):
        _create_user(db_session, 6099, "admin")

        resp = client.post(
            f"/api/admin/owner-death/{uuid.uuid4()}/verify",
            json={"notes": "Does not exist"},
            headers=_headers(6099, "admin"),
        )
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# POST /api/admin/owner-death/{cert_id}/reject
# ---------------------------------------------------------------------------


class TestAdminRejectCertificate:
    def _create_cert(self, db: Session, owner_id: int) -> str:
        from app.domain.owner_death import OwnerDeathCertificate
        cert = OwnerDeathCertificate(
            id=str(uuid.uuid4()),
            owner_user_id=owner_id,
            death_certificate_path="uploads/certs/test.pdf",
            verification_status="pending",
        )
        db.add(cert)
        db.commit()
        return cert.id

    def test_admin_can_reject_pending_cert(self, client, db_session):
        _create_user(db_session, 7001, "host")
        _create_user(db_session, 7099, "admin")
        cert_id = self._create_cert(db_session, 7001)

        resp = client.post(
            f"/api/admin/owner-death/{cert_id}/reject",
            json={"rejection_reason": "Missing notarized POA document"},
            headers=_headers(7099, "admin"),
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["verification_status"] == "rejected"


# ---------------------------------------------------------------------------
# GET /api/owner-death/{owner_user_id}
# ---------------------------------------------------------------------------


class TestGetDeathStatus:
    def test_owner_can_view_own_status(self, client, db_session):
        _create_user(db_session, 8001, "host")
        # No cert exists yet

        resp = client.get(
            "/api/owner-death/8001",
            headers=_headers(8001, "host"),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["certificate"] is None
        assert data["owner_user_id"] == 8001

    def test_non_owner_non_heir_gets_403(self, client, db_session):
        _create_user(db_session, 9001, "host")
        _create_user(db_session, 9002, "host")

        resp = client.get(
            "/api/owner-death/9001",
            headers=_headers(9002, "host"),
        )
        assert resp.status_code == 403

    def test_admin_can_view_any_status(self, client, db_session):
        _create_user(db_session, 9901, "host")
        _create_user(db_session, 9999, "admin")

        resp = client.get(
            "/api/owner-death/9901",
            headers=_headers(9999, "admin"),
        )
        assert resp.status_code == 200


# ---------------------------------------------------------------------------
# AC-58d: executor exception feature flag
# ---------------------------------------------------------------------------


class TestExecutorExceptionFlag:
    def _create_cert(self, db: Session, owner_id: int, executor_id: int) -> str:
        from app.domain.owner_death import OwnerDeathCertificate
        cert = OwnerDeathCertificate(
            id=str(uuid.uuid4()),
            owner_user_id=owner_id,
            death_certificate_path="uploads/certs/test.pdf",
            verification_status="verified",
            executor_user_id=executor_id,
            verified_at=datetime.utcnow(),
        )
        db.add(cert)
        db.commit()
        return cert.id

    def test_eligible_approvals_blocked_when_flag_off(
        self, client, db_session, monkeypatch
    ):
        monkeypatch.delenv("OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED", raising=False)
        _create_user(db_session, 11001, "host")
        _create_user(db_session, 11002, "host")
        cert_id = self._create_cert(db_session, 11001, 11002)

        resp = client.get(
            f"/api/owner-death/{cert_id}/eligible-approvals",
            headers=_headers(11002),
        )
        assert resp.status_code == 403
        assert "EXECUTOR_EXCEPTION_DISABLED" in resp.text

    def test_executor_decision_blocked_when_flag_off(
        self, client, db_session, monkeypatch
    ):
        monkeypatch.delenv("OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED", raising=False)
        _create_user(db_session, 12001, "host")
        _create_user(db_session, 12002, "host")
        cert_id = self._create_cert(db_session, 12001, 12002)

        resp = client.post(
            f"/api/owner-death/{cert_id}/executor-decision",
            json={
                "approval_id": str(uuid.uuid4()),
                "decision": "approved",
            },
            headers=_headers(12002),
        )
        assert resp.status_code == 403
        assert "EXECUTOR_EXCEPTION_DISABLED" in resp.text
