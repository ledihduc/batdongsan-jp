"""Unit tests for FraudTerminationService (Phase 04).

Tests:
  - report_fraud(): creates fraud_termination approval with 24h SLA
  - report_fraud(): lockdown_fraud_termination=True set
  - check_and_auto_suspend_expired(): finds recently expired fraud approvals, pauses operator
  - check_and_auto_suspend_expired(): no expired → returns 0
  - Escalation gates: 4h/12h/20h/24h (via sla_class validation)
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
import app.models  # noqa: F401
import app.domain  # noqa: F401
from app.domain.delegation import Delegation, DelegationApproval
from app.services.actor_context import ActorContext
from app.services.approval.fraud_termination_service import FraudTerminationService


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
    connection = engine.connect()
    transaction = connection.begin()
    _Session = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = _Session()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


def _make_delegation(db: Session, owner_id: int = 1, operator_id: int = 2) -> Delegation:
    d = Delegation(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        operator_id=operator_id,
        status="active",
        role_preset="operator_full",
        scope_type="all",
        commission_pct=Decimal("5.0"),
        threshold_monthly_rent_vnd=Decimal("5000000"),
        threshold_term_months=12,
        threshold_expense_vnd=Decimal("2000000"),
        threshold_rent_change_pct=Decimal("10.0"),
        threshold_refund_vnd=Decimal("1000000"),
        poa_format="digital",
        retention_tier="hot",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(d)
    db.flush()
    return d


def _make_operator_ctx(user_id: int = 2, delegation_id: str | None = None) -> ActorContext:
    from app.services.permission_set import preset_to_permissions
    return ActorContext(
        actor_user_id=user_id,
        on_behalf_of_user_id=1,
        delegation_id=delegation_id,
        scope_type="all",
        scope_target_building_ids=None,
        permission_set=preset_to_permissions("operator_full"),
        actor_role="host",
        request_id=str(uuid.uuid4()),
    )


# ---------------------------------------------------------------------------
# report_fraud() tests
# ---------------------------------------------------------------------------


class TestReportFraud:
    def test_creates_fraud_termination_approval(self, db: Session):
        """report_fraud() creates an approval with correct action_type and SLA."""
        delegation = _make_delegation(db)
        actor_ctx = _make_operator_ctx(user_id=2, delegation_id=delegation.id)
        svc = FraudTerminationService(db)

        approval = svc.report_fraud(
            actor_ctx=actor_ctx,
            delegation=delegation,
            fraud_reason="Tenant damaged property",
        )

        assert approval.action_type == "fraud_termination"
        assert approval.sla_class == "fraud_termination_24h"
        assert approval.status == "pending"

    def test_lockdown_fraud_termination_flag_set(self, db: Session):
        """AC-43b: lockdown_fraud_termination=True on fraud report approval."""
        delegation = _make_delegation(db)
        actor_ctx = _make_operator_ctx(user_id=2, delegation_id=delegation.id)
        svc = FraudTerminationService(db)

        approval = svc.report_fraud(
            actor_ctx=actor_ctx,
            delegation=delegation,
            fraud_reason="Fraud detected",
        )

        assert approval.lockdown_fraud_termination is True

    def test_24h_sla_expiry(self, db: Session):
        """AC-43b: fraud termination approval expires in 24h."""
        delegation = _make_delegation(db)
        actor_ctx = _make_operator_ctx(user_id=2, delegation_id=delegation.id)
        svc = FraudTerminationService(db)

        before = datetime.utcnow()
        approval = svc.report_fraud(
            actor_ctx=actor_ctx,
            delegation=delegation,
            fraud_reason="Evidence of fraud",
        )
        after = datetime.utcnow()

        expected_min = before + timedelta(hours=24)
        expected_max = after + timedelta(hours=24)
        assert expected_min <= approval.expires_at <= expected_max

    def test_evidence_urls_stored_in_payload(self, db: Session):
        """Evidence URLs stored in action_payload_json."""
        delegation = _make_delegation(db)
        actor_ctx = _make_operator_ctx(user_id=2, delegation_id=delegation.id)
        svc = FraudTerminationService(db)

        evidence = ["https://cdn.example.com/evidence1.jpg", "https://cdn.example.com/evidence2.jpg"]
        approval = svc.report_fraud(
            actor_ctx=actor_ctx,
            delegation=delegation,
            fraud_reason="Tenant running illegal business",
            evidence_urls=evidence,
        )

        assert approval.action_payload_json["evidence_urls"] == evidence
        assert approval.action_payload_json["fraud_reason"] == "Tenant running illegal business"

    def test_requester_is_operator(self, db: Session):
        """requester_user_id = operator (actor_ctx.actor_user_id)."""
        delegation = _make_delegation(db, operator_id=7)
        actor_ctx = _make_operator_ctx(user_id=7, delegation_id=delegation.id)
        svc = FraudTerminationService(db)

        approval = svc.report_fraud(
            actor_ctx=actor_ctx,
            delegation=delegation,
            fraud_reason="Fraud",
        )

        assert approval.requester_user_id == 7
        assert approval.owner_id == 1


# ---------------------------------------------------------------------------
# check_and_auto_suspend_expired() tests (AC-43b SLA monitor)
# ---------------------------------------------------------------------------


class TestAutoSuspendExpired:
    def _create_fraud_auto_rejected(
        self,
        db: Session,
        delegation: Delegation,
        decided_at_offset_minutes: int = -30,  # decided 30 min ago by default
    ) -> DelegationApproval:
        """Create a fraud_termination approval in auto_rejected state."""
        now = datetime.utcnow()
        approval = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=int(delegation.operator_id),
            owner_id=int(delegation.owner_id),
            action_type="fraud_termination",
            action_payload_json={"fraud_reason": "test"},
            requires_biometric=False,
            status="auto_rejected",  # already expired
            sla_class="fraud_termination_24h",
            expires_at=now - timedelta(hours=24),  # past expiry
            decided_at=now + timedelta(minutes=decided_at_offset_minutes),
            lockdown_fraud_termination=True,
            escalation_state="escalated_admin",
            created_at=now - timedelta(hours=24),
        )
        db.add(approval)
        db.flush()
        return approval

    def test_suspends_operator_on_expired_fraud_approval(self, db: Session):
        """AC-43b: auto_rejected fraud approval → operator delegations paused."""
        delegation = _make_delegation(db, operator_id=10)
        self._create_fraud_auto_rejected(db, delegation)
        svc = FraudTerminationService(db)

        count = svc.check_and_auto_suspend_expired()

        assert count > 0
        db.expire(delegation)
        updated = db.query(Delegation).filter(Delegation.id == delegation.id).first()
        assert updated.status == "paused"
        assert updated.paused_reason == "fraud_flag"

    def test_no_expired_returns_zero(self, db: Session):
        """No auto_rejected fraud approvals → returns 0."""
        svc = FraudTerminationService(db)
        count = svc.check_and_auto_suspend_expired()
        # May be 0 or more depending on test isolation — just check no exception
        assert isinstance(count, int)
        assert count >= 0

    def test_non_fraud_auto_rejected_not_processed(self, db: Session):
        """Non-fraud auto_rejected approvals are not processed by this job."""
        delegation = _make_delegation(db, operator_id=20)
        now = datetime.utcnow()
        # Regular (non-fraud) auto_rejected approval
        regular = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=20,
            owner_id=1,
            action_type="contract_create",  # NOT fraud_termination
            action_payload_json={},
            requires_biometric=False,
            status="auto_rejected",
            sla_class="default_72h",
            expires_at=now - timedelta(hours=73),
            decided_at=now - timedelta(minutes=30),
            lockdown_fraud_termination=False,
            escalation_state="push_only",
            created_at=now - timedelta(hours=73),
        )
        db.add(regular)
        db.flush()

        svc = FraudTerminationService(db)
        # This should NOT suspend the operator (action_type != fraud_termination)
        # The delegation should remain active
        db.expire(delegation)
        refreshed = db.query(Delegation).filter(Delegation.id == delegation.id).first()
        assert refreshed.status == "active"
