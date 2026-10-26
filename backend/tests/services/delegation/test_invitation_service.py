"""Unit tests for DelegationInvitationService (Phase 03).

Tests:
  - Token generation: URL-safe, 64 chars, unique each call
  - Expiry computation: 7 days from now
  - validate_for_accept: expired, used, wrong status
  - validate_for_reject: wrong status
  - mark_consumed: sets token_used_at, accepted_at, status
  - mark_rejected: sets rejected_at, status
  - mark_revoked_by_owner: sets revoked_at, status
  - get_pending_for_owner_invitee: duplicate detection (AC-10b)
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from app.database import Base
import app.models  # noqa: F401 — register users + host_profiles tables
import app.domain  # noqa: F401 — register delegation tables
from app.domain.delegation import DelegationInvitation
from app.services.delegation.invitation_service import (
    DelegationInvitationService,
    InvitationAlreadyUsed,
    InvitationExpired,
    InvitationInvalidStatus,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def engine():
    _e = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=_e)
    yield _e
    _e.dispose()


@pytest.fixture
def db(engine) -> Generator[Session, None, None]:
    connection = engine.connect()
    transaction = connection.begin()
    SessionLocal = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = SessionLocal()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


def _make_invitation(
    db: Session,
    owner_id: int = 1,
    invited: str = "op@test.com",
    status: str = "pending",
    invited_user_id: int | None = 2,
    expires_at: datetime | None = None,
    token_used_at: datetime | None = None,
) -> DelegationInvitation:
    inv = DelegationInvitation(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        invited_phone_or_email=invited,
        invited_user_id=invited_user_id,
        token=f"tok-{uuid.uuid4().hex[:32]}",
        token_used_at=token_used_at,
        proposed_role_preset="operator_full",
        proposed_scope_type="all",
        proposed_scope_target_ids=None,
        proposed_commission_pct=Decimal("5.00"),
        proposed_commission_fixed_vnd=None,
        proposed_thresholds_json={},
        proposed_poa_format="digital",
        status=status,
        expires_at=expires_at or (datetime.utcnow() + timedelta(days=7)),
        created_at=datetime.utcnow(),
    )
    db.add(inv)
    db.flush()
    return inv


# ---------------------------------------------------------------------------
# Token generation
# ---------------------------------------------------------------------------


class TestTokenGeneration:
    def test_token_length(self, db: Session) -> None:
        svc = DelegationInvitationService(db)
        token = svc.generate_token()
        assert len(token) == 64

    def test_token_unique_each_call(self, db: Session) -> None:
        svc = DelegationInvitationService(db)
        tokens = {svc.generate_token() for _ in range(20)}
        assert len(tokens) == 20  # all unique

    def test_token_url_safe(self, db: Session) -> None:
        """Token must be URL-safe (no +, /, =)."""
        svc = DelegationInvitationService(db)
        for _ in range(20):
            token = svc.generate_token()
            assert "+" not in token
            assert "/" not in token
            assert "=" not in token


# ---------------------------------------------------------------------------
# Expiry computation
# ---------------------------------------------------------------------------


class TestExpiryComputation:
    def test_default_7_days(self, db: Session) -> None:
        svc = DelegationInvitationService(db)
        before = datetime.utcnow()
        expiry = svc.compute_expiry()
        after = datetime.utcnow()
        expected_min = before + timedelta(days=7)
        expected_max = after + timedelta(days=7)
        assert expected_min <= expiry <= expected_max

    def test_from_custom_dt(self, db: Session) -> None:
        svc = DelegationInvitationService(db)
        base = datetime(2026, 1, 1, 0, 0, 0)
        expiry = svc.compute_expiry(from_dt=base)
        assert expiry == datetime(2026, 1, 8, 0, 0, 0)


# ---------------------------------------------------------------------------
# validate_for_accept
# ---------------------------------------------------------------------------


class TestValidateForAccept:
    def test_valid_pending_passes(self, db: Session) -> None:
        inv = _make_invitation(db, status="pending")
        svc = DelegationInvitationService(db)
        # Should not raise
        svc.validate_for_accept(inv)

    def test_expired_raises(self, db: Session) -> None:
        inv = _make_invitation(
            db, status="pending", expires_at=datetime.utcnow() - timedelta(seconds=1)
        )
        svc = DelegationInvitationService(db)
        with pytest.raises(InvitationExpired):
            svc.validate_for_accept(inv)

    def test_already_used_raises(self, db: Session) -> None:
        inv = _make_invitation(db, status="pending", token_used_at=datetime.utcnow())
        svc = DelegationInvitationService(db)
        with pytest.raises(InvitationAlreadyUsed):
            svc.validate_for_accept(inv)

    def test_rejected_raises_invalid_status(self, db: Session) -> None:
        inv = _make_invitation(db, status="rejected")
        svc = DelegationInvitationService(db)
        with pytest.raises(InvitationInvalidStatus):
            svc.validate_for_accept(inv)

    def test_accepted_raises_invalid_status(self, db: Session) -> None:
        inv = _make_invitation(db, status="accepted")
        svc = DelegationInvitationService(db)
        with pytest.raises(InvitationInvalidStatus):
            svc.validate_for_accept(inv)


# ---------------------------------------------------------------------------
# validate_for_reject
# ---------------------------------------------------------------------------


class TestValidateForReject:
    def test_pending_ok(self, db: Session) -> None:
        inv = _make_invitation(db, status="pending")
        svc = DelegationInvitationService(db)
        svc.validate_for_reject(inv)  # no raise

    def test_accepted_fails(self, db: Session) -> None:
        inv = _make_invitation(db, status="accepted")
        svc = DelegationInvitationService(db)
        with pytest.raises(InvitationInvalidStatus):
            svc.validate_for_reject(inv)


# ---------------------------------------------------------------------------
# mark_consumed / mark_rejected / mark_revoked
# ---------------------------------------------------------------------------


class TestMarkMethods:
    def test_mark_consumed(self, db: Session) -> None:
        """invited_user_id=None → set to accepting_user_id on consume."""
        inv = _make_invitation(db, status="pending", invited_user_id=None)
        svc = DelegationInvitationService(db)
        svc.mark_consumed(inv, accepting_user_id=999)
        assert inv.status == "accepted"
        assert inv.token_used_at is not None
        assert inv.accepted_at is not None
        assert inv.invited_user_id == 999

    def test_mark_consumed_preserves_existing_user_id(self, db: Session) -> None:
        """invited_user_id already set → should not be overwritten."""
        inv = _make_invitation(db, status="pending", invited_user_id=5)
        svc = DelegationInvitationService(db)
        svc.mark_consumed(inv, accepting_user_id=5)
        assert inv.invited_user_id == 5  # unchanged

    def test_mark_rejected(self, db: Session) -> None:
        inv = _make_invitation(db, status="pending")
        svc = DelegationInvitationService(db)
        svc.mark_rejected(inv)
        assert inv.status == "rejected"
        assert inv.rejected_at is not None

    def test_mark_revoked_by_owner(self, db: Session) -> None:
        inv = _make_invitation(db, status="pending")
        svc = DelegationInvitationService(db)
        svc.mark_revoked_by_owner(inv)
        assert inv.status == "revoked_by_owner"
        assert inv.revoked_at is not None


# ---------------------------------------------------------------------------
# get_pending_for_owner_invitee (AC-10b)
# ---------------------------------------------------------------------------


class TestGetPendingForOwnerInvitee:
    def test_returns_existing_pending(self, db: Session) -> None:
        inv = _make_invitation(db, owner_id=10, invited="dup@test.com", status="pending")
        svc = DelegationInvitationService(db)
        found = svc.get_pending_for_owner_invitee(owner_id=10, invited_phone_or_email="dup@test.com")
        assert found is not None
        assert str(found.id) == str(inv.id)

    def test_returns_none_for_different_invitee(self, db: Session) -> None:
        _make_invitation(db, owner_id=10, invited="a@test.com", status="pending")
        svc = DelegationInvitationService(db)
        found = svc.get_pending_for_owner_invitee(owner_id=10, invited_phone_or_email="b@test.com")
        assert found is None

    def test_returns_none_for_non_pending_status(self, db: Session) -> None:
        _make_invitation(db, owner_id=10, invited="old@test.com", status="accepted")
        svc = DelegationInvitationService(db)
        found = svc.get_pending_for_owner_invitee(owner_id=10, invited_phone_or_email="old@test.com")
        assert found is None

    def test_returns_none_for_different_owner(self, db: Session) -> None:
        _make_invitation(db, owner_id=10, invited="same@test.com", status="pending")
        svc = DelegationInvitationService(db)
        found = svc.get_pending_for_owner_invitee(owner_id=99, invited_phone_or_email="same@test.com")
        assert found is None
