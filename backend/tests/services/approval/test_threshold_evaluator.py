"""Unit tests for ThresholdEvaluator — AC-31b five-threshold check logic (Phase 04).

Tests:
  - All 5 threshold check paths for contract_create
  - invoice_high_amount above/below threshold
  - expense_high_amount above/below threshold
  - rent_change above/below pct threshold
  - refund_high_amount above/below threshold
  - cash_payment with/without evidence
  - kb04_fast_track always requires approval
  - kb04_pre_file always requires approval
  - fraud_termination always requires approval (24h SLA)
  - contract_terminate always requires approval (AC-27)
  - threshold_change always requires approval
  - AC-29b: biometric required for amount >= 50M VND
  - unknown action_type defaults to approval required
"""

from __future__ import annotations

import os
from decimal import Decimal
from unittest.mock import MagicMock

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from app.services.approval.threshold_evaluator import ThresholdEvaluator, BIOMETRIC_THRESHOLD_VND


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_delegation(
    threshold_monthly_rent_vnd: float = 5_000_000,
    threshold_term_months: int = 12,
    threshold_expense_vnd: float = 2_000_000,
    threshold_rent_change_pct: float = 10.0,
    threshold_refund_vnd: float = 1_000_000,
    role_preset: str = "operator_full",
) -> MagicMock:
    """Create a mock delegation with threshold columns."""
    d = MagicMock()
    d.threshold_monthly_rent_vnd = Decimal(str(threshold_monthly_rent_vnd))
    d.threshold_term_months = threshold_term_months
    d.threshold_expense_vnd = Decimal(str(threshold_expense_vnd))
    d.threshold_rent_change_pct = Decimal(str(threshold_rent_change_pct))
    d.threshold_refund_vnd = Decimal(str(threshold_refund_vnd))
    d.role_preset = role_preset
    return d


@pytest.fixture
def evaluator() -> ThresholdEvaluator:
    return ThresholdEvaluator()


@pytest.fixture
def delegation() -> MagicMock:
    return _make_delegation()


# ---------------------------------------------------------------------------
# contract_create tests
# ---------------------------------------------------------------------------


class TestContractCreate:
    def test_within_both_thresholds_no_approval(self, evaluator, delegation):
        """Monthly rent within threshold AND term within threshold → no approval."""
        result = evaluator.evaluate(
            "contract_create",
            delegation,
            {"monthly_rent_vnd": 4_000_000, "term_months": 10},
        )
        assert result.requires_approval is False
        assert result.sla_class == "default_72h"

    def test_monthly_rent_exceeds_threshold_requires_approval(self, evaluator, delegation):
        """monthly_rent > threshold → requires approval (AC-24)."""
        result = evaluator.evaluate(
            "contract_create",
            delegation,
            {"monthly_rent_vnd": 6_000_000, "term_months": 6},
        )
        assert result.requires_approval is True
        assert "monthly_rent" in result.reason.lower() or "threshold" in result.reason.lower()

    def test_term_months_exceeds_threshold_requires_approval(self, evaluator, delegation):
        """term_months > threshold → requires approval (AC-24)."""
        result = evaluator.evaluate(
            "contract_create",
            delegation,
            {"monthly_rent_vnd": 3_000_000, "term_months": 24},
        )
        assert result.requires_approval is True
        assert "term_months" in result.reason.lower()

    def test_both_thresholds_exceeded(self, evaluator, delegation):
        """Both monthly_rent and term_months exceed threshold → approval with both reasons."""
        result = evaluator.evaluate(
            "contract_create",
            delegation,
            {"monthly_rent_vnd": 10_000_000, "term_months": 24},
        )
        assert result.requires_approval is True

    def test_exactly_at_threshold_no_approval(self, evaluator, delegation):
        """Exactly at threshold (==) → no approval required (threshold is exclusive)."""
        result = evaluator.evaluate(
            "contract_create",
            delegation,
            {"monthly_rent_vnd": 5_000_000, "term_months": 12},
        )
        assert result.requires_approval is False

    def test_lease_value_computed(self, evaluator, delegation):
        """requested_amount_vnd = monthly_rent × term_months."""
        result = evaluator.evaluate(
            "contract_create",
            delegation,
            {"monthly_rent_vnd": 3_000_000, "term_months": 6},
        )
        assert result.requested_amount_vnd == Decimal("18000000")


# ---------------------------------------------------------------------------
# AC-27: contract_terminate always requires approval
# ---------------------------------------------------------------------------


class TestContractTerminate:
    def test_always_requires_approval(self, evaluator, delegation):
        """AC-27: contract termination always requires approval."""
        result = evaluator.evaluate(
            "contract_terminate",
            delegation,
            {},
        )
        assert result.requires_approval is True
        assert "AC-27" in result.reason or "always" in result.reason.lower()


# ---------------------------------------------------------------------------
# invoice/expense threshold tests (AC-25)
# ---------------------------------------------------------------------------


class TestInvoiceExpense:
    @pytest.mark.parametrize("action_type", ["invoice_high_amount", "expense_high_amount"])
    def test_above_threshold_requires_approval(self, evaluator, delegation, action_type):
        result = evaluator.evaluate(
            action_type,
            delegation,
            {"amount_vnd": 3_000_000},
        )
        assert result.requires_approval is True
        assert result.requested_amount_vnd == Decimal("3000000")

    @pytest.mark.parametrize("action_type", ["invoice_high_amount", "expense_high_amount"])
    def test_below_threshold_no_approval(self, evaluator, delegation, action_type):
        result = evaluator.evaluate(
            action_type,
            delegation,
            {"amount_vnd": 1_000_000},
        )
        assert result.requires_approval is False


# ---------------------------------------------------------------------------
# rent_change threshold tests (AC-26)
# ---------------------------------------------------------------------------


class TestRentChange:
    def test_pct_above_threshold_requires_approval(self, evaluator, delegation):
        """delta_pct > threshold_rent_change_pct → requires approval."""
        # Old: 5M, New: 6M → 20% increase, threshold=10%
        result = evaluator.evaluate(
            "rent_change",
            delegation,
            {"old_monthly_rent_vnd": 5_000_000, "new_monthly_rent_vnd": 6_000_000},
        )
        assert result.requires_approval is True
        assert "20.0%" in result.reason or "20" in result.reason

    def test_pct_within_threshold_no_approval(self, evaluator, delegation):
        """delta_pct <= threshold → no approval."""
        # Old: 5M, New: 5.4M → 8% increase, threshold=10%
        result = evaluator.evaluate(
            "rent_change",
            delegation,
            {"old_monthly_rent_vnd": 5_000_000, "new_monthly_rent_vnd": 5_400_000},
        )
        assert result.requires_approval is False

    def test_zero_old_rent_defaults_to_approval(self, evaluator, delegation):
        """If old_rent is 0 → cannot compute delta, require approval for safety."""
        result = evaluator.evaluate(
            "rent_change",
            delegation,
            {"old_monthly_rent_vnd": 0, "new_monthly_rent_vnd": 3_000_000},
        )
        assert result.requires_approval is True


# ---------------------------------------------------------------------------
# refund threshold tests (AC-28)
# ---------------------------------------------------------------------------


class TestRefund:
    def test_above_threshold_requires_approval(self, evaluator, delegation):
        result = evaluator.evaluate(
            "refund_high_amount",
            delegation,
            {"amount_vnd": 2_000_000},
        )
        assert result.requires_approval is True

    def test_below_threshold_no_approval(self, evaluator, delegation):
        result = evaluator.evaluate(
            "refund_high_amount",
            delegation,
            {"amount_vnd": 500_000},
        )
        assert result.requires_approval is False


# ---------------------------------------------------------------------------
# cash_payment (AC-32b)
# ---------------------------------------------------------------------------


class TestCashPayment:
    def test_within_threshold_with_evidence_no_approval(self, evaluator, delegation):
        """Amount < threshold + evidence → auto-approve (AC-32b)."""
        result = evaluator.evaluate(
            "cash_payment",
            delegation,
            {
                "amount_vnd": 1_000_000,
                "location_lat": 10.77,
                "location_lng": 106.69,
                "photo_url": "https://cdn.example.com/photo.jpg",
            },
        )
        assert result.requires_approval is False

    def test_above_threshold_requires_approval(self, evaluator, delegation):
        """Amount >= threshold → requires approval regardless of evidence."""
        result = evaluator.evaluate(
            "cash_payment",
            delegation,
            {
                "amount_vnd": 3_000_000,
                "location_lat": 10.77,
                "location_lng": 106.69,
                "photo_url": "https://cdn.example.com/photo.jpg",
            },
        )
        assert result.requires_approval is True

    def test_within_threshold_missing_evidence_requires_approval(self, evaluator, delegation):
        """Within threshold but no evidence → requires approval."""
        result = evaluator.evaluate(
            "cash_payment",
            delegation,
            {"amount_vnd": 1_000_000},  # no location, no photo
        )
        assert result.requires_approval is True
        assert "evidence" in result.reason.lower() or "photo" in result.reason.lower() or "location" in result.reason.lower()


# ---------------------------------------------------------------------------
# KB04 tests (AC-55, AC-55b)
# ---------------------------------------------------------------------------


class TestKB04:
    def test_fast_track_always_requires_approval(self, evaluator, delegation):
        """AC-55: KB04 fast-track always requires approval."""
        result = evaluator.evaluate("kb04_fast_track", delegation, {})
        assert result.requires_approval is True
        assert result.sla_class == "kb04_fast_track_6h"

    def test_pre_file_always_requires_approval(self, evaluator, delegation):
        """AC-55b: KB04 pre-file always requires approval."""
        result = evaluator.evaluate("kb04_pre_file", delegation, {})
        assert result.requires_approval is True
        assert result.sla_class == "kb04_fast_track_6h"


# ---------------------------------------------------------------------------
# Fraud termination (AC-43b)
# ---------------------------------------------------------------------------


class TestFraudTermination:
    def test_always_requires_24h_sla_approval(self, evaluator, delegation):
        """AC-43b: fraud termination requires approval with 24h SLA."""
        result = evaluator.evaluate("fraud_termination", delegation, {})
        assert result.requires_approval is True
        assert result.sla_class == "fraud_termination_24h"


# ---------------------------------------------------------------------------
# Threshold change
# ---------------------------------------------------------------------------


class TestThresholdChange:
    def test_always_requires_approval(self, evaluator, delegation):
        result = evaluator.evaluate("threshold_change", delegation, {})
        assert result.requires_approval is True


# ---------------------------------------------------------------------------
# AC-29b: biometric gate
# ---------------------------------------------------------------------------


class TestBiometricGate:
    def test_amount_below_50m_no_biometric(self, evaluator, delegation):
        """Amount < 50M VND → requires_biometric=False."""
        delegation.threshold_monthly_rent_vnd = Decimal("1000")  # very low threshold
        result = evaluator.evaluate(
            "contract_create",
            delegation,
            {"monthly_rent_vnd": 40_000_000, "term_months": 1},
        )
        assert result.requires_approval is True
        assert result.requires_biometric is False

    def test_amount_above_50m_requires_biometric(self, evaluator, delegation):
        """Amount >= 50M VND → requires_biometric=True (AC-29b)."""
        delegation.threshold_monthly_rent_vnd = Decimal("1000")  # force approval
        result = evaluator.evaluate(
            "contract_create",
            delegation,
            {"monthly_rent_vnd": 60_000_000, "term_months": 1},
        )
        assert result.requires_approval is True
        assert result.requires_biometric is True

    def test_exactly_50m_requires_biometric(self, evaluator, delegation):
        """Exactly at 50M VND → biometric required (boundary: >= 50M)."""
        delegation.threshold_monthly_rent_vnd = Decimal("1000")
        result = evaluator.evaluate(
            "contract_create",
            delegation,
            {"monthly_rent_vnd": 50_000_000, "term_months": 1},
        )
        assert result.requires_biometric is True


# ---------------------------------------------------------------------------
# Unknown action type
# ---------------------------------------------------------------------------


class TestUnknownActionType:
    def test_unknown_defaults_to_approval(self, evaluator, delegation):
        """Unknown action type → conservative default (require approval)."""
        result = evaluator.evaluate("some_unknown_action", delegation, {})
        assert result.requires_approval is True
