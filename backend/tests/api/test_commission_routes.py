"""Unit tests for commission API routes.

Tests:
  - IDOR guard: operator can only see own dashboard
  - IDOR guard: owner can only see own report
  - Admin bypass: admin can see any dashboard/report
  - Bad period format → 422
  - Happy path: returns correct response structure

Uses FastAPI TestClient with dependency overrides (no real DB).
"""

from __future__ import annotations

import os
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes.commission import router as commission_router
from app.database import get_db


def _make_app() -> FastAPI:
    app = FastAPI()
    app.include_router(commission_router)
    return app


def _override_db() -> MagicMock:
    """Minimal mock DB session."""
    db = MagicMock()
    # Mock User lookup for owner name
    user = MagicMock()
    user.name = "Test Owner"
    db.get.return_value = user
    # Empty delegation query
    query = MagicMock()
    db.query.return_value = query
    query.filter.return_value = query
    query.all.return_value = []
    return db


# ── Fixtures ──────────────────────────────────────────────────────────────────


@pytest.fixture(scope="module")
def app() -> FastAPI:
    return _make_app()


@pytest.fixture(scope="module")
def client(app: FastAPI) -> TestClient:
    db_mock = _override_db()
    app.dependency_overrides[get_db] = lambda: db_mock
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c
    app.dependency_overrides.clear()


def _host_token(user_id: int = 1) -> str:
    from app.auth import sign_token
    return sign_token(user_id=user_id, role="host")


def _admin_token() -> str:
    from app.auth import sign_token
    return sign_token(user_id=999, role="admin")


# ── Period validation ──────────────────────────────────────────────────────────


def test_dashboard_bad_period_format(client: TestClient) -> None:
    """Bad period format → 422 (Unprocessable Entity)."""
    resp = client.get(
        "/api/commission/operator/1/dashboard",
        params={"period": "2026/07"},  # wrong separator
        headers={"Authorization": f"Bearer {_host_token(1)}"},
    )
    assert resp.status_code == 422


def test_dashboard_bad_period_month_13(client: TestClient) -> None:
    """Month 13 → 422."""
    resp = client.get(
        "/api/commission/operator/1/dashboard",
        params={"period": "2026-13"},
        headers={"Authorization": f"Bearer {_host_token(1)}"},
    )
    assert resp.status_code == 422


def test_owner_report_bad_period(client: TestClient) -> None:
    """Bad period → 422 for owner report too."""
    resp = client.get(
        "/api/commission/owner/1/report",
        params={"period": "invalid"},
        headers={"Authorization": f"Bearer {_host_token(1)}"},
    )
    assert resp.status_code == 422


# ── IDOR guard: operator dashboard ────────────────────────────────────────────


def test_dashboard_idor_blocked(client: TestClient) -> None:
    """Operator 2 cannot see operator 1's dashboard."""
    resp = client.get(
        "/api/commission/operator/1/dashboard",
        params={"period": "2026-07"},
        headers={"Authorization": f"Bearer {_host_token(user_id=2)}"},
    )
    assert resp.status_code == 403


def test_dashboard_own_access_allowed(client: TestClient) -> None:
    """Operator can see their own dashboard."""
    resp = client.get(
        "/api/commission/operator/1/dashboard",
        params={"period": "2026-07"},
        headers={"Authorization": f"Bearer {_host_token(user_id=1)}"},
    )
    # Service returns empty dashboard (no delegations in mock)
    assert resp.status_code == 200
    data = resp.json()
    assert data["operator_id"] == 1
    assert data["period"] == "2026-07"
    assert data["total_commission_amount"] == 0.0
    assert data["per_owner"] == []


def test_dashboard_admin_bypass(client: TestClient) -> None:
    """Admin can see any operator's dashboard."""
    resp = client.get(
        "/api/commission/operator/99/dashboard",
        params={"period": "2026-07"},
        headers={"Authorization": f"Bearer {_admin_token()}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["operator_id"] == 99


# ── IDOR guard: owner report ───────────────────────────────────────────────────


def test_owner_report_idor_blocked(client: TestClient) -> None:
    """Owner 2 cannot see owner 1's commission report."""
    resp = client.get(
        "/api/commission/owner/1/report",
        params={"period": "2026-07"},
        headers={"Authorization": f"Bearer {_host_token(user_id=2)}"},
    )
    assert resp.status_code == 403


def test_owner_report_own_access_allowed(client: TestClient) -> None:
    """Owner can see their own commission report."""
    # Override db to return empty invoice list for owner query
    app_instance = _make_app()
    db_mock = MagicMock()
    query = MagicMock()
    db_mock.query.return_value = query
    query.filter.return_value = query
    query.order_by.return_value = query
    query.all.return_value = []

    app_instance.dependency_overrides[get_db] = lambda: db_mock
    with TestClient(app_instance, raise_server_exceptions=False) as c:
        resp = c.get(
            "/api/commission/owner/5/report",
            params={"period": "2026-07"},
            headers={"Authorization": f"Bearer {_host_token(user_id=5)}"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["owner_id"] == 5
    assert data["period"] == "2026-07"
    assert data["invoices"] == []
    assert data["total_commission_paid_to_operators"] == 0.0


def test_owner_report_admin_bypass(client: TestClient) -> None:
    """Admin can see any owner's report."""
    app_instance = _make_app()
    db_mock = MagicMock()
    query = MagicMock()
    db_mock.query.return_value = query
    query.filter.return_value = query
    query.order_by.return_value = query
    query.all.return_value = []

    app_instance.dependency_overrides[get_db] = lambda: db_mock
    with TestClient(app_instance, raise_server_exceptions=False) as c:
        resp = c.get(
            "/api/commission/owner/100/report",
            params={"period": "2026-07"},
            headers={"Authorization": f"Bearer {_admin_token()}"},
        )

    assert resp.status_code == 200
    assert resp.json()["owner_id"] == 100


# ── Missing period param ───────────────────────────────────────────────────────


def test_dashboard_missing_period(client: TestClient) -> None:
    """Missing period query param → 422."""
    resp = client.get(
        "/api/commission/operator/1/dashboard",
        headers={"Authorization": f"Bearer {_host_token(1)}"},
    )
    assert resp.status_code == 422


def test_owner_report_missing_period(client: TestClient) -> None:
    """Missing period → 422 for owner report."""
    resp = client.get(
        "/api/commission/owner/1/report",
        headers={"Authorization": f"Bearer {_host_token(1)}"},
    )
    assert resp.status_code == 422


# ── Unauthenticated request ────────────────────────────────────────────────────


def test_dashboard_unauthenticated(client: TestClient) -> None:
    """No auth token → 401 or 403."""
    resp = client.get(
        "/api/commission/operator/1/dashboard",
        params={"period": "2026-07"},
    )
    assert resp.status_code in (401, 403)
