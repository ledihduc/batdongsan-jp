"""Regression: invoice commission computation — v1 freemium (platform_fee_pct=0).

Verifies:
  - CommissionSnapshot with platform_fee_pct=0 produces same commission as before
    phase-09 was added (i.e., no platform fee added)
  - Self-managed owner (no delegation) → commission=0 (AC-37 edge case)
  - commission_snapshot immutability after invoice paid (NFR-critical)

AC coverage: AC-33, AC-37, NFR-15 (regression)
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Generator
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
import app.domain  # noqa: F401
from app.database import Base


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


def _make_mock_delegation_5pct() -> MagicMock:
    """5% commission delegation (typical case)."""
    d = MagicMock()
    d.id = str(uuid.uuid4())
    d.owner_id = 1
    d.operator_id = 2
    d.commission_pct = Decimal("0.05")
    d.commission_fixed_vnd = None
    d.status = "active"
    return d


def _make_mock_delegation_fixed() -> MagicMock:
    """Fixed commission delegation (500k VND/month)."""
    d = MagicMock()
    d.id = str(uuid.uuid4())
    d.owner_id = 1
    d.operator_id = 2
    d.commission_pct = None
    d.commission_fixed_vnd = Decimal("500000")
    d.status = "active"
    return d


# ---------------------------------------------------------------------------
# Core commission computation regression tests
# ---------------------------------------------------------------------------


class TestCommissionV1Freemium:
    """platform_fee_pct=0 in v1 freemium → no platform fee added."""

    def test_percentage_commission_no_platform_fee(self, db: Session):
        """5% commission, 0% platform fee → operator gets 5% of total (AC-33)."""
        from app.services.commission.commission_snapshot import CommissionSnapshot

        delegation = _make_mock_delegation_5pct()
        svc = CommissionSnapshot()

        # 6M VND invoice, fully paid
        result = svc.compute_commission(
            delegation=delegation,
            total_amount=Decimal("6000000"),
            paid_amount=Decimal("6000000"),
        )
        # Expected: 5% of 6000000 = 300000 (no platform fee in v1)
        assert result == Decimal("300000"), f"Expected 300000, got {result}"

    def test_fixed_commission_no_platform_fee(self, db: Session):
        """Fixed 500k commission → exactly 500k returned (no platform fee)."""
        from app.services.commission.commission_snapshot import CommissionSnapshot

        delegation = _make_mock_delegation_fixed()
        svc = CommissionSnapshot()

        result = svc.compute_commission(
            delegation=delegation,
            total_amount=Decimal("6000000"),
            paid_amount=Decimal("6000000"),
        )
        assert result == Decimal("500000"), f"Expected 500000, got {result}"

    def test_no_delegation_zero_commission(self, db: Session):
        """Self-managed owner (no delegation) → 0 commission (AC-37 edge)."""
        from app.services.commission.commission_snapshot import CommissionSnapshot

        svc = CommissionSnapshot()
        result = svc.compute_commission(
            delegation=None,
            total_amount=Decimal("6000000"),
            paid_amount=Decimal("6000000"),
        )
        assert result == Decimal("0"), f"Expected 0 for no delegation, got {result}"

    def test_partial_payment_proportional_commission(self, db: Session):
        """AC-37: 50% payment → 50% of expected commission (commission-loss on shortfall)."""
        from app.services.commission.commission_snapshot import CommissionSnapshot

        delegation = _make_mock_delegation_5pct()
        svc = CommissionSnapshot()

        result = svc.compute_commission(
            delegation=delegation,
            total_amount=Decimal("6000000"),
            paid_amount=Decimal("3000000"),  # 50% paid
        )
        # 5% of 6M = 300k; 50% of 300k = 150k
        assert result == Decimal("150000"), f"Expected 150000 (AC-37 partial), got {result}"

    def test_zero_payment_zero_commission(self, db: Session):
        """Zero payment → zero commission (no commission on unpaid)."""
        from app.services.commission.commission_snapshot import CommissionSnapshot

        delegation = _make_mock_delegation_5pct()
        svc = CommissionSnapshot()

        result = svc.compute_commission(
            delegation=delegation,
            total_amount=Decimal("6000000"),
            paid_amount=Decimal("0"),
        )
        assert result == Decimal("0"), f"Expected 0 for zero payment, got {result}"

    def test_commission_rounds_to_whole_vnd(self, db: Session):
        """Commission rounds to whole VND (no fractional dong)."""
        from app.services.commission.commission_snapshot import CommissionSnapshot

        delegation = _make_mock_delegation_5pct()
        svc = CommissionSnapshot()

        # 7,777,777 VND * 5% = 388,888.85 → should round to 388,889
        result = svc.compute_commission(
            delegation=delegation,
            total_amount=Decimal("7777777"),
            paid_amount=Decimal("7777777"),
        )
        # Should be a whole number (no decimal)
        assert result == result.to_integral_value(), f"Commission should be whole VND, got {result}"


# ---------------------------------------------------------------------------
# NFR-15: platform_fee_pct immutability after paid
# ---------------------------------------------------------------------------


class TestCommissionImmutabilityRegression:
    """NFR-15: commission and platform_fee_pct locked at paid_at — cannot be changed."""

    def test_creation_snapshot_blocked_on_paid_invoice(self, db: Session):
        """snapshot_at_creation on a paid invoice → 409 (NFR-15 immutability guard)."""
        from app.services.commission.commission_snapshot import CommissionSnapshot

        svc = CommissionSnapshot()

        # Invoice that was already paid — calling creation snapshot must fail
        mock_invoice = MagicMock()
        mock_invoice.id = 42
        mock_invoice.paid_at = datetime.utcnow()
        mock_invoice.total_amount = 6_000_000

        with pytest.raises(HTTPException) as exc_info:
            svc.snapshot_at_creation(mock_invoice, db)
        assert exc_info.value.status_code == 409
        assert "immutable" in str(exc_info.value.detail).lower()

    def test_paid_snapshot_requires_paid_at_set(self, db: Session):
        """snapshot_at_paid without paid_at set → 400 (caller-contract guard)."""
        from app.services.commission.commission_snapshot import CommissionSnapshot

        svc = CommissionSnapshot()

        mock_invoice = MagicMock()
        mock_invoice.id = 43
        mock_invoice.paid_at = None  # caller forgot to set
        mock_invoice.total_amount = 6_000_000
        mock_invoice.host_id = 1

        with pytest.raises(HTTPException) as exc_info:
            svc.snapshot_at_paid(mock_invoice, db)
        assert exc_info.value.status_code == 400
        assert "paid_at" in str(exc_info.value.detail)

    def test_compute_commission_does_not_persist_to_db(self, db: Session):
        """compute_commission() is pure — does not write to DB directly."""
        from app.services.commission.commission_snapshot import CommissionSnapshot

        delegation = _make_mock_delegation_5pct()
        svc = CommissionSnapshot()

        # Track DB write operations
        original_add = db.add
        calls = []
        db.add = lambda obj: calls.append(obj)  # type: ignore[method-assign]

        try:
            result = svc.compute_commission(
                delegation=delegation,
                total_amount=Decimal("6000000"),
                paid_amount=Decimal("6000000"),
            )
        finally:
            db.add = original_add  # restore

        # compute_commission should not write to DB
        assert result == Decimal("300000")
        # No invoice rows should have been added during compute
        commission_writes = [c for c in calls if hasattr(c, "commission_amount")]
        assert len(commission_writes) == 0, "compute_commission should not persist to DB"
