"""Unit tests for owner attestation service.

Coverage:
  - attest_sole_ownership: AC-64 idempotency, one-way, user not found
  - get_sole_ownership_status: null / set
  - check_sole_ownership_attested: True/False
  - ack_shared_login_disclosure: AC-66 idempotency, wrong operator, delegation not found
"""

from __future__ import annotations

import os
from datetime import datetime
from unittest.mock import MagicMock

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from app.services.kyc.owner_attestation_service import (
    attest_sole_ownership,
    ack_shared_login_disclosure,
    check_sole_ownership_attested,
    get_sole_ownership_status,
)


def _make_user(user_id: int = 1, attested_at=None):
    u = MagicMock()
    u.id = user_id
    u.sole_ownership_attested_at = attested_at
    return u


def _make_delegation(delegation_id: str = "abc-123", operator_id: int = 1, ack_at=None):
    d = MagicMock()
    d.id = delegation_id
    d.operator_id = operator_id
    d.shared_login_disclosure_ack_at = ack_at
    d.updated_at = datetime(2024, 1, 1)
    return d


def _make_db_for_user(user=None, delegation=None):
    db = MagicMock()
    call_count = [0]

    def side_effect():
        call_count[0] += 1
        if call_count[0] == 1:
            return user
        return delegation

    db.query.return_value.filter.return_value.first.side_effect = side_effect
    return db


def _make_db_for_delegation(delegation=None):
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = delegation
    return db


# ---------------------------------------------------------------------------
# attest_sole_ownership (AC-64)
# ---------------------------------------------------------------------------


class TestAttestSoleOwnership:
    def test_raises_if_user_not_found(self):
        db = _make_db_for_user(user=None)
        with pytest.raises(ValueError, match="not found"):
            attest_sole_ownership(user_id=99, db=db)

    def test_records_attestation_first_time(self):
        user = _make_user(attested_at=None)
        db = _make_db_for_user(user=user)

        result = attest_sole_ownership(user_id=1, db=db)
        assert user.sole_ownership_attested_at is not None

    def test_idempotent_when_already_attested(self):
        existing_at = datetime(2024, 6, 1)
        user = _make_user(attested_at=existing_at)
        db = _make_db_for_user(user=user)

        result = attest_sole_ownership(user_id=1, db=db)
        # Must NOT reset the timestamp
        assert user.sole_ownership_attested_at == existing_at

    def test_records_ip_in_logs(self):
        """Verify attest_sole_ownership passes ip_address to logger (AS-15 evidence trail).

        Uses mock.patch to intercept logger calls directly, avoiding caplog
        cross-test interference when other tests reload modules.
        """
        from unittest.mock import patch, call
        user = _make_user(attested_at=None)
        db = _make_db_for_user(user=user)

        with patch("app.services.kyc.owner_attestation_service.logger") as mock_logger:
            attest_sole_ownership(user_id=1, db=db, ip_address="192.168.1.1")

        # logger.info must have been called with ip_address somewhere in args
        assert mock_logger.info.called
        all_args = str(mock_logger.info.call_args_list)
        assert "192.168.1.1" in all_args


# ---------------------------------------------------------------------------
# get_sole_ownership_status
# ---------------------------------------------------------------------------


class TestGetSoleOwnershipStatus:
    def test_returns_null_when_not_attested(self):
        user = _make_user(attested_at=None)
        db = _make_db_for_user(user=user)
        result = get_sole_ownership_status(user_id=1, db=db)
        assert result["attested_at"] is None

    def test_returns_iso_when_attested(self):
        at = datetime(2025, 3, 15)
        user = _make_user(attested_at=at)
        db = _make_db_for_user(user=user)
        result = get_sole_ownership_status(user_id=1, db=db)
        assert "2025" in result["attested_at"]

    def test_returns_null_when_user_not_found(self):
        db = _make_db_for_user(user=None)
        result = get_sole_ownership_status(user_id=999, db=db)
        assert result["attested_at"] is None


# ---------------------------------------------------------------------------
# check_sole_ownership_attested
# ---------------------------------------------------------------------------


class TestCheckSoleOwnershipAttested:
    def test_returns_true_when_attested(self):
        user = _make_user(attested_at=datetime(2025, 1, 1))
        db = _make_db_for_user(user=user)
        assert check_sole_ownership_attested(user_id=1, db=db) is True

    def test_returns_false_when_not_attested(self):
        user = _make_user(attested_at=None)
        db = _make_db_for_user(user=user)
        assert check_sole_ownership_attested(user_id=1, db=db) is False


# ---------------------------------------------------------------------------
# ack_shared_login_disclosure (AC-66)
# ---------------------------------------------------------------------------


class TestAckSharedLoginDisclosure:
    def test_raises_when_delegation_not_found(self):
        db = _make_db_for_delegation(delegation=None)
        with pytest.raises(ValueError, match="not found"):
            ack_shared_login_disclosure(
                delegation_id="missing", operator_user_id=1, db=db
            )

    def test_raises_when_operator_mismatch(self):
        delegation = _make_delegation(operator_id=99)
        db = _make_db_for_delegation(delegation=delegation)
        with pytest.raises(ValueError, match="not the operator"):
            ack_shared_login_disclosure(
                delegation_id="abc-123", operator_user_id=1, db=db
            )

    def test_records_ack_timestamp(self):
        delegation = _make_delegation(operator_id=1, ack_at=None)
        db = _make_db_for_delegation(delegation=delegation)

        result = ack_shared_login_disclosure(
            delegation_id="abc-123", operator_user_id=1, db=db
        )
        assert delegation.shared_login_disclosure_ack_at is not None

    def test_idempotent_when_already_acked(self):
        existing_ack = datetime(2025, 4, 1)
        delegation = _make_delegation(operator_id=1, ack_at=existing_ack)
        db = _make_db_for_delegation(delegation=delegation)

        result = ack_shared_login_disclosure(
            delegation_id="abc-123", operator_user_id=1, db=db
        )
        # Timestamp must not change on second ack
        assert delegation.shared_login_disclosure_ack_at == existing_ack
