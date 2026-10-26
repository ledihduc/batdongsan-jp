"""Unit tests for HeirDesignationService — AC-58a/b/c."""

from __future__ import annotations

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

import pytest

import app.models  # noqa: F401 — register User on Base.metadata before domain

from app.services.owner_death.heir_designation_service import (
    HeirDesignationError,
    HeirDesignationService,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_cert(
    cert_id: str = "cert-uuid-123",
    owner_user_id: int = 10,
    verification_status: str = "verified",
    executor_user_id: int | None = None,
) -> MagicMock:
    cert = MagicMock()
    cert.id = cert_id
    cert.owner_user_id = owner_user_id
    cert.verification_status = verification_status
    cert.executor_user_id = executor_user_id
    cert.executor_onboarded_at = None
    return cert


def _make_delegation(
    delegation_id: str = "deleg-uuid-456",
    owner_id: int = 10,
    operator_id: int = 20,
    status: str = "paused",
    paused_reason: str = "heir_review_window",
    paused_until: datetime | None = None,
    role_preset: str = "owner_view",
) -> MagicMock:
    d = MagicMock()
    d.id = delegation_id
    d.owner_id = owner_id
    d.operator_id = operator_id
    d.status = status
    d.paused_reason = paused_reason
    d.paused_until = paused_until or (datetime.utcnow() + timedelta(days=20))
    d.role_preset = role_preset
    return d


# ---------------------------------------------------------------------------
# designate_heir
# ---------------------------------------------------------------------------


class TestDesignateHeir:
    def test_designate_heir_on_verified_cert(self):
        cert = _make_cert(verification_status="verified")
        db = MagicMock()
        svc = HeirDesignationService(db)

        result = svc.designate_heir(cert=cert, heir_user_id=20, admin_user_id=99)

        assert result.executor_user_id == 20
        assert result.executor_onboarded_at is not None
        db.flush.assert_called_once()

    def test_designate_heir_on_pending_cert_raises(self):
        cert = _make_cert(verification_status="pending")
        db = MagicMock()
        svc = HeirDesignationService(db)

        with pytest.raises(HeirDesignationError, match="not verified"):
            svc.designate_heir(cert=cert, heir_user_id=20, admin_user_id=99)

    def test_designate_heir_on_rejected_cert_raises(self):
        cert = _make_cert(verification_status="rejected")
        db = MagicMock()
        svc = HeirDesignationService(db)

        with pytest.raises(HeirDesignationError):
            svc.designate_heir(cert=cert, heir_user_id=20, admin_user_id=99)


# ---------------------------------------------------------------------------
# create_inherit_view_delegation
# ---------------------------------------------------------------------------


class TestCreateInheritViewDelegation:
    def test_creates_delegation_when_heir_designated(self):
        cert = _make_cert(executor_user_id=20)
        db = MagicMock()

        # No existing inherit_view delegation
        q = db.query.return_value
        q.filter.return_value.first.return_value = None

        svc = HeirDesignationService(db)
        delegation = svc.create_inherit_view_delegation(
            cert=cert, heir_user_id=20, admin_user_id=99
        )

        db.add.assert_called_once()
        db.flush.assert_called_once()
        added = db.add.call_args[0][0]
        assert added.owner_id == cert.owner_user_id
        assert added.operator_id == 20
        assert added.role_preset == "owner_view"
        assert added.paused_reason == "heir_review_window"
        assert added.status == "paused"

    def test_returns_existing_inherit_view_if_present(self):
        cert = _make_cert(executor_user_id=20)
        existing_delegation = _make_delegation()
        db = MagicMock()

        q = db.query.return_value
        q.filter.return_value.first.return_value = existing_delegation

        svc = HeirDesignationService(db)
        result = svc.create_inherit_view_delegation(
            cert=cert, heir_user_id=20, admin_user_id=99
        )

        assert result is existing_delegation
        db.add.assert_not_called()

    def test_raises_when_no_heir_designated(self):
        cert = _make_cert(executor_user_id=None)
        db = MagicMock()
        svc = HeirDesignationService(db)

        with pytest.raises(HeirDesignationError, match="must be designated"):
            svc.create_inherit_view_delegation(cert=cert, heir_user_id=20, admin_user_id=99)


# ---------------------------------------------------------------------------
# record_heir_claim
# ---------------------------------------------------------------------------


class TestHeirClaim:
    def test_heir_claims_ownership(self):
        delegation = _make_delegation(operator_id=20, paused_reason="heir_review_window")
        db = MagicMock()
        svc = HeirDesignationService(db)

        result = svc.record_heir_claim(delegation=delegation, heir_user_id=20)

        assert result.status == "terminated"
        assert result.terminate_reason == "heir_claimed_ownership"
        db.flush.assert_called_once()

    def test_non_heir_cannot_claim(self):
        delegation = _make_delegation(operator_id=20, paused_reason="heir_review_window")
        db = MagicMock()
        svc = HeirDesignationService(db)

        with pytest.raises(PermissionError):
            svc.record_heir_claim(delegation=delegation, heir_user_id=999)

    def test_wrong_paused_reason_raises(self):
        delegation = _make_delegation(operator_id=20, paused_reason="owner_death")
        db = MagicMock()
        svc = HeirDesignationService(db)

        with pytest.raises(HeirDesignationError, match="inherit_view"):
            svc.record_heir_claim(delegation=delegation, heir_user_id=20)


# ---------------------------------------------------------------------------
# extend_heir_window
# ---------------------------------------------------------------------------


class TestExtendHeirWindow:
    def test_extends_from_current_paused_until(self):
        future_date = datetime.utcnow() + timedelta(days=5)
        delegation = _make_delegation(operator_id=20, paused_until=future_date)
        db = MagicMock()
        svc = HeirDesignationService(db)

        result = svc.extend_heir_window(delegation=delegation, heir_user_id=20, extension_days=30)

        expected_min = future_date + timedelta(days=30)
        # paused_until should be >= expected_min
        assert result.paused_until >= expected_min - timedelta(seconds=1)
        db.flush.assert_called_once()

    def test_non_heir_cannot_extend(self):
        delegation = _make_delegation(operator_id=20)
        db = MagicMock()
        svc = HeirDesignationService(db)

        with pytest.raises(PermissionError):
            svc.extend_heir_window(delegation=delegation, heir_user_id=999)
