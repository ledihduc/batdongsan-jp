"""Unit tests for CommissionSnapshot service.

Tests:
  - snapshot_at_creation: seeds platform_fee = 0 (v1)
  - snapshot_at_paid: locks commission + platform fee
  - commission computation: NULL delegation → 0
  - commission computation: percentage (AC-37 collection ratio)
  - commission computation: fixed amount
  - expected_owner_payout formula (AC-33)
  - freemium: platform_fee_pct always 0 in v1

Uses MagicMock for SQLAlchemy session (pure unit tests — no DB required).
"""

from __future__ import annotations

import os
from datetime import datetime
from decimal import Decimal
from typing import Optional
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


# ── Helper factories ──────────────────────────────────────────────────────────


def _make_invoice(
    *,
    host_id: int = 1,
    total_amount: float = 3_000_000,
    paid_amount: float = 3_000_000,
    paid_at: Optional[datetime] = None,
    commission_amount: Optional[float] = None,
    commission_rate: Optional[float] = None,
    platform_fee_pct: Optional[object] = None,
    platform_fee_amount: Optional[object] = None,
) -> MagicMock:
    """Build a mock Invoice."""
    inv = MagicMock()
    inv.id = 42
    inv.host_id = host_id
    inv.total_amount = total_amount
    inv.paid_amount = paid_amount
    inv.paid_at = paid_at
    inv.commission_amount = commission_amount
    inv.commission_rate = commission_rate
    inv.platform_fee_pct = platform_fee_pct
    inv.platform_fee_amount = platform_fee_amount
    return inv


def _make_delegation(
    *,
    owner_id: int = 1,
    operator_id: int = 2,
    status: str = "active",
    commission_pct: Optional[Decimal] = Decimal("0.05"),  # 5%
    commission_fixed_vnd: Optional[Decimal] = None,
) -> MagicMock:
    """Build a mock Delegation."""
    d = MagicMock()
    d.owner_id = owner_id
    d.operator_id = operator_id
    d.status = status
    d.commission_pct = commission_pct
    d.commission_fixed_vnd = commission_fixed_vnd
    return d


def _make_db(delegation: Optional[object] = None) -> MagicMock:
    """Build a mock SQLAlchemy session that returns a delegation query result."""
    db = MagicMock()
    query = MagicMock()
    db.query.return_value = query
    query.filter.return_value = query
    query.first.return_value = delegation
    return db


# ── snapshot_at_creation ──────────────────────────────────────────────────────


def test_snapshot_at_creation_sets_platform_fee_zero() -> None:
    """Creation snapshot seeds platform_fee_pct=0, platform_fee_amount=0 (v1 NFR-15)."""
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    from app.services.commission.commission_snapshot import CommissionSnapshot
    snap = CommissionSnapshot()
    inv = _make_invoice()
    db = _make_db()

    snap.snapshot_at_creation(inv, db)

    assert inv.platform_fee_pct == Decimal("0")
    assert inv.platform_fee_amount == Decimal("0")
    # commission fields NOT set at creation — only at paid_at
    assert inv.commission_amount is None
    assert inv.commission_rate is None


def test_snapshot_at_creation_rejects_paid_invoice() -> None:
    """Cannot call snapshot_at_creation on an already-paid invoice."""
    from fastapi import HTTPException
    from app.services.commission.commission_snapshot import CommissionSnapshot

    snap = CommissionSnapshot()
    inv = _make_invoice(paid_at=datetime.utcnow())
    db = _make_db()

    with pytest.raises(HTTPException) as exc_info:
        snap.snapshot_at_creation(inv, db)
    assert exc_info.value.status_code == 409


# ── snapshot_at_paid — NULL delegation (self-managed) ────────────────────────


def test_snapshot_at_paid_null_delegation_zero_commission() -> None:
    """No delegation → commission_rate=None, commission_amount=0."""
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    from app.services.commission.commission_snapshot import CommissionSnapshot
    snap = CommissionSnapshot()
    inv = _make_invoice(paid_at=datetime.utcnow())
    db = _make_db(delegation=None)  # self-managed

    snap.snapshot_at_paid(inv, db)

    assert inv.commission_rate is None
    assert inv.commission_amount == 0.0
    assert inv.platform_fee_pct == Decimal("0")
    assert inv.platform_fee_amount == Decimal("0")


def test_snapshot_at_paid_requires_paid_at_set() -> None:
    """Calling snapshot_at_paid without paid_at raises 400."""
    from fastapi import HTTPException
    from app.services.commission.commission_snapshot import CommissionSnapshot

    snap = CommissionSnapshot()
    inv = _make_invoice(paid_at=None)  # not yet paid
    db = _make_db()

    with pytest.raises(HTTPException) as exc_info:
        snap.snapshot_at_paid(inv, db)
    assert exc_info.value.status_code == 400


# ── snapshot_at_paid — percentage commission ──────────────────────────────────


def test_snapshot_at_paid_percentage_full_payment() -> None:
    """100% paid → commission = total × pct (AC-37 collection ratio = 1.0)."""
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    from app.services.commission.commission_snapshot import CommissionSnapshot
    snap = CommissionSnapshot()

    # 3,000,000 VND invoice, 5% commission, fully paid
    inv = _make_invoice(
        total_amount=3_000_000, paid_amount=3_000_000, paid_at=datetime.utcnow()
    )
    delegation = _make_delegation(commission_pct=Decimal("0.05"))
    db = _make_db(delegation=delegation)

    snap.snapshot_at_paid(inv, db)

    # commission_rate stored as float (0.05)
    assert abs(inv.commission_rate - 0.05) < 1e-9
    # commission_amount = 3,000,000 × 0.05 = 150,000
    assert abs(inv.commission_amount - 150_000) < 1e-3


def test_snapshot_at_paid_percentage_partial_payment_ac37() -> None:
    """AC-37: partial payment → commission scales linearly with collection ratio."""
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    from app.services.commission.commission_snapshot import CommissionSnapshot
    snap = CommissionSnapshot()

    # 3,000,000 total, only 2,100,000 paid (70%)
    inv = _make_invoice(
        total_amount=3_000_000, paid_amount=2_100_000, paid_at=datetime.utcnow()
    )
    delegation = _make_delegation(commission_pct=Decimal("0.10"))  # 10%
    db = _make_db(delegation=delegation)

    snap.snapshot_at_paid(inv, db)

    # full_commission = 3,000,000 × 0.10 = 300,000
    # collection_ratio = 2,100,000 / 3,000,000 = 0.70
    # commission_amount = 300,000 × 0.70 = 210,000
    assert abs(inv.commission_amount - 210_000) < 1


def test_snapshot_at_paid_percentage_30_pct_partial() -> None:
    """Verify AC-37 formula: 30% collection → 30% of expected commission."""
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    from app.services.commission.commission_snapshot import CommissionSnapshot
    snap = CommissionSnapshot()

    total = 10_000_000
    paid = 3_000_000  # 30%

    inv = _make_invoice(
        total_amount=total, paid_amount=paid, paid_at=datetime.utcnow()
    )
    delegation = _make_delegation(commission_pct=Decimal("0.08"))  # 8%
    db = _make_db(delegation=delegation)

    snap.snapshot_at_paid(inv, db)

    # full = 10M × 0.08 = 800k; commission = 800k × 0.30 = 240k
    assert abs(inv.commission_amount - 240_000) < 1


# ── snapshot_at_paid — fixed amount commission ────────────────────────────────


def test_snapshot_at_paid_fixed_amount_commission() -> None:
    """Fixed-amount delegation: commission = commission_fixed_vnd (not scaled)."""
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    from app.services.commission.commission_snapshot import CommissionSnapshot
    snap = CommissionSnapshot()

    inv = _make_invoice(
        total_amount=5_000_000, paid_amount=5_000_000, paid_at=datetime.utcnow()
    )
    delegation = _make_delegation(
        commission_pct=None,
        commission_fixed_vnd=Decimal("500000"),  # 500k fixed
    )
    db = _make_db(delegation=delegation)

    snap.snapshot_at_paid(inv, db)

    assert inv.commission_rate is None  # No rate for fixed-amount
    assert abs(inv.commission_amount - 500_000) < 1e-3


# ── expected_owner_payout (AC-33) ─────────────────────────────────────────────


def test_expected_owner_payout_v1_no_platform_fee() -> None:
    """AC-33: In v1, payout = total - commission (platform_fee = 0)."""
    from app.services.commission.commission_snapshot import CommissionSnapshot

    inv = MagicMock()
    inv.total_amount = 3_000_000
    inv.commission_amount = 150_000  # 5%
    inv.platform_fee_amount = Decimal("0")

    payout = CommissionSnapshot.expected_owner_payout(inv)
    assert abs(payout - 2_850_000) < 1


def test_expected_owner_payout_zero_commission() -> None:
    """Self-managed owner: payout = total (commission = 0)."""
    from app.services.commission.commission_snapshot import CommissionSnapshot

    inv = MagicMock()
    inv.total_amount = 3_000_000
    inv.commission_amount = 0
    inv.platform_fee_amount = Decimal("0")

    payout = CommissionSnapshot.expected_owner_payout(inv)
    assert abs(payout - 3_000_000) < 1


def test_expected_owner_payout_never_negative() -> None:
    """Payout floored at 0 — never negative even if commission > total."""
    from app.services.commission.commission_snapshot import CommissionSnapshot

    inv = MagicMock()
    inv.total_amount = 1_000
    inv.commission_amount = 2_000  # More than total (defensive guard)
    inv.platform_fee_amount = 0

    payout = CommissionSnapshot.expected_owner_payout(inv)
    assert payout == 0.0


# ── assert_not_paid guard ─────────────────────────────────────────────────────


def test_assert_not_paid_allows_unpaid() -> None:
    """assert_not_paid should not raise if invoice.paid_at is None."""
    from app.services.commission.commission_snapshot import CommissionSnapshot

    inv = MagicMock()
    inv.id = 1
    inv.paid_at = None

    # Should not raise
    CommissionSnapshot.assert_not_paid(inv)


def test_assert_not_paid_raises_on_paid_invoice() -> None:
    """assert_not_paid raises 409 if paid_at is set."""
    from fastapi import HTTPException
    from app.services.commission.commission_snapshot import CommissionSnapshot

    inv = MagicMock()
    inv.id = 1
    inv.paid_at = datetime.utcnow()

    with pytest.raises(HTTPException) as exc_info:
        CommissionSnapshot.assert_not_paid(inv)
    assert exc_info.value.status_code == 409
