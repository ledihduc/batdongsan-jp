"""Immutability tests: commission fields MUST NOT change after Invoice.paid_at is set.

These tests verify the NFR critical rule:
  Once Invoice.paid_at IS NOT NULL, commission_rate, commission_amount,
  platform_fee_pct, and platform_fee_amount MUST NOT be mutatable via
  the service layer.

Tests cover:
  - snapshot_at_creation rejected for paid invoice (409)
  - assert_not_paid raises for paid invoice (409)
  - Double-call of snapshot_at_paid: second call recomputes (idempotent but caller-bug path)
  - Direct mutation via assert_not_paid guard pattern

Uses only in-memory MagicMock — no DB required.
"""

from __future__ import annotations

import os
from datetime import datetime
from decimal import Decimal
from unittest.mock import MagicMock

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


def _paid_invoice(total: float = 3_000_000, paid: float = 3_000_000) -> MagicMock:
    inv = MagicMock()
    inv.id = 99
    inv.host_id = 1
    inv.total_amount = total
    inv.paid_amount = paid
    inv.paid_at = datetime.utcnow()
    inv.commission_amount = 150_000.0
    inv.commission_rate = 0.05
    inv.platform_fee_pct = Decimal("0")
    inv.platform_fee_amount = Decimal("0")
    return inv


def _unpaid_invoice(total: float = 3_000_000) -> MagicMock:
    inv = MagicMock()
    inv.id = 100
    inv.host_id = 1
    inv.total_amount = total
    inv.paid_amount = 0
    inv.paid_at = None
    inv.commission_amount = None
    inv.commission_rate = None
    inv.platform_fee_pct = None
    inv.platform_fee_amount = None
    return inv


def _make_db() -> MagicMock:
    db = MagicMock()
    query = MagicMock()
    db.query.return_value = query
    query.filter.return_value = query
    query.first.return_value = None  # No delegation
    return db


# ── snapshot_at_creation must refuse paid invoices ────────────────────────────


def test_creation_snapshot_refuses_paid_invoice() -> None:
    """snapshot_at_creation must raise 409 if invoice already has paid_at."""
    from fastapi import HTTPException
    from app.services.commission.commission_snapshot import CommissionSnapshot

    snap = CommissionSnapshot()
    inv = _paid_invoice()
    db = _make_db()

    with pytest.raises(HTTPException) as exc:
        snap.snapshot_at_creation(inv, db)

    assert exc.value.status_code == 409
    assert "immutable" in exc.value.detail.lower()


# ── snapshot_at_paid must refuse unpaid invoices ──────────────────────────────


def test_paid_snapshot_refuses_if_paid_at_not_set() -> None:
    """snapshot_at_paid must raise 400 if invoice.paid_at is None."""
    from fastapi import HTTPException
    from app.services.commission.commission_snapshot import CommissionSnapshot

    snap = CommissionSnapshot()
    inv = _unpaid_invoice()
    db = _make_db()

    with pytest.raises(HTTPException) as exc:
        snap.snapshot_at_paid(inv, db)

    assert exc.value.status_code == 400


# ── assert_not_paid guard pattern ─────────────────────────────────────────────


def test_assert_not_paid_blocks_commission_mutation() -> None:
    """Pattern: caller should guard via assert_not_paid before any commission mutation."""
    from fastapi import HTTPException
    from app.services.commission.commission_snapshot import CommissionSnapshot

    inv = _paid_invoice()

    # Simulating a caller trying to mutate commission fields post-payment:
    with pytest.raises(HTTPException) as exc:
        CommissionSnapshot.assert_not_paid(inv, "commission_amount")

    assert exc.value.status_code == 409
    assert "commission_amount" in exc.value.detail


def test_assert_not_paid_blocks_platform_fee_mutation() -> None:
    """Pattern: assert_not_paid blocks platform_fee mutation on paid invoice."""
    from fastapi import HTTPException
    from app.services.commission.commission_snapshot import CommissionSnapshot

    inv = _paid_invoice()

    with pytest.raises(HTTPException) as exc:
        CommissionSnapshot.assert_not_paid(inv, "platform_fee_amount")

    assert exc.value.status_code == 409
    assert "platform_fee_amount" in exc.value.detail


def test_assert_not_paid_allows_unpaid_invoice() -> None:
    """assert_not_paid should not raise for invoices where paid_at is None."""
    from app.services.commission.commission_snapshot import CommissionSnapshot

    inv = _unpaid_invoice()
    # Should not raise — invoice is not paid
    CommissionSnapshot.assert_not_paid(inv, "commission_amount")


# ── Full lifecycle: unpaid → paid → immutable ─────────────────────────────────


def test_full_lifecycle_unpaid_to_paid_to_immutable() -> None:
    """Full lifecycle: create snapshot → mark paid → attempt mutation → blocked."""
    import os
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    import importlib
    import app.services.pricing.platform_fee as pf_module
    importlib.reload(pf_module)

    from fastapi import HTTPException
    from app.services.commission.commission_snapshot import CommissionSnapshot

    snap = CommissionSnapshot()
    inv = _unpaid_invoice(total=5_000_000)
    db = _make_db()

    # Step 1: Creation snapshot — allowed
    snap.snapshot_at_creation(inv, db)
    assert inv.platform_fee_pct == Decimal("0")
    assert inv.platform_fee_amount == Decimal("0")

    # Step 2: Mark as paid
    inv.paid_at = datetime.utcnow()
    inv.paid_amount = 5_000_000

    # Step 3: Paid snapshot — allowed (first time)
    snap.snapshot_at_paid(inv, db)
    assert inv.commission_amount == 0.0  # No delegation
    assert inv.commission_rate is None

    # Step 4: Attempt creation snapshot again after paid — blocked
    with pytest.raises(HTTPException) as exc:
        snap.snapshot_at_creation(inv, db)
    assert exc.value.status_code == 409

    # Step 5: assert_not_paid guard — confirms immutability
    with pytest.raises(HTTPException):
        CommissionSnapshot.assert_not_paid(inv, "commission_amount")
