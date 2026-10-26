"""Tests for app/services/scope_check.py (Phase 02).

Unit tests using SQLAlchemy mock/in-memory sessions.
These tests avoid real DB by checking the scope resolution logic
with Mock objects.
"""

from __future__ import annotations

import pytest
from unittest.mock import MagicMock, patch


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_request(cache: dict | None = None) -> MagicMock:
    """Make a fake FastAPI Request with optional state cache."""
    req = MagicMock()
    req.state = MagicMock()
    # Configure hasattr(req.state, "scope_cache") behavior
    if cache is not None:
        req.state.scope_cache = cache
        req.state.__dict__["scope_cache"] = cache
    else:
        del req.state.scope_cache  # ensures hasattr returns False
    return req


# ---------------------------------------------------------------------------
# Import-level validation
# ---------------------------------------------------------------------------


class TestScopeCheckImport:
    def test_scope_kind_constants_defined(self) -> None:
        from app.services.scope_check import (
            SCOPE_KIND_BUILDING,
            SCOPE_KIND_ROOM,
            SCOPE_KIND_CONTRACT,
            SCOPE_KIND_INVOICE,
            _VALID_SCOPE_KINDS,
        )
        assert SCOPE_KIND_BUILDING in _VALID_SCOPE_KINDS
        assert SCOPE_KIND_ROOM in _VALID_SCOPE_KINDS
        assert SCOPE_KIND_CONTRACT in _VALID_SCOPE_KINDS
        assert SCOPE_KIND_INVOICE in _VALID_SCOPE_KINDS


# ---------------------------------------------------------------------------
# resolve_to_building_id — value error for invalid scope kind
# ---------------------------------------------------------------------------


class TestResolveValidation:
    def test_unknown_scope_kind_raises(self) -> None:
        from app.services.scope_check import resolve_to_building_id

        db = MagicMock()
        req = MagicMock()
        req.state = MagicMock(spec=[])  # no scope_cache

        with pytest.raises(ValueError, match="Unknown scope_kind"):
            resolve_to_building_id(db, req, "tenant", 1)


# ---------------------------------------------------------------------------
# Cache behavior
# ---------------------------------------------------------------------------


class TestScopeCheckCache:
    def test_cache_hit_avoids_db_call(self) -> None:
        """If cache already has the result, DB is never queried."""
        from app.services.scope_check import resolve_to_building_id

        db = MagicMock()
        cache = {("building", 5): 5}
        req = MagicMock()
        req.state = MagicMock()
        req.state.scope_cache = cache

        result = resolve_to_building_id(db, req, "building", 5)
        assert result == 5
        # DB query should NOT have been called
        db.query.assert_not_called()

    def test_cache_populated_on_miss(self) -> None:
        """After a DB lookup, result is stored in cache."""
        from app.services.scope_check import resolve_to_building_id
        from app import models

        db = MagicMock()
        # Simulate Building exists
        mock_row = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = mock_row

        req = MagicMock()
        req.state = MagicMock(spec=[])  # no scope_cache initially

        result = resolve_to_building_id(db, req, "building", 42)
        # Cache should now have the result
        assert hasattr(req.state, "scope_cache")
        assert ("building", 42) in req.state.scope_cache


# ---------------------------------------------------------------------------
# _do_resolve — building
# ---------------------------------------------------------------------------


class TestDoResolveBuilding:
    def test_existing_building_returns_id(self) -> None:
        from app.services.scope_check import _do_resolve
        from app import models

        db = MagicMock()
        mock_row = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = mock_row

        result = _do_resolve(db, "building", 42)
        assert result == 42

    def test_nonexistent_building_returns_none(self) -> None:
        from app.services.scope_check import _do_resolve

        db = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = None

        result = _do_resolve(db, "building", 999)
        assert result is None


# ---------------------------------------------------------------------------
# _do_resolve — room
# ---------------------------------------------------------------------------


class TestDoResolveRoom:
    def test_room_returns_building_id(self) -> None:
        from app.services.scope_check import _do_resolve

        db = MagicMock()
        mock_row = MagicMock()
        mock_row.building_id = 7
        db.query.return_value.filter.return_value.first.return_value = mock_row

        result = _do_resolve(db, "room", 1)
        assert result == 7

    def test_nonexistent_room_returns_none(self) -> None:
        from app.services.scope_check import _do_resolve

        db = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = None

        result = _do_resolve(db, "room", 999)
        assert result is None


# ---------------------------------------------------------------------------
# _do_resolve — contract
# ---------------------------------------------------------------------------


class TestDoResolveContract:
    def test_contract_resolves_via_room(self) -> None:
        from app.services.scope_check import _do_resolve

        db = MagicMock()
        mock_row = MagicMock()
        mock_row.building_id = 3
        db.query.return_value.join.return_value.filter.return_value.first.return_value = mock_row

        result = _do_resolve(db, "contract", 1)
        assert result == 3

    def test_nonexistent_contract_returns_none(self) -> None:
        from app.services.scope_check import _do_resolve

        db = MagicMock()
        db.query.return_value.join.return_value.filter.return_value.first.return_value = None

        result = _do_resolve(db, "contract", 999)
        assert result is None


# ---------------------------------------------------------------------------
# _do_resolve — invoice
# ---------------------------------------------------------------------------


class TestDoResolveInvoice:
    def test_invoice_resolves_via_contract_and_room(self) -> None:
        from app.services.scope_check import _do_resolve

        db = MagicMock()
        mock_row = MagicMock()
        mock_row.building_id = 9
        # Invoice → Contract → Room chain
        q = db.query.return_value
        q.select_from.return_value = q
        q.join.return_value = q
        q.filter.return_value.first.return_value = mock_row

        result = _do_resolve(db, "invoice", 1)
        assert result == 9

    def test_nonexistent_invoice_returns_none(self) -> None:
        from app.services.scope_check import _do_resolve

        db = MagicMock()
        q = db.query.return_value
        q.select_from.return_value = q
        q.join.return_value = q
        q.filter.return_value.first.return_value = None

        result = _do_resolve(db, "invoice", 999)
        assert result is None
