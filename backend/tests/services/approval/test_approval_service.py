"""Unit tests for ApprovalService state machine (Phase 04).

Tests:
  - create(): happy path, KB04 auto-approve, SLA hours
  - decide() approve: happy path, IDOR guard, double-decide, expiry, biometric gate
  - decide() reject: reason required, IDOR guard
  - cancel(): operator cancel, IDOR guard, already decided
  - cancel_in_flight_for_delegation(): bulk cancel on terminate
  - cancel_for_owner_death(): AC-58d bulk auto-reject
  - auto_reject_expired(): cron job method
  - _handle_fraud_termination_approved(): delegation immediate terminate
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
import app.models  # noqa: F401 — register users + host_profiles tables
import app.domain  # noqa: F401 — register delegation tables
from app.domain.delegation import Delegation, DelegationApproval
from app.services.approval.approval_service import (
    ApprovalAlreadyDecided,
    ApprovalExpired,
    ApprovalNotFound,
    ApprovalService,
    BiometricRequired,
)
from app.services.actor_context import ActorContext


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
    """Create and flush a test delegation row."""
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


def _make_owner_ctx(user_id: int = 1) -> ActorContext:
    from app.services.permission_set import owner_self_permissions
    return ActorContext(
        actor_user_id=user_id,
        on_behalf_of_user_id=None,
        delegation_id=None,
        scope_type=None,
        scope_target_building_ids=None,
        permission_set=owner_self_permissions(),
        actor_role="host",
        request_id=str(uuid.uuid4()),
    )


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
# create() tests
# ---------------------------------------------------------------------------


class TestApprovalCreate:
    def test_create_pending_approval(self, db: Session):
        """create() returns pending approval for non-operator_full or non-KB04."""
        delegation = _make_delegation(db)
        svc = ApprovalService(db)

        approval = svc.create(
            delegation=delegation,
            action_type="contract_create",
            action_payload={"monthly_rent_vnd": 8_000_000, "term_months": 12},
            entity_type="contract",
            entity_id=None,
            requested_amount_vnd=Decimal("96000000"),
            sla_class="default_72h",
        )

        assert approval.status == "pending"
        assert approval.action_type == "contract_create"
        assert approval.delegation_id == delegation.id
        assert approval.sla_class == "default_72h"

    def test_kb04_operator_full_auto_approved(self, db: Session):
        """AC-55: KB04 fast-track for operator_full → auto-approved."""
        delegation = _make_delegation(db)
        svc = ApprovalService(db)

        approval = svc.create(
            delegation=delegation,
            action_type="kb04_fast_track",
            action_payload={"khai_bao_id": 42},
            sla_class="kb04_fast_track_6h",
        )

        assert approval.status == "approved"
        assert approval.decision_reason is not None
        assert "auto_approved" in approval.decision_reason

    def test_kb04_non_operator_full_stays_pending(self, db: Session):
        """KB04 for accountant preset → stays pending (needs owner approval)."""
        delegation = _make_delegation(db)
        delegation.role_preset = "accountant"
        svc = ApprovalService(db)

        approval = svc.create(
            delegation=delegation,
            action_type="kb04_fast_track",
            action_payload={"khai_bao_id": 42},
            sla_class="kb04_fast_track_6h",
        )

        assert approval.status == "pending"

    def test_expires_at_computed_correctly_72h(self, db: Session):
        """expires_at = created_at + 72h for default_72h SLA."""
        delegation = _make_delegation(db)
        svc = ApprovalService(db)

        before = datetime.utcnow()
        approval = svc.create(
            delegation=delegation,
            action_type="contract_create",
            action_payload={},
            sla_class="default_72h",
        )
        after = datetime.utcnow()

        expected_min = before + timedelta(hours=72)
        expected_max = after + timedelta(hours=72)
        assert expected_min <= approval.expires_at <= expected_max

    def test_expires_at_computed_6h_for_kb04(self, db: Session):
        """expires_at = created_at + 6h for kb04_fast_track_6h SLA."""
        delegation = _make_delegation(db)
        delegation.role_preset = "accountant"  # non-auto-approve
        svc = ApprovalService(db)

        before = datetime.utcnow()
        approval = svc.create(
            delegation=delegation,
            action_type="kb04_fast_track",
            action_payload={},
            sla_class="kb04_fast_track_6h",
        )
        after = datetime.utcnow()

        expected_min = before + timedelta(hours=6)
        expected_max = after + timedelta(hours=6)
        assert expected_min <= approval.expires_at <= expected_max

    def test_fraud_termination_24h_sla(self, db: Session):
        """AC-43b: fraud_termination approval has 24h SLA."""
        delegation = _make_delegation(db)
        svc = ApprovalService(db)

        before = datetime.utcnow()
        approval = svc.create(
            delegation=delegation,
            action_type="fraud_termination",
            action_payload={},
            sla_class="fraud_termination_24h",
            lockdown_fraud_termination=True,
        )
        after = datetime.utcnow()

        assert approval.lockdown_fraud_termination is True
        expected_min = before + timedelta(hours=24)
        expected_max = after + timedelta(hours=24)
        assert expected_min <= approval.expires_at <= expected_max


# ---------------------------------------------------------------------------
# decide() tests
# ---------------------------------------------------------------------------


class TestApprovalDecide:
    def _create_pending(
        self,
        db: Session,
        owner_id: int = 1,
        operator_id: int = 2,
        action_type: str = "contract_create",
        requires_biometric: bool = False,
        expires_offset_hours: float = 72,
    ) -> DelegationApproval:
        delegation = _make_delegation(db, owner_id=owner_id, operator_id=operator_id)
        now = datetime.utcnow()
        approval = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=operator_id,
            owner_id=owner_id,
            action_type=action_type,
            action_payload_json={},
            requires_biometric=requires_biometric,
            status="pending",
            sla_class="default_72h",
            expires_at=now + timedelta(hours=expires_offset_hours),
            lockdown_fraud_termination=False,
            escalation_state="push_only",
            created_at=now,
        )
        db.add(approval)
        db.flush()
        return approval

    def test_approve_happy_path(self, db: Session):
        """Owner approves → status=approved, decided_by, decided_at set."""
        approval = self._create_pending(db)
        svc = ApprovalService(db)
        owner_ctx = _make_owner_ctx(user_id=1)

        result = svc.decide(
            approval_id=approval.id,
            owner_ctx=owner_ctx,
            decision="approved",
        )

        assert result.status == "approved"
        assert result.decided_by_user_id == 1
        assert result.decided_at is not None

    def test_reject_happy_path(self, db: Session):
        """Owner rejects with reason → status=rejected."""
        approval = self._create_pending(db)
        svc = ApprovalService(db)
        owner_ctx = _make_owner_ctx(user_id=1)

        result = svc.decide(
            approval_id=approval.id,
            owner_ctx=owner_ctx,
            decision="rejected",
            reason="Amount too high",
        )

        assert result.status == "rejected"
        assert result.decision_reason == "Amount too high"

    def test_reject_without_reason_raises(self, db: Session):
        """Rejection without reason → ValueError."""
        approval = self._create_pending(db)
        svc = ApprovalService(db)
        owner_ctx = _make_owner_ctx(user_id=1)

        with pytest.raises(ValueError, match="reason"):
            svc.decide(
                approval_id=approval.id,
                owner_ctx=owner_ctx,
                decision="rejected",
                reason=None,
            )

    def test_idor_guard_wrong_owner_raises(self, db: Session):
        """User that is NOT the owner cannot decide → PermissionError."""
        approval = self._create_pending(db, owner_id=1)
        svc = ApprovalService(db)
        wrong_owner_ctx = _make_owner_ctx(user_id=99)  # wrong user

        with pytest.raises(PermissionError):
            svc.decide(
                approval_id=approval.id,
                owner_ctx=wrong_owner_ctx,
                decision="approved",
            )

    def test_double_decide_raises(self, db: Session):
        """Deciding on already-decided approval → ApprovalAlreadyDecided."""
        approval = self._create_pending(db)
        svc = ApprovalService(db)
        owner_ctx = _make_owner_ctx(user_id=1)

        svc.decide(approval_id=approval.id, owner_ctx=owner_ctx, decision="approved")

        with pytest.raises(ApprovalAlreadyDecided):
            svc.decide(approval_id=approval.id, owner_ctx=owner_ctx, decision="approved")

    def test_expired_approval_raises(self, db: Session):
        """Expired approval → ApprovalExpired."""
        approval = self._create_pending(db, expires_offset_hours=-1)  # 1h in past
        svc = ApprovalService(db)
        owner_ctx = _make_owner_ctx(user_id=1)

        with pytest.raises(ApprovalExpired):
            svc.decide(approval_id=approval.id, owner_ctx=owner_ctx, decision="approved")

    def test_biometric_required_raises_without_token(self, db: Session):
        """AC-29b: requires_biometric=True without token → BiometricRequired."""
        approval = self._create_pending(db, requires_biometric=True)
        svc = ApprovalService(db)
        owner_ctx = _make_owner_ctx(user_id=1)

        with pytest.raises(BiometricRequired):
            svc.decide(
                approval_id=approval.id,
                owner_ctx=owner_ctx,
                decision="approved",
                biometric_token=None,
            )

    def test_not_found_raises(self, db: Session):
        """Non-existent approval → ApprovalNotFound."""
        svc = ApprovalService(db)
        owner_ctx = _make_owner_ctx(user_id=1)

        with pytest.raises(ApprovalNotFound):
            svc.decide(
                approval_id="00000000-0000-0000-0000-000000000000",
                owner_ctx=owner_ctx,
                decision="approved",
            )

    def test_fraud_termination_approved_terminates_delegation(self, db: Session):
        """AC-43b: fraud_termination approved → delegation.status=terminated."""
        delegation = _make_delegation(db, owner_id=1, operator_id=2)
        now = datetime.utcnow()
        approval = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=2,
            owner_id=1,
            action_type="fraud_termination",
            action_payload_json={"fraud_reason": "test"},
            requires_biometric=False,
            status="pending",
            sla_class="fraud_termination_24h",
            expires_at=now + timedelta(hours=24),
            lockdown_fraud_termination=True,
            escalation_state="push_only",
            created_at=now,
        )
        db.add(approval)
        db.flush()

        svc = ApprovalService(db)
        owner_ctx = _make_owner_ctx(user_id=1)

        result = svc.decide(
            approval_id=approval.id,
            owner_ctx=owner_ctx,
            decision="approved",
        )

        assert result.status == "approved"
        # Reload delegation to check it was terminated
        db.expire(delegation)
        updated = db.query(Delegation).filter(Delegation.id == delegation.id).first()
        assert updated.status == "terminated"
        assert updated.terminate_reason == "fraud_suspected"


# ---------------------------------------------------------------------------
# cancel() tests
# ---------------------------------------------------------------------------


class TestApprovalCancel:
    def _create_pending(self, db: Session, operator_id: int = 2) -> DelegationApproval:
        delegation = _make_delegation(db, owner_id=1, operator_id=operator_id)
        now = datetime.utcnow()
        approval = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=operator_id,
            owner_id=1,
            action_type="contract_create",
            action_payload_json={},
            requires_biometric=False,
            status="pending",
            sla_class="default_72h",
            expires_at=now + timedelta(hours=72),
            lockdown_fraud_termination=False,
            escalation_state="push_only",
            created_at=now,
        )
        db.add(approval)
        db.flush()
        return approval

    def test_cancel_happy_path(self, db: Session):
        """Operator cancels own pending approval."""
        approval = self._create_pending(db, operator_id=2)
        svc = ApprovalService(db)
        operator_ctx = _make_operator_ctx(user_id=2)

        result = svc.cancel(approval_id=approval.id, operator_ctx=operator_ctx)

        assert result.status == "cancelled"
        assert result.decision_reason == "operator_cancelled"

    def test_cancel_wrong_operator_raises(self, db: Session):
        """Different operator cannot cancel someone else's approval."""
        approval = self._create_pending(db, operator_id=2)
        svc = ApprovalService(db)
        wrong_ctx = _make_operator_ctx(user_id=99)

        with pytest.raises(PermissionError):
            svc.cancel(approval_id=approval.id, operator_ctx=wrong_ctx)

    def test_cancel_already_decided_raises(self, db: Session):
        """Cannot cancel an already-decided approval."""
        approval = self._create_pending(db, operator_id=2)
        # Manually decide it
        approval.status = "approved"
        db.flush()

        svc = ApprovalService(db)
        operator_ctx = _make_operator_ctx(user_id=2)

        with pytest.raises(ApprovalAlreadyDecided):
            svc.cancel(approval_id=approval.id, operator_ctx=operator_ctx)


# ---------------------------------------------------------------------------
# cancel_in_flight_for_delegation() tests
# ---------------------------------------------------------------------------


class TestBulkCancel:
    def test_cancels_all_pending_for_delegation(self, db: Session):
        """All pending approvals for a delegation are bulk-cancelled."""
        delegation = _make_delegation(db)
        now = datetime.utcnow()

        pending_ids = []
        for _ in range(3):
            a = DelegationApproval(
                id=str(uuid.uuid4()),
                delegation_id=delegation.id,
                requester_user_id=2,
                owner_id=1,
                action_type="contract_create",
                action_payload_json={},
                requires_biometric=False,
                status="pending",
                sla_class="default_72h",
                expires_at=now + timedelta(hours=72),
                lockdown_fraud_termination=False,
                escalation_state="push_only",
                created_at=now,
            )
            db.add(a)
            pending_ids.append(a)

        # Also add an already-decided one (should NOT be cancelled)
        decided = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=2,
            owner_id=1,
            action_type="contract_create",
            action_payload_json={},
            requires_biometric=False,
            status="approved",
            sla_class="default_72h",
            expires_at=now + timedelta(hours=72),
            lockdown_fraud_termination=False,
            escalation_state="push_only",
            created_at=now,
        )
        db.add(decided)
        db.flush()

        svc = ApprovalService(db)
        count = svc.cancel_in_flight_for_delegation(
            delegation_id=delegation.id, reason="delegation_terminated"
        )

        assert count == 3
        for a in pending_ids:
            db.expire(a)
            refreshed = db.query(DelegationApproval).filter(DelegationApproval.id == a.id).first()
            assert refreshed.status == "cancelled"

        # Decided one untouched
        db.expire(decided)
        refreshed_decided = db.query(DelegationApproval).filter(DelegationApproval.id == decided.id).first()
        assert refreshed_decided.status == "approved"


# ---------------------------------------------------------------------------
# cancel_for_owner_death() — AC-58d
# ---------------------------------------------------------------------------


class TestOwnerDeathCancel:
    def test_auto_rejects_pending_for_owner(self, db: Session):
        """AC-58d: all pending approvals for deceased owner → auto_rejected."""
        delegation = _make_delegation(db, owner_id=5, operator_id=6)
        now = datetime.utcnow()
        approval = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=6,
            owner_id=5,
            action_type="contract_create",
            action_payload_json={},
            requires_biometric=False,
            status="pending",
            sla_class="default_72h",
            expires_at=now + timedelta(hours=72),
            lockdown_fraud_termination=False,
            escalation_state="push_only",
            created_at=now,
        )
        db.add(approval)
        db.flush()

        svc = ApprovalService(db)
        count = svc.cancel_for_owner_death(owner_id=5)

        assert count == 1
        db.expire(approval)
        updated = db.query(DelegationApproval).filter(DelegationApproval.id == approval.id).first()
        assert updated.status == "auto_rejected"
        assert updated.decision_reason == "owner_deceased"


# ---------------------------------------------------------------------------
# auto_reject_expired() tests (AC-30)
# ---------------------------------------------------------------------------


class TestAutoRejectExpired:
    def test_auto_rejects_expired_pending_approvals(self, db: Session):
        """AC-30: expired pending approvals → auto_rejected."""
        delegation = _make_delegation(db)
        now = datetime.utcnow()

        # Expired approval (expires_at in the past)
        expired = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=2,
            owner_id=1,
            action_type="contract_create",
            action_payload_json={},
            requires_biometric=False,
            status="pending",
            sla_class="default_72h",
            expires_at=now - timedelta(hours=1),  # 1h in the past
            lockdown_fraud_termination=False,
            escalation_state="push_only",
            created_at=now - timedelta(hours=73),
        )
        db.add(expired)
        # Not expired (still within SLA)
        not_expired = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=delegation.id,
            requester_user_id=2,
            owner_id=1,
            action_type="contract_create",
            action_payload_json={},
            requires_biometric=False,
            status="pending",
            sla_class="default_72h",
            expires_at=now + timedelta(hours=24),
            lockdown_fraud_termination=False,
            escalation_state="push_only",
            created_at=now,
        )
        db.add(not_expired)
        db.flush()

        svc = ApprovalService(db)
        count = svc.auto_reject_expired()

        assert count == 1
        db.expire(expired)
        db.expire(not_expired)
        updated_expired = db.query(DelegationApproval).filter(DelegationApproval.id == expired.id).first()
        updated_not_expired = db.query(DelegationApproval).filter(DelegationApproval.id == not_expired.id).first()

        assert updated_expired.status == "auto_rejected"
        assert updated_expired.decision_reason == "sla_expired"
        assert updated_not_expired.status == "pending"
