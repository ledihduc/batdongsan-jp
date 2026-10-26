"""Unit tests for operator individual KYC service.

Coverage:
  - is_operator_individual_kyc_complete: no profile, verified, unverified, missing fields
  - mark_individual_kyc_complete: happy path, no profile, not verified
  - get_kyc_status_for_user: no profile, complete, partial
"""

from __future__ import annotations

import os
from datetime import datetime
from unittest.mock import MagicMock

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from app.services.kyc.operator_individual_service import (
    is_operator_individual_kyc_complete,
    mark_individual_kyc_complete,
    get_kyc_status_for_user,
)


def _make_db(host_profile=None, user=None):
    """Build a minimal mock SQLAlchemy Session."""
    db = MagicMock()
    query = MagicMock()
    db.query.return_value = query
    filter_mock = MagicMock()
    query.filter.return_value = filter_mock

    # We need to discriminate between queries on HostProfile vs User
    def first_side_effect():
        return host_profile

    filter_mock.first.side_effect = first_side_effect
    return db


def _make_host_profile(verified=True, cccd_hash="hash", bank="12345", expires_at=None, grace=None):
    p = MagicMock()
    p.verified = verified
    p.cccd_number_hash = cccd_hash
    p.bank_account_number = bank
    p.kyc_expires_at = expires_at
    p.kyc_grace_period_until = grace
    p.updated_at = datetime(2024, 1, 1)
    return p


# ---------------------------------------------------------------------------
# is_operator_individual_kyc_complete
# ---------------------------------------------------------------------------


class TestIsOperatorIndividualKycComplete:
    def test_returns_false_when_no_profile(self):
        db = _make_db(host_profile=None)
        assert is_operator_individual_kyc_complete(user_id=1, db=db) is False

    def test_returns_true_when_all_fields_set(self):
        profile = _make_host_profile()
        db = _make_db(host_profile=profile)
        assert is_operator_individual_kyc_complete(user_id=1, db=db) is True

    def test_returns_false_when_not_verified(self):
        profile = _make_host_profile(verified=False)
        db = _make_db(host_profile=profile)
        assert is_operator_individual_kyc_complete(user_id=1, db=db) is False

    def test_returns_false_when_no_cccd_hash(self):
        profile = _make_host_profile(cccd_hash=None)
        db = _make_db(host_profile=profile)
        assert is_operator_individual_kyc_complete(user_id=1, db=db) is False

    def test_returns_false_when_no_bank(self):
        profile = _make_host_profile(bank=None)
        db = _make_db(host_profile=profile)
        assert is_operator_individual_kyc_complete(user_id=1, db=db) is False


# ---------------------------------------------------------------------------
# mark_individual_kyc_complete
# ---------------------------------------------------------------------------


class TestMarkIndividualKycComplete:
    def test_raises_if_no_profile(self):
        db = _make_db(host_profile=None)
        with pytest.raises(ValueError, match="No host_profiles row"):
            mark_individual_kyc_complete(user_id=1, db=db)

    def test_raises_if_not_verified(self):
        profile = _make_host_profile(verified=False)
        db = _make_db(host_profile=profile)
        # Also need User query to return something
        user_mock = MagicMock()
        user_mock.is_operator_capable = False

        # Override: first call to filter().first() returns profile,
        # second call (User query) returns user_mock
        call_count = [0]

        def side_effect():
            call_count[0] += 1
            if call_count[0] == 1:
                return profile
            return user_mock

        db.query.return_value.filter.return_value.first.side_effect = side_effect
        with pytest.raises(ValueError, match="verified is False"):
            mark_individual_kyc_complete(user_id=1, db=db)

    def test_sets_kyc_expires_at_5_years(self):
        profile = _make_host_profile()
        profile.kyc_expires_at = None
        user_mock = MagicMock()
        user_mock.is_operator_capable = False

        call_count = [0]

        def side_effect():
            call_count[0] += 1
            if call_count[0] == 1:
                return profile
            return user_mock

        db = _make_db(host_profile=profile)
        db.query.return_value.filter.return_value.first.side_effect = side_effect

        result = mark_individual_kyc_complete(user_id=1, db=db)

        # kyc_expires_at should be set (5 years = 1825 days)
        assert profile.kyc_expires_at is not None
        delta_days = (profile.kyc_expires_at - datetime(2024, 1, 1)).days
        assert 1824 <= delta_days <= 1826  # tolerant of leap year


# ---------------------------------------------------------------------------
# get_kyc_status_for_user
# ---------------------------------------------------------------------------


class TestGetKycStatusForUser:
    def test_returns_defaults_when_no_profile(self):
        db = _make_db(host_profile=None)
        result = get_kyc_status_for_user(user_id=99, db=db)
        assert result["kyc_complete"] is False
        assert result["verified"] is False
        assert result["kyc_expires_at"] is None

    def test_returns_complete_true_when_kyc_done(self):
        profile = _make_host_profile(expires_at=datetime(2029, 1, 1))
        db = _make_db(host_profile=profile)
        result = get_kyc_status_for_user(user_id=1, db=db)
        assert result["kyc_complete"] is True
        assert result["verified"] is True
        assert result["has_cccd"] is True
        assert result["has_bank"] is True
        assert "2029" in result["kyc_expires_at"]

    def test_returns_partial_when_no_cccd(self):
        profile = _make_host_profile(cccd_hash=None)
        db = _make_db(host_profile=profile)
        result = get_kyc_status_for_user(user_id=1, db=db)
        assert result["kyc_complete"] is False
        assert result["has_cccd"] is False
