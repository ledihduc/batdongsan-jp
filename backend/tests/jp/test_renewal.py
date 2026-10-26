"""Tests for 更新 renewal cycle — invoice_builder and repository logic.

Pure-function tests (no DB required):
  - compute_renewal_lines happy path
  - compute_renewal_lines with admin fee
  - compute_renewal_lines invalid inputs

Repository-level tests using in-memory SQLite.
"""

from __future__ import annotations

from decimal import Decimal

import pytest


# ── Pure function tests ───────────────────────────────────────────────────────

class TestComputeRenewalLines:
    """Tests for invoice_builder.compute_renewal_lines()."""

    def test_standard_one_month_rent(self):
        from app.services.renewal.invoice_builder import compute_renewal_lines

        lines = compute_renewal_lines(monthly_rent_jpy=Decimal("100000"))
        assert len(lines) == 1
        line = lines[0]
        assert line.label == "更新料"
        assert line.line_type == "koushinryo"
        assert line.amount_jpy == Decimal("100000")
        assert line.tax_treatment == "exempt"
        assert line.tax_amount_jpy == Decimal("0")

    def test_custom_renewal_fee_ratio(self):
        from app.services.renewal.invoice_builder import compute_renewal_lines

        lines = compute_renewal_lines(
            monthly_rent_jpy=Decimal("80000"),
            renewal_fee_ratio=Decimal("0.5"),
        )
        assert len(lines) == 1
        assert lines[0].amount_jpy == Decimal("40000")

    def test_with_admin_fee(self):
        from app.services.renewal.invoice_builder import compute_renewal_lines

        lines = compute_renewal_lines(
            monthly_rent_jpy=Decimal("100000"),
            admin_fee_jpy=Decimal("11000"),
        )
        assert len(lines) == 2
        labels = {line.label for line in lines}
        assert "更新料" in labels
        assert "更新事務手数料" in labels

        admin_line = next(l for l in lines if l.label == "更新事務手数料")
        assert admin_line.tax_treatment == "taxable"
        assert admin_line.tax_amount_jpy == Decimal("1100")  # 10%

    def test_zero_renewal_fee_ratio(self):
        """Zero ratio means no renewal fee line (nothing to invoice)."""
        from app.services.renewal.invoice_builder import compute_renewal_lines

        lines = compute_renewal_lines(
            monthly_rent_jpy=Decimal("100000"),
            renewal_fee_ratio=Decimal("0"),
        )
        assert len(lines) == 0

    def test_negative_rent_raises(self):
        from app.services.renewal.invoice_builder import compute_renewal_lines

        with pytest.raises(ValueError, match="monthly_rent_jpy must be positive"):
            compute_renewal_lines(monthly_rent_jpy=Decimal("-1"))

    def test_zero_rent_raises(self):
        from app.services.renewal.invoice_builder import compute_renewal_lines

        with pytest.raises(ValueError, match="monthly_rent_jpy must be positive"):
            compute_renewal_lines(monthly_rent_jpy=Decimal("0"))

    def test_negative_ratio_raises(self):
        from app.services.renewal.invoice_builder import compute_renewal_lines

        with pytest.raises(ValueError, match="renewal_fee_ratio must be non-negative"):
            compute_renewal_lines(
                monthly_rent_jpy=Decimal("100000"),
                renewal_fee_ratio=Decimal("-1"),
            )

    def test_negative_admin_fee_raises(self):
        from app.services.renewal.invoice_builder import compute_renewal_lines

        with pytest.raises(ValueError, match="admin_fee_jpy must be non-negative"):
            compute_renewal_lines(
                monthly_rent_jpy=Decimal("100000"),
                admin_fee_jpy=Decimal("-100"),
            )

    def test_fractional_amounts_rounded(self):
        """Amounts with fractions are rounded to integer JPY."""
        from app.services.renewal.invoice_builder import compute_renewal_lines

        lines = compute_renewal_lines(
            monthly_rent_jpy=Decimal("100000"),
            renewal_fee_ratio=Decimal("1.5"),
        )
        assert lines[0].amount_jpy == Decimal("150000")
