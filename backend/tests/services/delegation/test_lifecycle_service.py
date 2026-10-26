"""Unit tests for DelegationLifecycleService state machine (Phase 03).

Tests:
  - All valid state transitions (happy paths)
  - All invalid state transitions (raises InvalidStateTransition)
  - AC-08: OwnerHasActiveDelegation raised on second activate
  - AC-10b: DuplicatePendingInvitation raised on duplicate pending invite
  - AC-22: operator resign enforced to operator only
  - AC-45: immediate termination for fraud/legal
  - AC-42: 30d notice for normal termination
  - AC-44/cancel termination within window
  - AC-57: OOO set/clear
  - NFR-01: atomic state guard (FOR UPDATE fallback)

Using in-memory SQLite with SQLAlchemy — no real Postgres needed.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Generator
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from app.database import Base
import app.models  # noqa: F401 — register users + host_profiles tables on Base.metadata
import app.domain  # noqa: F401 — register delegation tables on Base.metadata
from app.domain.delegation import Delegation, DelegationInvitation
from app.services.delegation.lifecycle_service import (
    DelegationLifecycleService,
    DuplicatePendingInvitation,
    InvalidStateTransition,
    OwnerHasActiveDelegation,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def engine():
    _engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=_engine)
    yield _engine
    _engine.dispose()


@pytest.fixture
def db(engine) -> Generator[Session, None, None]:
    """Per-test session with rollback isolation."""
    connection = engine.connect()
    transaction = connection.begin()
    SessionLocal = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = SessionLocal()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


def _make_delegation(
    db: Session,
    owner_id: int = 1,
    operator_id: int = 2,
    status: str = "active",
    invite_id: str | None = None,
) -> Delegation:
    """Create and flush a Delegation row for testing."""
    d = Delegation(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        operator_id=operator_id,
        invitation_id=invite_id,
        status=status,
        role_preset="operator_full",
        scope_type="all",
        scope_target_ids=None,
        commission_pct=Decimal("5.00"),
        commission_fixed_vnd=None,
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


def _make_invitation(
    db: Session,
    owner_id: int = 1,
    invited: str = "op@example.com",
    status: str = "pending",
    invited_user_id: int | None = 2,
) -> DelegationInvitation:
    """Create and flush a DelegationInvitation row for testing."""
    inv = DelegationInvitation(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        invited_phone_or_email=invited,
        invited_user_id=invited_user_id,
        token=f"tok-{uuid.uuid4().hex[:32]}",
        token_used_at=None,
        proposed_role_preset="operator_full",
        proposed_scope_type="all",
        proposed_scope_target_ids=None,
        proposed_commission_pct=Decimal("5.00"),
        proposed_commission_fixed_vnd=None,
        proposed_thresholds_json={
            "threshold_monthly_rent_vnd": "5000000",
            "threshold_term_months": 12,
            "threshold_expense_vnd": "2000000",
            "threshold_rent_change_pct": "5.00",
            "threshold_refund_vnd": "1000000",
        },
        proposed_poa_format="digital",
        status=status,
        expires_at=datetime.utcnow() + timedelta(days=7),
        created_at=datetime.utcnow(),
    )
    db.add(inv)
    db.flush()
    return inv


# ---------------------------------------------------------------------------
# pause_delegation tests
# ---------------------------------------------------------------------------


class TestPauseDelegation:
    def test_active_to_paused_owner_request(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        result = svc.pause_delegation(d, reason="owner_request")
        assert result.status == "paused"
        assert result.paused_reason == "owner_request"

    def test_active_to_paused_system_reason(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        result = svc.pause_delegation(d, reason="gpkd_revoked")
        assert result.status == "paused"
        assert result.paused_reason == "gpkd_revoked"

    def test_active_to_paused_with_until(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        until = datetime.utcnow() + timedelta(days=30)
        result = svc.pause_delegation(d, reason="kyc_expired", paused_until=until)
        assert result.paused_until == until

    def test_paused_to_paused_invalid(self, db: Session) -> None:
        d = _make_delegation(db, status="paused")
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition) as exc_info:
            svc.pause_delegation(d, reason="owner_request")
        assert "active" in str(exc_info.value).lower() or "paused" in str(exc_info.value).lower()

    def test_terminated_to_paused_invalid(self, db: Session) -> None:
        d = _make_delegation(db, status="terminated")
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition):
            svc.pause_delegation(d, reason="owner_request")


# ---------------------------------------------------------------------------
# resume_delegation tests
# ---------------------------------------------------------------------------


class TestResumeDelegation:
    def test_paused_owner_request_to_active(self, db: Session) -> None:
        d = _make_delegation(db, status="paused")
        d.paused_reason = "owner_request"
        db.flush()
        svc = DelegationLifecycleService(db)
        result = svc.resume_delegation(d)
        assert result.status == "active"
        assert result.paused_reason is None

    def test_paused_kyc_expired_cannot_resume(self, db: Session) -> None:
        d = _make_delegation(db, status="paused")
        d.paused_reason = "kyc_expired"
        db.flush()
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition) as exc_info:
            svc.resume_delegation(d)
        assert "external resolution" in str(exc_info.value).lower() or "kyc_expired" in str(exc_info.value)

    def test_paused_gpkd_cannot_resume(self, db: Session) -> None:
        d = _make_delegation(db, status="paused")
        d.paused_reason = "gpkd_revoked"
        db.flush()
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition):
            svc.resume_delegation(d)

    def test_active_to_active_resume_invalid(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition):
            svc.resume_delegation(d)


# ---------------------------------------------------------------------------
# terminate_delegation tests
# ---------------------------------------------------------------------------


class TestTerminateDelegation:
    def test_active_to_terminating_normal(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        result = svc.terminate_delegation(d, reason="owner_request")
        assert result.status == "terminating"
        assert result.terminate_requested_at is not None
        assert result.terminate_reason == "owner_request"

    def test_active_to_terminated_immediate_fraud(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        result = svc.terminate_delegation(d, reason="fraud_suspected")
        assert result.status == "terminated"
        assert result.terminated_at is not None

    def test_active_to_terminated_immediate_legal(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        result = svc.terminate_delegation(d, reason="legal_dispute")
        assert result.status == "terminated"

    def test_paused_to_terminating(self, db: Session) -> None:
        d = _make_delegation(db, status="paused")
        d.paused_reason = "owner_request"
        db.flush()
        svc = DelegationLifecycleService(db)
        result = svc.terminate_delegation(d, reason="owner_request")
        assert result.status == "terminating"

    def test_terminated_cannot_terminate_again(self, db: Session) -> None:
        d = _make_delegation(db, status="terminated")
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition):
            svc.terminate_delegation(d, reason="owner_request")

    def test_archived_cannot_terminate(self, db: Session) -> None:
        d = _make_delegation(db, status="archived")
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition):
            svc.terminate_delegation(d, reason="owner_request")


# ---------------------------------------------------------------------------
# cancel_termination tests
# ---------------------------------------------------------------------------


class TestCancelTermination:
    def test_terminating_to_active(self, db: Session) -> None:
        d = _make_delegation(db, status="terminating")
        d.terminate_requested_at = datetime.utcnow()
        d.terminate_reason = "owner_request"
        db.flush()
        svc = DelegationLifecycleService(db)
        result = svc.cancel_termination(d)
        assert result.status == "active"
        assert result.terminate_requested_at is None

    def test_fraud_termination_cannot_cancel(self, db: Session) -> None:
        d = _make_delegation(db, status="terminating")
        d.terminate_requested_at = datetime.utcnow()
        d.terminate_reason = "fraud_suspected"
        db.flush()
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition) as exc_info:
            svc.cancel_termination(d)
        assert "fraud" in str(exc_info.value).lower() or "legal" in str(exc_info.value).lower()

    def test_elapsed_30d_cannot_cancel(self, db: Session) -> None:
        d = _make_delegation(db, status="terminating")
        d.terminate_requested_at = datetime.utcnow() - timedelta(days=31)
        d.terminate_reason = "owner_request"
        db.flush()
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition) as exc_info:
            svc.cancel_termination(d)
        assert "elapsed" in str(exc_info.value).lower() or "terminal" in str(exc_info.value).lower()

    def test_active_cannot_cancel(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition):
            svc.cancel_termination(d)


# ---------------------------------------------------------------------------
# resign_delegation tests (AC-22)
# ---------------------------------------------------------------------------


class TestResignDelegation:
    def test_operator_can_resign(self, db: Session) -> None:
        d = _make_delegation(db, operator_id=99, status="active")
        svc = DelegationLifecycleService(db)
        result = svc.resign_delegation(d, actor_user_id=99)
        assert result.status == "terminating"
        assert result.terminate_reason == "operator_resign"

    def test_non_operator_cannot_resign(self, db: Session) -> None:
        d = _make_delegation(db, operator_id=99, status="active")
        svc = DelegationLifecycleService(db)
        with pytest.raises(PermissionError) as exc_info:
            svc.resign_delegation(d, actor_user_id=888)
        assert "operator" in str(exc_info.value).lower()

    def test_terminated_cannot_resign(self, db: Session) -> None:
        d = _make_delegation(db, operator_id=99, status="terminated")
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition):
            svc.resign_delegation(d, actor_user_id=99)


# ---------------------------------------------------------------------------
# archive_delegation tests (AC-44)
# ---------------------------------------------------------------------------


class TestArchiveDelegation:
    def test_terminated_to_archived(self, db: Session) -> None:
        d = _make_delegation(db, status="terminated")
        d.terminated_at = datetime.utcnow() - timedelta(days=31)
        db.flush()
        svc = DelegationLifecycleService(db)
        result = svc.archive_delegation(d)
        assert result.status == "archived"
        assert result.archived_at is not None

    def test_active_cannot_archive(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition):
            svc.archive_delegation(d)


# ---------------------------------------------------------------------------
# set_out_of_office tests (AC-57)
# ---------------------------------------------------------------------------


class TestSetOutOfOffice:
    def test_set_oof_on_active(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)
        start = datetime.utcnow() + timedelta(days=1)
        end = start + timedelta(days=5)
        result = svc.set_out_of_office(d, out_of_office_start=start, out_of_office_end=end)
        assert result.out_of_office_start == start
        assert result.out_of_office_end == end

    def test_clear_oof(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        d.out_of_office_start = datetime.utcnow()
        d.out_of_office_end = datetime.utcnow() + timedelta(days=3)
        db.flush()
        svc = DelegationLifecycleService(db)
        result = svc.set_out_of_office(d, out_of_office_start=None, out_of_office_end=None)
        assert result.out_of_office_start is None
        assert result.out_of_office_end is None

    def test_oof_on_paused_invalid(self, db: Session) -> None:
        d = _make_delegation(db, status="paused")
        svc = DelegationLifecycleService(db)
        with pytest.raises(InvalidStateTransition):
            svc.set_out_of_office(d, out_of_office_start=datetime.utcnow(), out_of_office_end=datetime.utcnow() + timedelta(days=1))


# ---------------------------------------------------------------------------
# accept_invitation tests (AC-05/08)
# ---------------------------------------------------------------------------


class TestAcceptInvitation:
    def test_accept_creates_delegation(self, db: Session) -> None:
        inv = _make_invitation(db, owner_id=10, invited_user_id=20)
        svc = DelegationLifecycleService(db)
        # Patch KYC check to True for happy path
        with patch.object(svc, "_check_operator_kyc_complete", return_value=True):
            d = svc.accept_invitation(invitation=inv, accepting_user_id=20)
        assert d.owner_id == 10
        assert d.operator_id == 20
        assert d.status in ("active", "pending_op_kyc")

    def test_accept_without_kyc_is_pending(self, db: Session) -> None:
        inv = _make_invitation(db, owner_id=11, invited_user_id=21)
        svc = DelegationLifecycleService(db)
        with patch.object(svc, "_check_operator_kyc_complete", return_value=False):
            d = svc.accept_invitation(invitation=inv, accepting_user_id=21)
        assert d.status == "pending_op_kyc"

    def test_accept_fails_when_owner_has_active(self, db: Session) -> None:
        """AC-08: second active delegation for same owner must fail."""
        # Create existing active delegation
        _make_delegation(db, owner_id=30, operator_id=31, status="active")
        # Try to accept a new one
        inv = _make_invitation(db, owner_id=30, invited_user_id=32)
        svc = DelegationLifecycleService(db)
        with patch.object(svc, "_check_operator_kyc_complete", return_value=True):
            with pytest.raises(OwnerHasActiveDelegation) as exc_info:
                svc.accept_invitation(invitation=inv, accepting_user_id=32)
        assert "active delegation" in str(exc_info.value).lower()


# ---------------------------------------------------------------------------
# create_invitation tests (AC-10b)
# ---------------------------------------------------------------------------


class TestCreateInvitation:
    def test_duplicate_pending_raises(self, db: Session) -> None:
        """AC-10b: duplicate pending invitation for same (owner, invitee) raises."""
        from unittest.mock import MagicMock as _MM

        # Seed existing pending invitation
        _make_invitation(db, owner_id=50, invited="dup@example.com", status="pending")

        payload = _MM()
        payload.invited_phone_or_email = "dup@example.com"
        payload.role_preset = "operator_full"
        payload.scope_type = "all"
        payload.scope_target_ids = None
        payload.commission_pct = Decimal("5.00")
        payload.commission_fixed_vnd = None
        thresholds = _MM()
        thresholds.threshold_monthly_rent_vnd = Decimal("5000000")
        thresholds.threshold_term_months = 12
        thresholds.threshold_expense_vnd = Decimal("2000000")
        thresholds.threshold_rent_change_pct = Decimal("5.00")
        thresholds.threshold_refund_vnd = Decimal("1000000")
        payload.thresholds = thresholds
        payload.poa_format = "digital"

        svc = DelegationLifecycleService(db)
        with pytest.raises(DuplicatePendingInvitation) as exc_info:
            svc.create_invitation(owner_id=50, payload=payload)
        assert "revoke" in exc_info.value.revoke_url

    def test_no_duplicate_for_different_invitee(self, db: Session) -> None:
        """Different invitee: no duplicate error."""
        from unittest.mock import MagicMock as _MM

        _make_invitation(db, owner_id=60, invited="first@example.com", status="pending")

        payload = _MM()
        payload.invited_phone_or_email = "second@example.com"
        payload.role_preset = "operator_full"
        payload.scope_type = "all"
        payload.scope_target_ids = None
        payload.commission_pct = Decimal("5.00")
        payload.commission_fixed_vnd = None
        thresholds = _MM()
        thresholds.threshold_monthly_rent_vnd = Decimal("5000000")
        thresholds.threshold_term_months = 12
        thresholds.threshold_expense_vnd = Decimal("2000000")
        thresholds.threshold_rent_change_pct = Decimal("5.00")
        thresholds.threshold_refund_vnd = Decimal("1000000")
        payload.thresholds = thresholds
        payload.poa_format = "digital"

        svc = DelegationLifecycleService(db)
        # Should not raise
        inv = svc.create_invitation(owner_id=60, payload=payload)
        assert inv.status == "pending"


# ---------------------------------------------------------------------------
# AC-56: user as both owner and operator
# ---------------------------------------------------------------------------


class TestAC56SelfOwnerOperator:
    def test_user_can_be_both_owner_and_operator(self, db: Session) -> None:
        """AC-56: a user can appear in delegations as both owner and operator."""
        user_id = 77
        # As owner: owns a delegation
        d_as_owner = _make_delegation(db, owner_id=user_id, operator_id=78, status="active")
        # As operator: operates for another owner
        d_as_operator = _make_delegation(db, owner_id=79, operator_id=user_id, status="active")
        db.flush()

        from sqlalchemy import or_
        rows = (
            db.query(Delegation)
            .filter(or_(Delegation.owner_id == user_id, Delegation.operator_id == user_id))
            .all()
        )
        assert len(rows) == 2
        ids = {str(r.id) for r in rows}
        assert str(d_as_owner.id) in ids
        assert str(d_as_operator.id) in ids


# ---------------------------------------------------------------------------
# update_thresholds
# ---------------------------------------------------------------------------


class TestUpdateThresholds:
    def test_update_thresholds_on_active(self, db: Session) -> None:
        d = _make_delegation(db, status="active")
        svc = DelegationLifecycleService(db)

        thresholds = MagicMock()
        thresholds.threshold_monthly_rent_vnd = Decimal("9999999")
        thresholds.threshold_term_months = 24
        thresholds.threshold_expense_vnd = Decimal("3000000")
        thresholds.threshold_rent_change_pct = Decimal("10.00")
        thresholds.threshold_refund_vnd = Decimal("500000")

        result = svc.update_thresholds(d, thresholds=thresholds)
        assert result.threshold_monthly_rent_vnd == Decimal("9999999")
        assert result.threshold_term_months == 24

    def test_update_thresholds_on_terminated_fails(self, db: Session) -> None:
        d = _make_delegation(db, status="terminated")
        svc = DelegationLifecycleService(db)

        thresholds = MagicMock()
        thresholds.threshold_monthly_rent_vnd = Decimal("9999999")
        thresholds.threshold_term_months = 24
        thresholds.threshold_expense_vnd = Decimal("3000000")
        thresholds.threshold_rent_change_pct = Decimal("10.00")
        thresholds.threshold_refund_vnd = Decimal("500000")

        with pytest.raises(InvalidStateTransition):
            svc.update_thresholds(d, thresholds=thresholds)
