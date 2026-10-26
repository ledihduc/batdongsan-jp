"""Integration tests for admin API routes (Phase 10).

Tests:
  - All admin endpoints require role=admin (403 for non-admin)
  - GET /api/admin/dashboard/summary returns 200 with expected keys
  - GET /api/admin/audit-trail/{id} returns 404 for missing delegation
  - GET /api/admin/audit-trail/{id} returns 200 with entries
  - GET /api/admin/users/{id}/delegations returns owner/operator breakdown
  - POST /api/admin/delegations/{id}/force-revoke terminates delegation
  - POST /api/admin/users/{id}/suspend-operator pauses active delegations
  - POST /api/admin/users/{id}/reinstate-operator resumes admin_suspend paused
  - GET /api/admin/disputes returns list
  - POST /api/admin/disputes/{id}/escalate transitions to escalated
  - POST /api/admin/disputes/{id}/resolve closes dispute

Uses SQLite in-memory + TestClient.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from app.database import Base, get_db
import app.models  # noqa: F401
import app.domain  # noqa: F401
from app.api.routes.admin_dashboard import router as admin_dashboard_router
from app.api.routes.admin_delegations import router as admin_delegations_router
from app.api.routes.admin_disputes import router as admin_disputes_router
from app.auth import sign_token


def _make_app() -> FastAPI:
    app = FastAPI()
    app.include_router(admin_dashboard_router)
    app.include_router(admin_delegations_router)
    app.include_router(admin_disputes_router)
    return app


@pytest.fixture(scope="module")
def sqlite_engine():
    _engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=_engine)
    yield _engine
    _engine.dispose()


@pytest.fixture
def db_session(sqlite_engine) -> Generator[Session, None, None]:
    """Per-test session on a shared connection — allows client to see seeded data."""
    connection = sqlite_engine.connect()
    transaction = connection.begin()
    _Session = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = _Session()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session: Session) -> Generator[TestClient, None, None]:
    """TestClient that shares the same DB connection as db_session."""
    _app = _make_app()

    def _override_db() -> Generator[Session, None, None]:
        yield db_session

    _app.dependency_overrides[get_db] = _override_db
    with TestClient(_app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture
def admin_token():
    return sign_token(user_id=99999, role="admin")


@pytest.fixture
def host_token():
    return sign_token(user_id=88888, role="host")


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _make_user(db, role="host"):
    from app.models import User
    u = User(
        name="Test",
        email=f"u_{uuid.uuid4().hex[:6]}@test.com",
        phone=f"09{uuid.uuid4().int % 100000000:08d}",
        password_hash="hashed",
        role=role,
    )
    db.add(u)
    db.flush()
    return u


def _make_delegation(db, owner_id, operator_id, status="active", paused_reason=None):
    from app.domain.delegation import Delegation
    d = Delegation(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        operator_id=operator_id,
        status=status,
        paused_reason=paused_reason,
        role_preset="operator_full",
        scope_type="all",
        commission_pct=Decimal("0.05"),
        threshold_monthly_rent_vnd=Decimal("5000000"),
        threshold_term_months=12,
        threshold_expense_vnd=Decimal("2000000"),
        threshold_rent_change_pct=Decimal("5.00"),
        threshold_refund_vnd=Decimal("1000000"),
        poa_format="digital",
        retention_tier="hot",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(d)
    db.flush()
    return d


def _make_tenant_flag(db, tenant_id, operator_user_id, delegation_id=None, status="pending"):
    from app.domain.tenant_authority import TenantAuthorityFlag
    flag = TenantAuthorityFlag(
        id=str(uuid.uuid4()),
        tenant_id=tenant_id,
        reported_operator_user_id=operator_user_id,
        delegation_id=delegation_id,
        report_reason="Unauthorized operator",
        status=status,
        created_at=datetime.utcnow(),
    )
    db.add(flag)
    db.flush()
    return flag


def _make_tenant(db, host_id):
    from app.models import Tenant
    t = Tenant(
        host_id=host_id,
        full_name="Tenant",
        phone=f"09{uuid.uuid4().int % 100000000:08d}",
    )
    db.add(t)
    db.flush()
    return t


# ---------------------------------------------------------------------------
# Auth guard tests
# ---------------------------------------------------------------------------


class TestAdminAuthGuard:
    """All admin endpoints must return 403 for non-admin roles."""

    def test_dashboard_requires_admin(self, client, host_token):
        resp = client.get("/api/admin/dashboard/summary", headers=_auth(host_token))
        assert resp.status_code == 403

    def test_audit_trail_requires_admin(self, client, host_token):
        resp = client.get("/api/admin/audit-trail/some-id", headers=_auth(host_token))
        assert resp.status_code == 403

    def test_user_delegations_requires_admin(self, client, host_token):
        resp = client.get("/api/admin/users/1/delegations", headers=_auth(host_token))
        assert resp.status_code == 403

    def test_force_revoke_requires_admin(self, client, host_token):
        resp = client.post(
            "/api/admin/delegations/some-id/force-revoke",
            json={"reason": "test", "immediate": True},
            headers=_auth(host_token),
        )
        assert resp.status_code == 403

    def test_suspend_operator_requires_admin(self, client, host_token):
        resp = client.post(
            "/api/admin/users/1/suspend-operator",
            json={"reason": "test"},
            headers=_auth(host_token),
        )
        assert resp.status_code == 403

    def test_reinstate_operator_requires_admin(self, client, host_token):
        resp = client.post(
            "/api/admin/users/1/reinstate-operator",
            json={"reason": "test"},
            headers=_auth(host_token),
        )
        assert resp.status_code == 403

    def test_disputes_requires_admin(self, client, host_token):
        resp = client.get("/api/admin/disputes", headers=_auth(host_token))
        assert resp.status_code == 403

    def test_escalate_dispute_requires_admin(self, client, host_token):
        resp = client.post(
            "/api/admin/disputes/some-id/escalate",
            json={"reason": "test"},
            headers=_auth(host_token),
        )
        assert resp.status_code == 403

    def test_resolve_dispute_requires_admin(self, client, host_token):
        resp = client.post(
            "/api/admin/disputes/some-id/resolve",
            json={"outcome": "invalid", "action": "no_action", "reason": "test"},
            headers=_auth(host_token),
        )
        assert resp.status_code == 403

    def test_unauthenticated_returns_401(self, client):
        resp = client.get("/api/admin/dashboard/summary")
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# Dashboard tests
# ---------------------------------------------------------------------------


class TestDashboard:
    def test_summary_returns_200_with_keys(self, client, admin_token):
        resp = client.get("/api/admin/dashboard/summary", headers=_auth(admin_token))
        assert resp.status_code == 200
        data = resp.json()
        assert "pending_kyc_count" in data
        assert "active_delegations_count" in data
        assert "fraud_reports_last_24h_count" in data
        assert "as_of" in data


# ---------------------------------------------------------------------------
# Audit trail tests
# ---------------------------------------------------------------------------


class TestAuditTrail:
    def test_returns_404_for_missing_delegation(self, client, admin_token):
        resp = client.get(
            "/api/admin/audit-trail/00000000-0000-0000-0000-000000000000",
            headers=_auth(admin_token),
        )
        assert resp.status_code == 404

    def test_returns_200_with_empty_entries_for_new_delegation(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        delegation = _make_delegation(db_session, owner.id, op.id)

        resp = client.get(
            f"/api/admin/audit-trail/{delegation.id}",
            headers=_auth(admin_token),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["delegation_id"] == str(delegation.id)
        assert isinstance(data["entries"], list)
        assert "total" in data


# ---------------------------------------------------------------------------
# User delegations tests
# ---------------------------------------------------------------------------


class TestUserDelegations:
    def test_returns_owner_and_operator_lists(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        _make_delegation(db_session, owner.id, op.id)

        resp = client.get(f"/api/admin/users/{op.id}/delegations", headers=_auth(admin_token))
        assert resp.status_code == 200
        data = resp.json()
        assert data["user_id"] == op.id
        assert "as_owner" in data
        assert "as_operator" in data
        assert len(data["as_operator"]) >= 1


# ---------------------------------------------------------------------------
# Force-revoke tests
# ---------------------------------------------------------------------------


class TestForceRevoke:
    def test_terminates_active_delegation(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        delegation = _make_delegation(db_session, owner.id, op.id, status="active")

        resp = client.post(
            f"/api/admin/delegations/{delegation.id}/force-revoke",
            json={"reason": "Court order #2026/001", "immediate": True},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "terminated"
        assert data["delegation_id"] == str(delegation.id)

    def test_returns_404_for_missing_delegation(self, client, admin_token):
        resp = client.post(
            "/api/admin/delegations/00000000-0000-0000-0000-000000000000/force-revoke",
            json={"reason": "Test", "immediate": True},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 404

    def test_requires_reason(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        delegation = _make_delegation(db_session, owner.id, op.id)

        resp = client.post(
            f"/api/admin/delegations/{delegation.id}/force-revoke",
            json={"reason": "   ", "immediate": True},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Suspend / reinstate operator tests
# ---------------------------------------------------------------------------


class TestSuspendReinstateOperator:
    def test_suspend_operator_pauses_active_delegations(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        _make_delegation(db_session, owner.id, op.id, status="active")

        resp = client.post(
            f"/api/admin/users/{op.id}/suspend-operator",
            json={"reason": "Fraud investigation"},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["user_id"] == op.id
        assert data["delegations_paused"] >= 1

    def test_reinstate_operator_resumes_admin_suspended(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        _make_delegation(db_session, owner.id, op.id, status="paused", paused_reason="admin_suspend")

        resp = client.post(
            f"/api/admin/users/{op.id}/reinstate-operator",
            json={"reason": "Investigation cleared"},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["delegations_reinstated"] >= 1


# ---------------------------------------------------------------------------
# Dispute tests
# ---------------------------------------------------------------------------


class TestDisputes:
    def test_list_disputes_returns_200(self, client, admin_token):
        resp = client.get("/api/admin/disputes", headers=_auth(admin_token))
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_escalate_pending_dispute(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        tenant = _make_tenant(db_session, owner.id)
        flag = _make_tenant_flag(db_session, tenant.id, op.id, status="pending")

        resp = client.post(
            f"/api/admin/disputes/{flag.id}/escalate",
            json={"reason": "Urgent — tenant reported active unauthorized transactions"},
            headers=_auth(admin_token),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["dispute_id"] == str(flag.id)
        assert data["status"] == "escalated"

    def test_resolve_dispute_no_action(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        tenant = _make_tenant(db_session, owner.id)
        flag = _make_tenant_flag(db_session, tenant.id, op.id, status="pending")

        resp = client.post(
            f"/api/admin/disputes/{flag.id}/resolve",
            json={
                "outcome": "invalid",
                "action": "no_action",
                "reason": "No credible evidence found",
            },
            headers=_auth(admin_token),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["outcome"] == "invalid"
        assert data["delegation_paused"] is False

    def test_resolve_dispute_pause_delegation(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        tenant = _make_tenant(db_session, owner.id)
        delegation = _make_delegation(db_session, owner.id, op.id, status="active")
        flag = _make_tenant_flag(db_session, tenant.id, op.id, delegation_id=str(delegation.id))

        resp = client.post(
            f"/api/admin/disputes/{flag.id}/resolve",
            json={
                "outcome": "prima_facie_valid",
                "action": "pause_delegation",
                "reason": "Operator acting without authority",
            },
            headers=_auth(admin_token),
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["delegation_paused"] is True

    def test_resolve_invalid_outcome_returns_422(self, client, admin_token, db_session):
        owner = _make_user(db_session)
        op = _make_user(db_session)
        tenant = _make_tenant(db_session, owner.id)
        flag = _make_tenant_flag(db_session, tenant.id, op.id, status="pending")

        resp = client.post(
            f"/api/admin/disputes/{flag.id}/resolve",
            json={
                "outcome": "maybe",
                "action": "no_action",
                "reason": "Test",
            },
            headers=_auth(admin_token),
        )
        assert resp.status_code == 422
