"""Unit tests for AdminDelegationActions (Phase 10).

Tests:
  - force_revoke_delegation(): terminates any non-archived delegation
  - force_revoke_delegation(): 404 for missing delegation
  - force_revoke_delegation(): 409 for already archived
  - suspend_operator(): pauses all active delegations for operator
  - suspend_operator(): skips non-active delegations
  - reinstate_operator(): resumes only admin_suspend paused delegations
  - reinstate_operator(): does not resume system-pause delegations
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime
from decimal import Decimal

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
import app.models  # noqa: F401
import app.domain  # noqa: F401


@pytest.fixture(scope="module")
def sqlite_engine():
    _engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=_engine)
    yield _engine
    _engine.dispose()


@pytest.fixture
def db(sqlite_engine):
    Session = sessionmaker(bind=sqlite_engine)
    session = Session()
    yield session
    session.rollback()
    session.close()


def _make_user(db):
    from app.models import User
    u = User(
        name="Test User",
        email=f"user_{uuid.uuid4().hex[:6]}@example.com",
        phone=f"09{uuid.uuid4().int % 100000000:08d}",
        password_hash="hashed",
        role="host",
    )
    db.add(u)
    db.flush()
    return u


def _make_delegation(db, owner_id, operator_id, status="active", paused_reason=None):
    from app.domain.delegation import Delegation
    d = Delegation(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        operator_id=operator_id,
        status=status,
        paused_reason=paused_reason,
        role_preset="operator_full",
        scope_type="all",
        commission_pct=Decimal("5.00"),
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


# ---------------------------------------------------------------------------
# Tests: force_revoke_delegation
# ---------------------------------------------------------------------------


class TestForceRevokeDelegation:
    def test_terminates_active_delegation(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db)
        delegation = _make_delegation(db, owner.id, op.id, status="active")

        svc = AdminDelegationActions(db)
        result = svc.force_revoke_delegation(
            delegation_id=str(delegation.id),
            admin_user_id=admin.id,
            reason="Court order #2026/123",
        )

        assert result.status == "terminated"
        assert result.terminate_reason == "admin_force_revoke"
        assert result.terminated_at is not None

    def test_terminates_paused_delegation(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db)
        delegation = _make_delegation(db, owner.id, op.id, status="paused", paused_reason="owner_request")

        svc = AdminDelegationActions(db)
        result = svc.force_revoke_delegation(
            delegation_id=str(delegation.id),
            admin_user_id=admin.id,
            reason="Fraud investigation",
        )

        assert result.status == "terminated"

    def test_raises_for_nonexistent_delegation(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions

        admin = _make_user(db)
        svc = AdminDelegationActions(db)

        with pytest.raises(ValueError, match="not found"):
            svc.force_revoke_delegation(
                delegation_id="00000000-0000-0000-0000-000000000000",
                admin_user_id=admin.id,
                reason="Test",
            )

    def test_raises_for_archived_delegation(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db)
        delegation = _make_delegation(db, owner.id, op.id, status="archived")

        svc = AdminDelegationActions(db)

        with pytest.raises(ValueError, match="archived"):
            svc.force_revoke_delegation(
                delegation_id=str(delegation.id),
                admin_user_id=admin.id,
                reason="Test",
            )

    def test_writes_change_log_entry(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions
        from app import models

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db)
        delegation = _make_delegation(db, owner.id, op.id, status="active")

        svc = AdminDelegationActions(db)
        svc.force_revoke_delegation(
            delegation_id=str(delegation.id),
            admin_user_id=admin.id,
            reason="Security concern",
        )

        log = (
            db.query(models.ChangeLog)
            .filter(
                models.ChangeLog.action == "admin_force_revoke",
                models.ChangeLog.actor_id == admin.id,
            )
            .first()
        )
        assert log is not None
        assert log.on_behalf_of_user_id == owner.id


# ---------------------------------------------------------------------------
# Tests: suspend_operator
# ---------------------------------------------------------------------------


class TestSuspendOperator:
    def test_pauses_all_active_delegations(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions

        owner1 = _make_user(db)
        owner2 = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db)

        del1 = _make_delegation(db, owner1.id, op.id, status="active")
        del2 = _make_delegation(db, owner2.id, op.id, status="active")

        svc = AdminDelegationActions(db)
        count = svc.suspend_operator(
            operator_user_id=op.id,
            admin_user_id=admin.id,
            reason="Fraud investigation",
        )

        assert count >= 2
        db.refresh(del1)
        db.refresh(del2)
        assert del1.status == "paused"
        assert del1.paused_reason == "admin_suspend"
        assert del2.status == "paused"
        assert del2.paused_reason == "admin_suspend"

    def test_skips_non_active_delegations(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db)

        # Already paused — should not be affected
        already_paused = _make_delegation(db, owner.id, op.id, status="paused", paused_reason="owner_request")

        svc = AdminDelegationActions(db)
        count = svc.suspend_operator(
            operator_user_id=op.id,
            admin_user_id=admin.id,
            reason="Test",
        )

        # The already-paused delegation is not counted
        db.refresh(already_paused)
        assert already_paused.paused_reason == "owner_request"  # unchanged

    def test_returns_zero_when_no_active_delegations(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions

        op = _make_user(db)
        admin = _make_user(db)

        svc = AdminDelegationActions(db)
        count = svc.suspend_operator(
            operator_user_id=op.id,
            admin_user_id=admin.id,
            reason="Test",
        )
        assert count == 0


# ---------------------------------------------------------------------------
# Tests: reinstate_operator
# ---------------------------------------------------------------------------


class TestReinstateOperator:
    def test_reinstates_admin_suspended_delegations(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db)

        paused = _make_delegation(db, owner.id, op.id, status="paused", paused_reason="admin_suspend")

        svc = AdminDelegationActions(db)
        count = svc.reinstate_operator(
            operator_user_id=op.id,
            admin_user_id=admin.id,
            reason="Investigation cleared",
        )

        assert count >= 1
        db.refresh(paused)
        assert paused.status == "active"
        assert paused.paused_reason is None

    def test_does_not_reinstate_system_paused_delegations(self, db):
        from app.services.admin.admin_delegation_actions import AdminDelegationActions

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db)

        kyc_paused = _make_delegation(
            db, owner.id, op.id, status="paused", paused_reason="kyc_expired"
        )

        svc = AdminDelegationActions(db)
        count = svc.reinstate_operator(
            operator_user_id=op.id,
            admin_user_id=admin.id,
            reason="Test",
        )

        # kyc_expired is not reinstated by admin reinstate
        db.refresh(kyc_paused)
        assert kyc_paused.status == "paused"
        assert kyc_paused.paused_reason == "kyc_expired"
