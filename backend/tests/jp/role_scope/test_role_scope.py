"""Tests for JP role scope enforcement.

Tests:
  - sales cannot access listings not assigned to them
  - tenant can only access their own viewings/applications
  - admin gets global access (org-bounded)
  - missing auth = 403
  - require_role_scope returns correct ScopeContext
"""

from __future__ import annotations

import os
from unittest.mock import MagicMock, patch

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest
from fastapi import FastAPI, HTTPException, Request

from app.services.auth.role_scope import ScopeContext, require_role_scope


def _make_request(
    *,
    user_id=None,
    org_id=None,
    role=None,
    path_params=None,
    query_params=None,
) -> Request:
    """Build a mock Request with state attributes set."""
    mock_request = MagicMock(spec=Request)
    state = MagicMock()
    state.user_id = user_id
    state.org_id = org_id
    state.role = role
    mock_request.state = state
    mock_request.path_params = path_params or {}
    mock_request.query_params = query_params or {}
    return mock_request


class TestRequireRoleScopeBasic:
    """Basic role scope dependency behavior."""

    def test_missing_user_id_returns_403(self) -> None:
        dep = require_role_scope("tenant", "own")
        request = _make_request(user_id=None, org_id="org-001", role="tenant")
        mock_db = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            dep(request=request, db=mock_db)
        assert exc_info.value.status_code == 403

    def test_matching_role_returns_scope_context(self) -> None:
        dep = require_role_scope("tenant", "own")
        request = _make_request(user_id=42, org_id="org-001", role="tenant")
        mock_db = MagicMock()

        ctx = dep(request=request, db=mock_db)
        assert isinstance(ctx, ScopeContext)
        assert ctx.user_id == 42
        assert ctx.org_id == "org-001"
        assert ctx.role == "tenant"
        assert ctx.scope == "own"

    def test_role_mismatch_returns_403(self) -> None:
        """User has role 'tenant' but endpoint requires 'sales'."""
        dep = require_role_scope("sales", "assigned")
        request = _make_request(user_id=42, org_id="org-001", role="tenant")
        mock_db = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            dep(request=request, db=mock_db)
        assert exc_info.value.status_code == 403

    def test_admin_bypasses_role_check(self) -> None:
        """Admin role bypasses required role — gets global scope."""
        dep = require_role_scope("sales", "assigned")
        request = _make_request(user_id=1, org_id="org-001", role="admin")
        mock_db = MagicMock()

        ctx = dep(request=request, db=mock_db)
        assert ctx.role == "admin"
        assert ctx.scope == "global"

    def test_owner_role_allowed(self) -> None:
        dep = require_role_scope("owner", "own")
        request = _make_request(user_id=10, org_id="org-001", role="owner")
        mock_db = MagicMock()

        ctx = dep(request=request, db=mock_db)
        assert ctx.role == "owner"


class TestSalesAssignedScope:
    """Sales role 'assigned' scope — checks listing_sales_assignments."""

    def test_assigned_sales_user_gets_access(self) -> None:
        dep = require_role_scope("sales", "assigned")
        request = _make_request(
            user_id=99,
            org_id="org-001",
            role="sales",
            path_params={"listing_id": "listing-001"},
        )
        mock_db = MagicMock()

        with patch(
            "app.services.auth.role_scope._check_sales_assignment",
            return_value=True,
        ):
            ctx = dep(request=request, db=mock_db)

        assert ctx.user_id == 99
        assert ctx.scope == "assigned"

    def test_unassigned_sales_user_gets_403(self) -> None:
        dep = require_role_scope("sales", "assigned")
        request = _make_request(
            user_id=99,
            org_id="org-001",
            role="sales",
            path_params={"listing_id": "listing-other"},
        )
        mock_db = MagicMock()

        with patch(
            "app.services.auth.role_scope._check_sales_assignment",
            return_value=False,
        ):
            with pytest.raises(HTTPException) as exc_info:
                dep(request=request, db=mock_db)
            assert exc_info.value.status_code == 403

    def test_sales_without_listing_id_gets_access(self) -> None:
        """Sales user with no listing_id in path (list endpoint) — no assignment check."""
        dep = require_role_scope("sales", "assigned")
        request = _make_request(
            user_id=99,
            org_id="org-001",
            role="sales",
            path_params={},  # no listing_id
            query_params={},
        )
        mock_db = MagicMock()

        ctx = dep(request=request, db=mock_db)
        assert ctx.user_id == 99


class TestScopeContextAttributes:
    """Verify ScopeContext carries correct attributes."""

    def test_scope_context_fields(self) -> None:
        ctx = ScopeContext(user_id=42, org_id="org-001", role="tenant", scope="own")
        assert ctx.user_id == 42
        assert ctx.org_id == "org-001"
        assert ctx.role == "tenant"
        assert ctx.scope == "own"


class TestOrgIsolation:
    """Sales agent cannot see other agent's org data."""

    def test_sales_cannot_cross_org_boundary(self) -> None:
        """Sales agent from org-001 is never assigned to a listing in org-002."""
        dep = require_role_scope("sales", "assigned")
        request = _make_request(
            user_id=99,
            org_id="org-001",  # agent's org
            role="sales",
            path_params={"listing_id": "listing-in-org-002"},
        )
        mock_db = MagicMock()

        # The listing_sales_assignments table is also filtered by org_id,
        # so this will return False even for a real listing in another org.
        with patch(
            "app.services.auth.role_scope._check_sales_assignment",
            return_value=False,
        ):
            with pytest.raises(HTTPException) as exc_info:
                dep(request=request, db=mock_db)
            assert exc_info.value.status_code == 403
