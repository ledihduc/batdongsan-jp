"""Unit tests for AdminDashboardService (Phase 10).

Tests:
  - dashboard_summary() returns correct counts
  - audit_trail_for_delegation() queries by delegation_id
  - delegations_for_user() segregates by owner/operator role
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
from unittest.mock import MagicMock, patch

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


def _make_user(db, role="host"):
    from app.models import User
    u = User(
        name="Test User",
        email=f"user_{uuid.uuid4().hex[:6]}@example.com",
        phone=f"09{uuid.uuid4().int % 100000000:08d}",
        password_hash="hashed",
        role=role,
    )
    db.add(u)
    db.flush()
    return u


def _make_delegation(db, owner_id, operator_id, status="active"):
    from app.domain.delegation import Delegation
    d = Delegation(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        operator_id=operator_id,
        status=status,
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
# Tests: dashboard_summary
# ---------------------------------------------------------------------------


class TestDashboardSummary:
    def test_returns_all_expected_keys(self, db):
        from app.services.admin.admin_dashboard_service import AdminDashboardService

        svc = AdminDashboardService(db)
        summary = svc.dashboard_summary()

        assert "pending_kyc_count" in summary
        assert "pending_death_certs_count" in summary
        assert "pending_poa_reviews_count" in summary
        assert "fraud_reports_last_24h_count" in summary
        assert "stuck_approvals_count" in summary
        assert "active_delegations_count" in summary
        assert "paused_delegations_count" in summary
        assert "as_of" in summary

    def test_counts_active_delegations(self, db):
        from app.services.admin.admin_dashboard_service import AdminDashboardService

        owner = _make_user(db)
        op = _make_user(db)
        _make_delegation(db, owner.id, op.id, status="active")
        db.flush()

        svc = AdminDashboardService(db)
        summary = svc.dashboard_summary()

        assert summary["active_delegations_count"] >= 1

    def test_counts_paused_delegations(self, db):
        from app.services.admin.admin_dashboard_service import AdminDashboardService

        owner = _make_user(db)
        op = _make_user(db)
        _make_delegation(db, owner.id, op.id, status="paused")
        db.flush()

        svc = AdminDashboardService(db)
        summary = svc.dashboard_summary()

        assert summary["paused_delegations_count"] >= 1

    def test_counts_stuck_approvals(self, db):
        from app.services.admin.admin_dashboard_service import AdminDashboardService
        from app.domain.delegation import DelegationApproval

        owner = _make_user(db)
        op = _make_user(db)
        delegation = _make_delegation(db, owner.id, op.id)

        # Create an approval that is 70 hours old (> 60h stuck threshold)
        old_created_at = datetime.utcnow() - timedelta(hours=70)
        appr = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=op.id,
            owner_id=owner.id,
            action_type="contract_create",
            status="pending",
            sla_class="default_72h",
            expires_at=datetime.utcnow() + timedelta(hours=2),
            created_at=old_created_at,
        )
        db.add(appr)
        db.flush()

        svc = AdminDashboardService(db)
        summary = svc.dashboard_summary()

        assert summary["stuck_approvals_count"] >= 1

    def test_counts_fraud_reports_24h(self, db):
        from app.services.admin.admin_dashboard_service import AdminDashboardService
        from app.domain.delegation import DelegationApproval

        owner = _make_user(db)
        op = _make_user(db)
        delegation = _make_delegation(db, owner.id, op.id)

        # Create a fraud_termination approval created 2h ago (within 24h window)
        recent = datetime.utcnow() - timedelta(hours=2)
        appr = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=op.id,
            owner_id=owner.id,
            action_type="fraud_termination",
            status="pending",
            sla_class="fraud_termination_24h",
            expires_at=datetime.utcnow() + timedelta(hours=22),
            created_at=recent,
        )
        db.add(appr)
        db.flush()

        svc = AdminDashboardService(db)
        summary = svc.dashboard_summary()

        assert summary["fraud_reports_last_24h_count"] >= 1


# ---------------------------------------------------------------------------
# Tests: audit_trail_for_delegation
# ---------------------------------------------------------------------------


class TestAuditTrailForDelegation:
    def test_returns_empty_list_for_no_entries(self, db):
        from app.services.admin.admin_dashboard_service import AdminDashboardService

        svc = AdminDashboardService(db)
        entries = svc.audit_trail_for_delegation("nonexistent-id")
        assert entries == []

    def test_returns_entries_for_delegation(self, db):
        from app.services.admin.admin_dashboard_service import AdminDashboardService
        from app import models

        delegation_id = str(uuid.uuid4())
        owner = _make_user(db)

        # Insert a ChangeLog row linked to this delegation
        log = models.ChangeLog(
            entity_type="delegation",
            entity_id=owner.id,
            actor_id=owner.id,
            action="delegation_accepted",
            after_json='{"status": "active"}',
            acted_via_delegation_id=delegation_id,
            on_behalf_of_user_id=None,
        )
        db.add(log)
        db.flush()

        svc = AdminDashboardService(db)
        entries = svc.audit_trail_for_delegation(delegation_id)

        assert len(entries) >= 1
        assert entries[0]["acted_via_delegation_id"] == delegation_id
        assert entries[0]["action"] == "delegation_accepted"


# ---------------------------------------------------------------------------
# Tests: delegations_for_user
# ---------------------------------------------------------------------------


class TestDelegationsForUser:
    def test_returns_as_owner_and_operator(self, db):
        from app.services.admin.admin_dashboard_service import AdminDashboardService

        owner = _make_user(db)
        op1 = _make_user(db)
        op2 = _make_user(db)

        # owner delegates to op1; op2 is operator in another delegation
        del1 = _make_delegation(db, owner.id, op1.id)
        del2 = _make_delegation(db, op2.id, op1.id)  # op1 is also operator here
        db.flush()

        svc = AdminDashboardService(db)
        result = svc.delegations_for_user(op1.id)

        assert result["user_id"] == op1.id
        op_ids = [str(d.id) for d in result["as_operator"]]
        assert str(del1.id) in op_ids
        assert str(del2.id) in op_ids
        # op1 is not an owner in any delegation
        assert result["as_owner"] == []

    def test_user_with_no_delegations(self, db):
        from app.services.admin.admin_dashboard_service import AdminDashboardService

        user = _make_user(db)
        svc = AdminDashboardService(db)
        result = svc.delegations_for_user(user.id)

        assert result["as_owner"] == []
        assert result["as_operator"] == []
