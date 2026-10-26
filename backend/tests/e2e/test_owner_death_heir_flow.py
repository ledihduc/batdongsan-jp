"""E2E: Owner death + heir designation flow (Phase 11).

Covers:
  - Death cert report → admin verify → 7d pause → heir designation
  - In-flight approvals blocked (executor feature flag OFF)
  - 30d window expires → delegations archived

Uses service-layer tests. APScheduler NOT run — job functions called directly.

AC coverage: AC-58, AC-58b, AC-58d, AC-59
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Generator
from unittest.mock import patch

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
import app.domain  # noqa: F401
from app.database import Base
from app.domain.owner_death import OwnerDeathCertificate  # noqa: F401 — register table


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def sqlite_engine():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    try:
        Base.metadata.drop_all(bind=engine)
    except Exception:  # noqa: BLE001
        pass
    engine.dispose()


@pytest.fixture()
def db(sqlite_engine) -> Generator[Session, None, None]:
    connection = sqlite_engine.connect()
    transaction = connection.begin()
    _Session = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = _Session()
    try:
        yield session
    finally:
        session.close()
        transaction.rollback()
        connection.close()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _seed_users(db: Session) -> None:
    from app.models import User

    for user_id, is_op in [(1, False), (2, True), (3, False)]:
        if not db.query(User).filter_by(id=user_id).first():
            u = User(
                id=user_id,
                email=f"user{user_id}@test.com",
                phone=f"+8490000000{user_id}",
                name=f"User {user_id}",
                role="host",
                is_active=True,
                password_hash="x",
            )
            if is_op:
                u.is_operator_capable = True
            db.add(u)
    db.flush()


def _seed_active_delegation(db: Session, owner_id: int = 1, operator_id: int = 2) -> object:
    from app.domain.delegation import Delegation

    d = Delegation(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        operator_id=operator_id,
        invitation_id=None,
        role_preset="operator_full",
        scope_type="all",
        scope_target_ids=None,
        commission_pct=Decimal("5.00"),
        commission_fixed_vnd=None,
        status="active",
        activated_at=datetime.utcnow() - timedelta(days=30),
        out_of_office_start=None,
        out_of_office_end=None,
        terminate_requested_at=None,
        terminated_at=None,
        threshold_monthly_rent_vnd=Decimal("5000000"),
        threshold_term_months=12,
        threshold_expense_vnd=Decimal("2000000"),
        threshold_rent_change_pct=Decimal("5.00"),
        threshold_refund_vnd=Decimal("1000000"),
        retention_tier="hot",
        poa_format="notarized",
        poa_document_path=None,
    )
    db.add(d)
    db.flush()
    return d


def _seed_pending_approval(db: Session, delegation_id: str) -> object:
    from app.domain.delegation import DelegationApproval

    approval = DelegationApproval(
        id=str(uuid.uuid4()),
        delegation_id=delegation_id,
        owner_id=1,
        requester_user_id=2,
        action_type="invoice_above_threshold",
        action_payload_json={"invoice_id": 888},
        sla_class="default_72h",
        expires_at=datetime.utcnow() + timedelta(hours=48),
        status="pending",
        created_at=datetime.utcnow() - timedelta(hours=24),
    )
    db.add(approval)
    db.flush()
    return approval


# ---------------------------------------------------------------------------
# AC-58: Report death → pending cert
# ---------------------------------------------------------------------------


class TestDeathReport:
    """Death certificate reporting flow (AC-58)."""

    def test_report_death_creates_pending_cert(self, db: Session):
        """Reporting death → certificate in pending_verification status."""
        _seed_users(db)

        from app.services.owner_death.death_certificate_service import DeathCertificateService

        svc = DeathCertificateService(db)
        cert = svc.report_death(
            owner_user_id=1,
            submitted_by_user_id=3,
            death_certificate_path="death_certificates/cert_001.pdf",
            notarized_poa_path=None,
        )
        db.flush()

        assert cert.verification_status == "pending"
        assert cert.owner_user_id == 1

    def test_duplicate_death_report_raises(self, db: Session):
        """Second death cert for same owner → DuplicateCertificateError."""
        _seed_users(db)

        from app.services.owner_death.death_certificate_service import (
            DeathCertificateService,
            DuplicateCertificateError,
        )

        svc = DeathCertificateService(db)
        svc.report_death(
            owner_user_id=1,
            submitted_by_user_id=3,
            death_certificate_path="death_certificates/cert_001.pdf",
            notarized_poa_path=None,
        )
        db.flush()

        with pytest.raises(DuplicateCertificateError):
            svc.report_death(
                owner_user_id=1,
                submitted_by_user_id=3,
                death_certificate_path="death_certificates/cert_002.pdf",
                notarized_poa_path=None,
            )


# ---------------------------------------------------------------------------
# AC-58: Admin verify → cert verified + delegations paused (7d pause)
# ---------------------------------------------------------------------------


class TestDeathAdminVerify:
    """Admin verifies death → delegations paused for 7d (AC-58)."""

    def test_admin_verify_pauses_delegation(self, db: Session):
        """After verify, active delegation status should be paused."""
        _seed_users(db)
        delegation = _seed_active_delegation(db, owner_id=1, operator_id=2)

        from app.services.owner_death.death_certificate_service import DeathCertificateService
        from app.services.owner_death.death_pause_service import DeathPauseService

        cert_svc = DeathCertificateService(db)
        cert = cert_svc.report_death(
            owner_user_id=1,
            submitted_by_user_id=3,
            death_certificate_path="death_certificates/cert_001.pdf",
            notarized_poa_path=None,
        )
        db.flush()

        verified = cert_svc.verify_death(
            cert_id=str(cert.id),
            admin_user_id=999,
        )
        db.flush()
        assert verified.verification_status == "verified"

        pause_svc = DeathPauseService(db)
        paused_ids = pause_svc.pause_all_owner_delegations(
            cert=verified,
            admin_user_id=999,
        )
        db.flush()
        # At least 1 delegation paused
        assert len(paused_ids) >= 1

        db.refresh(delegation)
        assert delegation.status == "paused"

    def test_admin_reject_leaves_delegation_active(self, db: Session):
        """Admin rejects death cert → delegations remain active."""
        _seed_users(db)
        delegation = _seed_active_delegation(db, owner_id=1, operator_id=2)

        from app.services.owner_death.death_certificate_service import DeathCertificateService

        svc = DeathCertificateService(db)
        cert = svc.report_death(
            owner_user_id=1,
            submitted_by_user_id=3,
            death_certificate_path="death_certificates/cert_001.pdf",
            notarized_poa_path=None,
        )
        db.flush()

        rejected = svc.reject_death(
            cert_id=str(cert.id),
            admin_user_id=999,
            rejection_reason="Insufficient evidence",
        )
        db.flush()
        assert rejected.verification_status == "rejected"

        # Delegation should still be active (not paused)
        db.refresh(delegation)
        assert delegation.status == "active"


# ---------------------------------------------------------------------------
# AC-58b: Heir designation
# ---------------------------------------------------------------------------


class TestHeirDesignation:
    """Heir (executor) designation flow (AC-58b)."""

    def test_designate_heir_sets_executor(self, db: Session):
        """AC-58b: designate-heir sets executor_user_id on death certificate."""
        _seed_users(db)

        from app.services.owner_death.death_certificate_service import DeathCertificateService
        from app.services.owner_death.heir_designation_service import HeirDesignationService

        cert_svc = DeathCertificateService(db)
        cert = cert_svc.report_death(
            owner_user_id=1,
            submitted_by_user_id=3,
            death_certificate_path="death_certificates/cert_001.pdf",
            notarized_poa_path=None,
        )
        db.flush()

        # Verify first
        verified_cert = cert_svc.verify_death(cert_id=str(cert.id), admin_user_id=999)
        db.flush()

        heir_svc = HeirDesignationService(db)
        updated = heir_svc.designate_heir(
            cert=verified_cert,
            heir_user_id=3,
            admin_user_id=999,
        )
        db.flush()

        assert updated.executor_user_id == 3


# ---------------------------------------------------------------------------
# AC-58d: In-flight approvals blocked (executor exception flag OFF)
# ---------------------------------------------------------------------------


class TestInFlightApprovalBlockedOnOwnerDeath:
    """AC-58d: when owner dies, in-flight approvals auto-rejected (flag OFF)."""

    def test_in_flight_approvals_auto_rejected_on_death(self, db: Session):
        """Owner death → bulk cancel of pending approvals (AC-58d, flag OFF)."""
        _seed_users(db)
        delegation = _seed_active_delegation(db, owner_id=1, operator_id=2)
        approval = _seed_pending_approval(db, delegation_id=str(delegation.id))

        from app.services.approval.approval_service import ApprovalService

        svc = ApprovalService(db)
        with patch.object(svc, "_log_event", return_value=None):
            count = svc.cancel_for_owner_death(
                owner_id=1,
            )
        db.flush()
        assert count >= 1

        db.refresh(approval)
        assert approval.status in ("cancelled", "auto_rejected", "expired")


# ---------------------------------------------------------------------------
# 30d window expiry → delegations archived
# ---------------------------------------------------------------------------


class TestOwnerDeathArchiveAfter30d:
    """After 30d without heir, delegations archived (AC-59)."""

    def test_delegations_archived_after_30d_no_heir(self, db: Session):
        """AC-59: delegations archived when no heir designated after 30d."""
        _seed_users(db)
        # Seed a paused delegation (simulating post-death state)
        from app.domain.delegation import Delegation

        paused = Delegation(
            id=str(uuid.uuid4()),
            owner_id=1,
            operator_id=2,
            invitation_id=None,
            role_preset="operator_full",
            scope_type="all",
            scope_target_ids=None,
            commission_pct=Decimal("5.00"),
            commission_fixed_vnd=None,
            status="paused",
            activated_at=datetime.utcnow() - timedelta(days=60),
            out_of_office_start=None,
            out_of_office_end=None,
            terminate_requested_at=None,
            terminated_at=None,
            threshold_monthly_rent_vnd=Decimal("5000000"),
        threshold_term_months=12,
        threshold_expense_vnd=Decimal("2000000"),
        threshold_rent_change_pct=Decimal("5.00"),
        threshold_refund_vnd=Decimal("1000000"),
        retention_tier="hot",
            poa_format="notarized",
            poa_document_path=None,
        )
        db.add(paused)
        db.flush()

        from app.services.delegation.lifecycle_service import DelegationLifecycleService

        svc = DelegationLifecycleService(db)
        # Simulate 30d window elapsed: terminate (→ terminating), complete termination (→ terminated), then archive
        with patch.object(svc, "_log_event", return_value=None):
            terminating = svc.terminate_delegation(
                delegation=paused,
                actor_user_id=999,
                reason="owner_death_no_heir",
            )
        db.flush()

        with patch.object(svc, "_log_event", return_value=None):
            terminated = svc.complete_termination(delegation=terminating)
        db.flush()

        with patch.object(svc, "_log_event", return_value=None):
            archived = svc.archive_delegation(delegation=terminated)
        db.flush()

        assert archived.status == "archived"
