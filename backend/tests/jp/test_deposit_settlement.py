"""Tests for 敷金精算 deposit settlement — itemizer pure function.

All tests are pure (no DB required).
"""

from __future__ import annotations

from decimal import Decimal

import pytest


class TestComputeNetRefund:
    """Tests for itemizer.compute_net_refund()."""

    def test_no_deductions_full_refund(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        net, breakdown = compute_net_refund(
            gross_shikikin_jpy=Decimal("200000"),
            deductions=[],
        )
        assert net == Decimal("200000")
        assert breakdown.total_deductions_jpy == Decimal("0")
        assert len(breakdown.deductions) == 0

    def test_partial_deduction(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        deductions = [
            {"label": "畳の取替", "amount_jpy": 30000, "reason": "故意破損"},
            {"label": "クリーニング", "amount_jpy": 20000, "reason": "通常清掃"},
        ]
        net, breakdown = compute_net_refund(
            gross_shikikin_jpy=Decimal("200000"),
            deductions=deductions,
        )
        assert net == Decimal("150000")
        assert breakdown.total_deductions_jpy == Decimal("50000")
        assert len(breakdown.deductions) == 2

    def test_full_deduction_zero_refund(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        net, breakdown = compute_net_refund(
            gross_shikikin_jpy=Decimal("100000"),
            deductions=[{"label": "修繕", "amount_jpy": 100000, "reason": "損傷"}],
        )
        assert net == Decimal("0")

    def test_deductions_exceed_gross_raises(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        with pytest.raises(ValueError, match="exceed gross deposit"):
            compute_net_refund(
                gross_shikikin_jpy=Decimal("100000"),
                deductions=[{"label": "X", "amount_jpy": 150000, "reason": "Y"}],
            )

    def test_negative_deduction_raises(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        with pytest.raises(ValueError, match="amount_jpy must be >= 0"):
            compute_net_refund(
                gross_shikikin_jpy=Decimal("100000"),
                deductions=[{"label": "X", "amount_jpy": -1, "reason": "Y"}],
            )

    def test_missing_label_raises(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        with pytest.raises(ValueError, match="missing 'label'"):
            compute_net_refund(
                gross_shikikin_jpy=Decimal("100000"),
                deductions=[{"label": "", "amount_jpy": 1000, "reason": "Y"}],
            )

    def test_non_numeric_amount_raises(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        with pytest.raises(ValueError, match="not numeric"):
            compute_net_refund(
                gross_shikikin_jpy=Decimal("100000"),
                deductions=[{"label": "X", "amount_jpy": "not-a-number", "reason": "Y"}],
            )

    def test_negative_gross_raises(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        with pytest.raises(ValueError, match="must be positive"):
            compute_net_refund(
                gross_shikikin_jpy=Decimal("-1"),
                deductions=[],
            )

    def test_breakdown_fields(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        net, breakdown = compute_net_refund(
            gross_shikikin_jpy=Decimal("300000"),
            deductions=[{"label": "畳", "amount_jpy": 50000, "reason": "破損"}],
        )
        assert breakdown.gross_jpy == Decimal("300000")
        assert breakdown.net_refund_jpy == Decimal("250000")
        assert breakdown.deductions[0].label == "畳"
        assert breakdown.deductions[0].amount_jpy == Decimal("50000")
        assert breakdown.deductions[0].reason == "破損"

    def test_zero_gross_raises(self):
        from app.services.deposit_settlement.itemizer import compute_net_refund

        with pytest.raises(ValueError):
            compute_net_refund(gross_shikikin_jpy=Decimal("0"), deductions=[])
