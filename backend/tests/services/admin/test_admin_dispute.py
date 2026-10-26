"""Unit tests for AdminDisputeService (Phase 10 / AC-63).

Tests:
  - list_disputes(): returns all flags, filterable by status
  - escalate_dispute(): transitions pending → escalated
  - escalate_dispute(): raises on resolved disputes
  - resolve_dispute(): closes dispute with outcome + optional pause
  - resolve_dispute(): raises on already-resolved dispute
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


def _make_user(db, role="host"):
    from app.models import User
    u = User(
        name="User",
        email=f"u_{uuid.uuid4().hex[:6]}@test.com",
        phone=f"09{uuid.uuid4().int % 100000000:08d}",
        password_hash="hashed",
        role=role,
    )
    db.add(u)
    db.flush()
    return u


def _make_tenant(db, host_id):
    """Create a minimal Tenant record."""
    from app.models import Tenant

    t = Tenant(
        host_id=host_id,
        full_name="Test Tenant",
        phone=f"09{uuid.uuid4().int % 100000000:08d}",
    )
    db.add(t)
    db.flush()
    return t


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


def _make_tenant_flag(db, tenant_id, operator_user_id, delegation_id=None, status="pending"):
    from app.domain.tenant_authority import TenantAuthorityFlag
    flag = TenantAuthorityFlag(
        id=str(uuid.uuid4()),
        tenant_id=tenant_id,
        reported_operator_user_id=operator_user_id,
        delegation_id=delegation_id,
        report_reason="Unauthorized operator collecting rent",
        status=status,
        created_at=datetime.utcnow(),
    )
    db.add(flag)
    db.flush()
    return flag


# ---------------------------------------------------------------------------
# Tests: list_disputes
# ---------------------------------------------------------------------------


class TestListDisputes:
    def test_returns_all_flags_without_filter(self, db):
        from app.services.admin.admin_dispute_service import AdminDisputeService

        owner = _make_user(db)
        op = _make_user(db)
        tenant = _make_tenant(db, host_id=owner.id)

        _make_tenant_flag(db, tenant.id, op.id, status="pending")
        _make_tenant_flag(db, tenant.id, op.id, status="escalated")

        svc = AdminDisputeService(db)
        flags = svc.list_disputes()

        assert len(flags) >= 2

    def test_filters_by_status(self, db):
        from app.services.admin.admin_dispute_service import AdminDisputeService

        owner = _make_user(db)
        op = _make_user(db)
        tenant = _make_tenant(db, host_id=owner.id)

        _make_tenant_flag(db, tenant.id, op.id, status="pending")

        svc = AdminDisputeService(db)
        pending_flags = svc.list_disputes(status="pending")
        valid_flags = svc.list_disputes(status="valid")

        # All returned pending flags should have status='pending'
        assert all(f.status == "pending" for f in pending_flags)


# ---------------------------------------------------------------------------
# Tests: escalate_dispute
# ---------------------------------------------------------------------------


class TestEscalateDispute:
    def test_escalates_pending_flag(self, db):
        from app.services.admin.admin_dispute_service import AdminDisputeService

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db, role="admin")
        tenant = _make_tenant(db, host_id=owner.id)

        flag = _make_tenant_flag(db, tenant.id, op.id, status="pending")

        svc = AdminDisputeService(db)
        result = svc.escalate_dispute(
            dispute_id=str(flag.id),
            admin_user_id=admin.id,
            reason="Tenant reported ongoing unauthorized transactions",
        )

        assert result.status == "escalated"

    def test_raises_when_already_resolved(self, db):
        from app.services.admin.admin_dispute_service import AdminDisputeService

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db, role="admin")
        tenant = _make_tenant(db, host_id=owner.id)

        # Already resolved as 'valid'
        flag = _make_tenant_flag(db, tenant.id, op.id, status="valid")

        svc = AdminDisputeService(db)

        with pytest.raises(ValueError, match="already resolved"):
            svc.escalate_dispute(
                dispute_id=str(flag.id),
                admin_user_id=admin.id,
                reason="Test",
            )

    def test_raises_for_nonexistent_dispute(self, db):
        from app.services.admin.admin_dispute_service import AdminDisputeService

        admin = _make_user(db, role="admin")
        svc = AdminDisputeService(db)

        with pytest.raises(ValueError, match="not found"):
            svc.escalate_dispute(
                dispute_id="00000000-0000-0000-0000-000000000000",
                admin_user_id=admin.id,
                reason="Test",
            )


# ---------------------------------------------------------------------------
# Tests: resolve_dispute
# ---------------------------------------------------------------------------


class TestResolveDispute:
    def test_resolves_with_no_action(self, db):
        from app.services.admin.admin_dispute_service import AdminDisputeService

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db, role="admin")
        tenant = _make_tenant(db, host_id=owner.id)

        flag = _make_tenant_flag(db, tenant.id, op.id, status="pending")

        svc = AdminDisputeService(db)
        result = svc.resolve_dispute(
            dispute_id=str(flag.id),
            admin_user_id=admin.id,
            outcome="invalid",
            action="no_action",
            reason="No evidence found",
        )

        assert result["outcome"] == "invalid"
        assert result["delegation_paused"] is False

    def test_resolves_and_pauses_delegation(self, db):
        from app.services.admin.admin_dispute_service import AdminDisputeService

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db, role="admin")
        tenant = _make_tenant(db, host_id=owner.id)

        delegation = _make_delegation(db, owner.id, op.id, status="active")
        flag = _make_tenant_flag(
            db, tenant.id, op.id, delegation_id=str(delegation.id), status="pending"
        )

        svc = AdminDisputeService(db)
        result = svc.resolve_dispute(
            dispute_id=str(flag.id),
            admin_user_id=admin.id,
            outcome="prima_facie_valid",
            action="pause_delegation",
            reason="Operator activity is suspicious",
        )

        assert result["delegation_paused"] is True

        db.refresh(delegation)
        assert delegation.status == "paused"
        assert delegation.paused_reason == "disputed_authority"

    def test_raises_when_already_resolved(self, db):
        from app.services.admin.admin_dispute_service import AdminDisputeService

        owner = _make_user(db)
        op = _make_user(db)
        admin = _make_user(db, role="admin")
        tenant = _make_tenant(db, host_id=owner.id)

        flag = _make_tenant_flag(db, tenant.id, op.id, status="valid")

        svc = AdminDisputeService(db)

        with pytest.raises(ValueError, match="already resolved"):
            svc.resolve_dispute(
                dispute_id=str(flag.id),
                admin_user_id=admin.id,
                outcome="invalid",
                action="no_action",
                reason="Test",
            )
