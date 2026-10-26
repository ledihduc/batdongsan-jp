"""
pytest conftest — Postgres smoke test fixtures.

Postgres smoke tests (Phase 01): pytest-postgresql managed instance.
Real DB with alembic-managed schema; transactional rollback per test.

JWT secret is set to TEST_ONLY value via env var.

NOTE: Planning router stripped in JP fork (Phase 03). Legacy planning
fixtures removed; conftest no longer builds a minimal planning app.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any, Generator
from unittest.mock import MagicMock

import pytest

# ── Environment MUST be set before any app.* import ──────────────────────────
os.environ["DATABASE_URL"] = "postgresql://localhost/fake_test"
os.environ["JWT_SECRET"] = "test-secret-xyz-never-use-in-prod"

# Purge cached app modules to pick up the env vars above
import sys

_TO_PURGE = [k for k in sys.modules if k.startswith(("app", "main"))]
for _k in _TO_PURGE:
    del sys.modules[_k]


# ── Planning minimal test app REMOVED (JP fork Phase 03) ──────────────────────
# Planning router was stripped from the JP fork; the minimal FastAPI test app
# and its fixtures are no longer needed. get_db import kept for use elsewhere.
from app.database import get_db  # noqa: F401


# ── Shared canned data ────────────────────────────────────────────────────────

CANNED_PARCEL: dict[str, Any] = {
    "parcel_id": "Q1-001-TEST",
    "zone_code": "ODT",
    "zone_name": "Đất ở đô thị",
    "zone_color": "#F5F5F5",
    "area_m2": 120.5,
    "sheet_no": "001",
    "parcel_no": "100",
    "district": "Quận 1",
    "layer_key": "landuse_2030",
    "fetched_at": datetime(2025, 1, 15, 0, 0, tzinfo=timezone.utc),
    "geometry": {
        "type": "Polygon",
        "coordinates": [
            [
                [106.69, 10.77],
                [106.70, 10.77],
                [106.70, 10.78],
                [106.69, 10.78],
                [106.69, 10.77],
            ]
        ],
    },
}

CANNED_DISTRICTS: list[dict[str, Any]] = [
    {"district": "Quận 1", "parcel_count": 1250},
    {"district": "Quận 3", "parcel_count": 980},
    {"district": "Bình Thạnh", "parcel_count": 2100},
]

CANNED_RISKY_LISTINGS: list[dict[str, Any]] = [
    {
        "id": 1,
        "title": "Căn hộ gần đường mở rộng",
        "latitude": 10.77,
        "longitude": 106.69,
        "zone_code": "DGT",
        "zone_name": "Đất giao thông",
    }
]

CANNED_ETL_RUNS: list[dict[str, Any]] = [
    {
        "id": 1,
        "district": "Quận 1",
        "layer_key": "landuse_2030",
        "status": "success",
        "parcels_upserted": 1250,
        "error_msg": None,
        "started_at": datetime(2025, 1, 15, 2, 0, tzinfo=timezone.utc),
        "finished_at": datetime(2025, 1, 15, 2, 15, tzinfo=timezone.utc),
    }
]


# ── Fake DB ───────────────────────────────────────────────────────────────────


class FakeResult:
    """Mimics sqlalchemy CursorResult with .mappings().first() / .all()."""

    def __init__(self, rows: list[dict]) -> None:
        self._rows = rows

    def mappings(self) -> "FakeResult":
        return self

    def first(self) -> dict | None:
        return self._rows[0] if self._rows else None

    def all(self) -> list[dict]:
        return list(self._rows)


class FakeSession:
    """
    Minimal Session replacement for planning service tests.
    Intercepts db.execute(...) and db.commit() calls without touching Postgres.
    """

    def __init__(self, rows: list[dict] | None = None) -> None:
        self._rows: list[dict] = rows or []
        self.committed = False
        self.execute_calls: list[tuple[Any, dict]] = []

    def configure(self, rows: list[dict] | None) -> None:
        """Set rows returned by next execute() call."""
        self._rows = rows or []

    def execute(self, stmt: Any, params: dict | None = None) -> FakeResult:
        self.execute_calls.append((stmt, params or {}))
        return FakeResult(self._rows)

    def commit(self) -> None:
        self.committed = True

    def close(self) -> None:
        pass


# ── pytest fixtures ───────────────────────────────────────────────────────────


@pytest.fixture(scope="session")
def app_instance():
    """Return the minimal test FastAPI app."""
    return _test_app


@pytest.fixture(scope="session")
def fake_db_session() -> FakeSession:
    """Single shared FakeSession for the test session."""
    return FakeSession()


@pytest.fixture(scope="session")
def client(app_instance, fake_db_session):
    """
    TestClient with get_db overridden to avoid real Postgres.
    scope=session — app built once per test run.
    """
    from fastapi.testclient import TestClient

    def _override_get_db() -> Generator[FakeSession, None, None]:
        yield fake_db_session

    app_instance.dependency_overrides[get_db] = _override_get_db
    with TestClient(app_instance, raise_server_exceptions=False) as c:
        yield c
    app_instance.dependency_overrides.pop(get_db, None)


@pytest.fixture
def admin_token() -> str:
    """JWT with role=admin, sub=999."""
    from app.auth import sign_token
    return sign_token(user_id=999, role="admin")


@pytest.fixture
def user_token() -> str:
    """JWT with role=guest, sub=1."""
    from app.auth import sign_token
    return sign_token(user_id=1, role="guest")


# ── DB state fixtures (configure FakeSession per test) ────────────────────────


@pytest.fixture
def parcel_db(fake_db_session) -> FakeSession:
    """Configure fake_db to return a single canned parcel row."""
    fake_db_session.configure([CANNED_PARCEL])
    return fake_db_session


@pytest.fixture
def empty_db(fake_db_session) -> FakeSession:
    """Configure fake_db to return no rows."""
    fake_db_session.configure([])
    return fake_db_session


@pytest.fixture
def districts_db(fake_db_session) -> FakeSession:
    """Configure fake_db to return 3 district rows."""
    fake_db_session.configure(CANNED_DISTRICTS)
    return fake_db_session


@pytest.fixture
def risky_db(fake_db_session) -> FakeSession:
    """Configure fake_db to return risky listing rows."""
    fake_db_session.configure(CANNED_RISKY_LISTINGS)
    return fake_db_session


@pytest.fixture
def etl_runs_db(fake_db_session) -> FakeSession:
    """Configure fake_db to return ETL run history rows."""
    fake_db_session.configure(CANNED_ETL_RUNS)


# ── Postgres smoke test fixtures (Phase 01) ───────────────────────────────────
# These fixtures use pytest-postgresql to spin up a real Postgres instance.
# Scope: session (DB created once) + function (transactional rollback per test).
# Requires: pg_ctl in PATH (Homebrew: brew install postgresql@16).
# In CI: uses DATABASE_URL env var pointing to GH Actions postgres service.


def _get_smoke_db_url() -> str:
    """Return the DB URL for Postgres smoke tests.

    SMOKE_DATABASE_URL takes priority over DATABASE_URL. This separation is needed
    because conftest.py sets DATABASE_URL to a fake value for planning tests.
    In CI, set SMOKE_DATABASE_URL=postgresql://postgres:postgres@localhost:5432/test_db
    For local dev, set SMOKE_DATABASE_URL=postgresql://ancu365:...@localhost:5433/ancu365
    """
    url = os.getenv("SMOKE_DATABASE_URL", "")
    if not url or not url.startswith("postgresql"):
        return ""
    return url


@pytest.fixture(scope="session")
def pg_smoke_engine():
    """Session-scoped SQLAlchemy engine for smoke tests against real Postgres.

    Uses SMOKE_DATABASE_URL env var — NEVER the module-level fake DATABASE_URL.
    Skips all tests in test_smoke_postgres.py if SMOKE_DATABASE_URL is not set.
    Creates all Base tables (idempotent — tables already exist from alembic upgrade head).
    """
    from sqlalchemy import create_engine as _ce
    import sys as _sys

    url = _get_smoke_db_url()
    if not url:
        pytest.skip(
            "SMOKE_DATABASE_URL not set — skipping Postgres smoke tests. "
            "Set SMOKE_DATABASE_URL=postgresql://user:pass@host:port/db to run these tests."
        )

    # Re-import app modules with the correct DATABASE_URL (not the fake one)
    for mod in list(_sys.modules.keys()):
        if mod.startswith("app.") or mod == "app":
            del _sys.modules[mod]

    os.environ["DATABASE_URL"] = url

    from app.database import Base
    from app import models as _models  # noqa: F401 — register Base subclasses

    engine = _ce(url, pool_pre_ping=True)
    # Tables must already exist via `alembic upgrade head`.
    # No create_all fallback — surfaces missing migrations loudly per AC6.
    yield engine
    engine.dispose()


@pytest.fixture
def pg_session(pg_smoke_engine):
    """Per-test database session with transactional rollback.

    Each test runs inside a transaction that is rolled back when the test ends.
    This isolates test data without slow table truncation.
    """
    from sqlalchemy.orm import sessionmaker

    connection = pg_smoke_engine.connect()
    transaction = connection.begin()
    Session = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = Session()

    yield session

    session.close()
    transaction.rollback()
    connection.close()


# ── Delegation domain fixtures ────────────────────────────────────────────────


def make_delegation(
    db,
    owner_id: int,
    operator_id: int,
    status: str = "active",
    role_preset: str = "operator_full",
    scope_type: str = "all",
    scope_target_ids=None,
    commission_pct: float | None = 0.05,
    commission_fixed_vnd: float | None = None,
    threshold_monthly_rent_vnd: float = 5_000_000,
    threshold_term_months: int = 12,
    threshold_expense_vnd: float = 2_000_000,
    threshold_rent_change_pct: float = 5.00,
    threshold_refund_vnd: float = 1_000_000,
    poa_format: str = "digital",
    invitation_id: str | None = None,
) -> object:
    """Factory for Delegation test records.

    AC-04: exactly one of commission_pct / commission_fixed_vnd must be non-NULL.
    AC-31b: all 5 threshold values must be explicitly set (no DB defaults).

    Example usage in tests:
        delegation = make_delegation(db, owner_id=owner.id, operator_id=op.id)
        db.flush()
        assert delegation.status == 'active'
    """
    import uuid as _uuid
    from decimal import Decimal
    from datetime import datetime as _dt

    # Validate commission XOR (mirrors DB CHECK constraint in application layer)
    if (commission_pct is None) == (commission_fixed_vnd is None):
        raise ValueError(
            "AC-04: exactly one of commission_pct / commission_fixed_vnd must be non-NULL"
        )

    # Import here to avoid circular imports at module level in conftest
    try:
        from app.domain.delegation import Delegation
    except ImportError:
        pytest.skip("Delegation models not available")

    delegation = Delegation(
        id=str(_uuid.uuid4()),
        owner_id=owner_id,
        operator_id=operator_id,
        status=status,
        role_preset=role_preset,
        scope_type=scope_type,
        scope_target_ids=scope_target_ids,
        commission_pct=Decimal(str(commission_pct)) if commission_pct is not None else None,
        commission_fixed_vnd=(
            Decimal(str(commission_fixed_vnd)) if commission_fixed_vnd is not None else None
        ),
        threshold_monthly_rent_vnd=Decimal(str(threshold_monthly_rent_vnd)),
        threshold_term_months=threshold_term_months,
        threshold_expense_vnd=Decimal(str(threshold_expense_vnd)),
        threshold_rent_change_pct=Decimal(str(threshold_rent_change_pct)),
        threshold_refund_vnd=Decimal(str(threshold_refund_vnd)),
        poa_format=poa_format,
        invitation_id=invitation_id,
        retention_tier="hot",
        created_at=_dt.utcnow(),
        updated_at=_dt.utcnow(),
    )
    db.add(delegation)
    return delegation


def make_delegation_invitation(
    db,
    owner_id: int,
    invited_phone_or_email: str = "operator@example.com",
    status: str = "pending",
    token: str | None = None,
    proposed_role_preset: str = "operator_full",
    proposed_scope_type: str = "all",
) -> object:
    """Factory for DelegationInvitation test records.

    AC-01: token must be unique + single-use.
    AC-10b: only one pending invite per (owner, invitee) — enforced by partial UNIQUE index.
    """
    import uuid as _uuid
    import secrets as _secrets
    from datetime import datetime as _dt, timedelta

    try:
        from app.domain.delegation import DelegationInvitation
    except ImportError:
        pytest.skip("Delegation models not available")

    invitation = DelegationInvitation(
        id=str(_uuid.uuid4()),
        owner_id=owner_id,
        invited_phone_or_email=invited_phone_or_email,
        token=token or _secrets.token_urlsafe(48)[:64],
        proposed_role_preset=proposed_role_preset,
        proposed_scope_type=proposed_scope_type,
        proposed_scope_target_ids=None,
        proposed_poa_format="digital",
        status=status,
        expires_at=_dt.utcnow() + timedelta(days=7),
        created_at=_dt.utcnow(),
    )
    db.add(invitation)
    return invitation
