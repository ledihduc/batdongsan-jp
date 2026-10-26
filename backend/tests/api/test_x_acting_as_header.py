"""Tests for app/api/dependencies/actor.py — X-Acting-As-Delegation-Id header (Phase 02).

Tests the resolve_actor_context dependency via a minimal FastAPI test app.
Uses mock DB sessions to avoid real Postgres.

Covers:
  - Missing header → owner self-acting mode (AC-47/48)
  - Valid header + active delegation → operator mode
  - Revoked delegation (terminated/archived) → 401 DELEGATION_REVOKED
  - Paused delegation → 401 DELEGATION_PAUSED
  - Delegation owned by different operator → 403 NOT_YOUR_DELEGATION
  - Invalid UUID header → 400 INVALID_DELEGATION_HEADER
  - require_actor_with_permission: permission denied → 403
  - require_actor_with_permission: lockdown blocked → 403
  - require_actor_with_permission: owner-mutate while delegated → 409
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Generator
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI, Depends
from fastapi.testclient import TestClient

from app.api.dependencies.actor import resolve_actor_context, require_actor_with_permission
from app.database import get_db
from app.services.actor_context import ActorContext
from app.services.permission_set import (
    CONTRACT_CREATE,
    CONTRACT_READ,
    INVOICE_CREATE,
)


# ---------------------------------------------------------------------------
# Fixtures — minimal app + mock DB
# ---------------------------------------------------------------------------


def _make_delegation_mock(
    id: str | None = None,
    owner_id: int = 10,
    operator_id: int = 20,
    status: str = "active",
    role_preset: str = "operator_full",
    scope_type: str = "all",
    scope_target_ids=None,
    out_of_office_start=None,
    out_of_office_end=None,
) -> MagicMock:
    d = MagicMock()
    d.id = id or str(uuid.uuid4())
    d.owner_id = owner_id
    d.operator_id = operator_id
    d.status = status
    d.role_preset = role_preset
    d.scope_type = scope_type
    d.scope_target_ids = scope_target_ids
    d.out_of_office_start = out_of_office_start
    d.out_of_office_end = out_of_office_end
    return d


class _FakeDB:
    """Minimal SQLAlchemy session stub for unit tests."""

    def __init__(self, delegation: MagicMock | None = None) -> None:
        self._delegation = delegation

    def query(self, model: type) -> "_FakeQuery":
        return _FakeQuery(self._delegation, model)


class _FakeQuery:
    def __init__(self, result: MagicMock | None, model: type) -> None:
        self._result = result
        self._model = model

    def filter(self, *args, **kwargs) -> "_FakeQuery":
        return self

    def first(self) -> MagicMock | None:
        return self._result


def _make_test_app(db_override: _FakeDB, actor_user_id: int = 1, role: str = "host") -> FastAPI:
    """Build a minimal FastAPI app with one test endpoint wired to resolve_actor_context."""
    import os
    os.environ.setdefault("JWT_SECRET", "test-secret-xyz")

    from app.auth import sign_token

    app = FastAPI()

    # Minimal endpoint for testing actor context resolution
    @app.get("/test/actor")
    async def _actor_endpoint(
        ctx: ActorContext = Depends(resolve_actor_context),
    ) -> dict:
        return {
            "actor_user_id": ctx.actor_user_id,
            "on_behalf_of_user_id": ctx.on_behalf_of_user_id,
            "delegation_id": ctx.delegation_id,
            "is_delegated": ctx.is_acting_on_behalf,
        }

    @app.post("/test/contract")
    async def _contract_endpoint(
        ctx: ActorContext = Depends(require_actor_with_permission(CONTRACT_CREATE)),
    ) -> dict:
        return {"ok": True}

    app.dependency_overrides[get_db] = lambda: db_override
    return app


def _get_jwt(user_id: int = 1, role: str = "host") -> str:
    import os
    os.environ.setdefault("JWT_SECRET", "test-secret-xyz")
    os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake")
    from app.auth import sign_token
    return sign_token(user_id=user_id, role=role)


# ---------------------------------------------------------------------------
# Test: missing header → owner self-acting
# ---------------------------------------------------------------------------


class TestMissingHeader:
    def test_no_header_returns_owner_self_mode(self) -> None:
        """AC-47/48: missing X-Acting-As-Delegation-Id → self-acting owner context."""
        db = _FakeDB(delegation=None)
        app = _make_test_app(db, actor_user_id=5)
        token = _get_jwt(user_id=5, role="host")

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get(
                "/test/actor",
                headers={"Authorization": f"Bearer {token}"},
            )
        assert resp.status_code == 200
        data = resp.json()
        assert data["actor_user_id"] == 5
        assert data["on_behalf_of_user_id"] is None
        assert data["delegation_id"] is None
        assert data["is_delegated"] is False

    def test_no_auth_header_returns_401(self) -> None:
        db = _FakeDB(delegation=None)
        app = _make_test_app(db)
        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get("/test/actor")
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# Test: valid header + active delegation → operator mode
# ---------------------------------------------------------------------------


class TestValidDelegationHeader:
    def test_active_delegation_returns_operator_context(self) -> None:
        del_id = str(uuid.uuid4())
        delegation = _make_delegation_mock(
            id=del_id, owner_id=10, operator_id=20,
            status="active", role_preset="operator_full", scope_type="all",
        )
        db = _FakeDB(delegation=delegation)
        app = _make_test_app(db, actor_user_id=20)
        token = _get_jwt(user_id=20, role="host")

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get(
                "/test/actor",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Acting-As-Delegation-Id": del_id,
                },
            )
        assert resp.status_code == 200
        data = resp.json()
        assert data["actor_user_id"] == 20
        assert data["on_behalf_of_user_id"] == 10
        assert data["delegation_id"] == del_id
        assert data["is_delegated"] is True


# ---------------------------------------------------------------------------
# Test: revoked delegation → 401 DELEGATION_REVOKED
# ---------------------------------------------------------------------------


class TestRevokedDelegation:
    @pytest.mark.parametrize("status", ["terminated", "archived"])
    def test_revoked_status_returns_401(self, status: str) -> None:
        del_id = str(uuid.uuid4())
        delegation = _make_delegation_mock(
            id=del_id, owner_id=10, operator_id=20, status=status,
        )
        db = _FakeDB(delegation=delegation)
        app = _make_test_app(db, actor_user_id=20)
        token = _get_jwt(user_id=20, role="host")

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get(
                "/test/actor",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Acting-As-Delegation-Id": del_id,
                },
            )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "DELEGATION_REVOKED"


# ---------------------------------------------------------------------------
# Test: paused delegation → 401 DELEGATION_PAUSED
# ---------------------------------------------------------------------------


class TestPausedDelegation:
    def test_paused_delegation_returns_401(self) -> None:
        del_id = str(uuid.uuid4())
        delegation = _make_delegation_mock(
            id=del_id, owner_id=10, operator_id=20, status="paused",
        )
        db = _FakeDB(delegation=delegation)
        app = _make_test_app(db, actor_user_id=20)
        token = _get_jwt(user_id=20, role="host")

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get(
                "/test/actor",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Acting-As-Delegation-Id": del_id,
                },
            )
        assert resp.status_code == 401
        assert resp.json()["detail"]["code"] == "DELEGATION_PAUSED"


# ---------------------------------------------------------------------------
# Test: delegation owned by different operator → 403 NOT_YOUR_DELEGATION
# ---------------------------------------------------------------------------


class TestNotYourDelegation:
    def test_wrong_operator_returns_403(self) -> None:
        del_id = str(uuid.uuid4())
        # Delegation belongs to operator 99, but JWT sub is 20
        delegation = _make_delegation_mock(
            id=del_id, owner_id=10, operator_id=99, status="active",
        )
        db = _FakeDB(delegation=delegation)
        app = _make_test_app(db, actor_user_id=20)
        token = _get_jwt(user_id=20, role="host")

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get(
                "/test/actor",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Acting-As-Delegation-Id": del_id,
                },
            )
        assert resp.status_code == 403
        assert resp.json()["detail"]["code"] == "NOT_YOUR_DELEGATION"


# ---------------------------------------------------------------------------
# Test: delegation not found → 404 DELEGATION_NOT_FOUND
# ---------------------------------------------------------------------------


class TestDelegationNotFound:
    def test_unknown_uuid_returns_404(self) -> None:
        db = _FakeDB(delegation=None)
        app = _make_test_app(db, actor_user_id=20)
        token = _get_jwt(user_id=20, role="host")
        unknown_uuid = str(uuid.uuid4())

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get(
                "/test/actor",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Acting-As-Delegation-Id": unknown_uuid,
                },
            )
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "DELEGATION_NOT_FOUND"


# ---------------------------------------------------------------------------
# Test: invalid UUID header → 400 INVALID_DELEGATION_HEADER
# ---------------------------------------------------------------------------


class TestInvalidHeader:
    @pytest.mark.parametrize("bad_value", [
        "not-a-uuid",
        "12345",
        "00000000-0000-0000-0000-000000000000x",
        "",
    ])
    def test_malformed_header_returns_400(self, bad_value: str) -> None:
        db = _FakeDB(delegation=None)
        app = _make_test_app(db, actor_user_id=20)
        token = _get_jwt(user_id=20, role="host")

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get(
                "/test/actor",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Acting-As-Delegation-Id": bad_value,
                },
            )
        # Empty string header may be treated as absent (depends on FastAPI) — accept 200 or 400
        if bad_value == "":
            assert resp.status_code in (200, 400)
        else:
            assert resp.status_code == 400
            if resp.status_code == 400:
                assert resp.json()["detail"]["code"] == "INVALID_DELEGATION_HEADER"


# ---------------------------------------------------------------------------
# Test: require_actor_with_permission — permission denied
# ---------------------------------------------------------------------------


class TestRequireActorWithPermission:
    def test_permission_denied_for_viewer(self) -> None:
        """viewer preset cannot create contracts → 403 PERMISSION_DENIED."""
        del_id = str(uuid.uuid4())
        delegation = _make_delegation_mock(
            id=del_id, owner_id=10, operator_id=20,
            status="active", role_preset="viewer", scope_type="all",
        )
        db = _FakeDB(delegation=delegation)
        app = _make_test_app(db, actor_user_id=20)
        token = _get_jwt(user_id=20, role="host")

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.post(
                "/test/contract",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Acting-As-Delegation-Id": del_id,
                },
            )
        assert resp.status_code == 403
        assert resp.json()["detail"]["code"] == "PERMISSION_DENIED"

    def test_permission_granted_for_operator_full(self) -> None:
        """operator_full can create contracts → 200."""
        del_id = str(uuid.uuid4())
        delegation = _make_delegation_mock(
            id=del_id, owner_id=10, operator_id=20,
            status="active", role_preset="operator_full", scope_type="all",
        )
        db = _FakeDB(delegation=delegation)
        app = _make_test_app(db, actor_user_id=20)
        token = _get_jwt(user_id=20, role="host")

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.post(
                "/test/contract",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Acting-As-Delegation-Id": del_id,
                },
            )
        assert resp.status_code == 200

    def test_lockdown_blocked_during_terminating(self) -> None:
        """CONTRACT_CREATE blocked during terminating status → 403 LOCKDOWN_BLOCKED."""
        del_id = str(uuid.uuid4())
        delegation = _make_delegation_mock(
            id=del_id, owner_id=10, operator_id=20,
            status="terminating", role_preset="operator_full", scope_type="all",
        )
        db = _FakeDB(delegation=delegation)
        app = _make_test_app(db, actor_user_id=20)
        token = _get_jwt(user_id=20, role="host")

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.post(
                "/test/contract",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Acting-As-Delegation-Id": del_id,
                },
            )
        assert resp.status_code == 403
        assert resp.json()["detail"]["code"] == "LOCKDOWN_BLOCKED"

    def test_owner_mutation_while_delegated_returns_409(self) -> None:
        """Owner self-acting + CONTRACT_CREATE + active delegation exists → 409."""
        # DB returns active delegation for owner_id=5's query
        active_delegation = _make_delegation_mock(
            id=str(uuid.uuid4()), owner_id=5, operator_id=20,
            status="active", role_preset="operator_full", scope_type="all",
        )
        db = _FakeDB(delegation=active_delegation)
        app = _make_test_app(db, actor_user_id=5)
        token = _get_jwt(user_id=5, role="host")

        # No delegation header → owner self-acting path
        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.post(
                "/test/contract",
                headers={"Authorization": f"Bearer {token}"},
            )
        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "OWNER_MUTATION_WHILE_DELEGATED"
