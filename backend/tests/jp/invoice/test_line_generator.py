"""Tests for JP invoice line generator — tax treatment and line amounts.

Tests target compute_line_drafts() (pure function, no ORM) and
compute_totals_from_drafts(). No DB connection required.
"""

from __future__ import annotations

import os
from decimal import Decimal
from unittest.mock import MagicMock

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest

from app.services.jp.invoice.line_generator import (
    compute_line_drafts,
    compute_totals_from_drafts,
)


def _make_terms(**kwargs) -> MagicMock:
    """Create a duck-typed JpRentalTerms mock (no SQLAlchemy needed)."""
    t = MagicMock(spec=object)  # spec=object avoids SA mapper
    t.monthly_rent_jpy = Decimal(str(kwargs.get("monthly_rent_jpy", 80000)))
    raw_mgmt = kwargs.get("management_fee_jpy", 0)
    t.management_fee_jpy = Decimal(str(raw_mgmt)) if raw_mgmt else None
    raw_shikikin = kwargs.get("shikikin_months", 0)
    t.shikikin_months = Decimal(str(raw_shikikin)) if raw_shikikin else None
    raw_reikin = kwargs.get("reikin_months", 0)
    t.reikin_months = Decimal(str(raw_reikin)) if raw_reikin else None
    raw_koushin = kwargs.get("koushinryo_months", 0)
    t.koushinryo_months = Decimal(str(raw_koushin)) if raw_koushin else None
    raw_broker = kwargs.get("brokerage_rate", 0)
    t.brokerage_rate = Decimal(str(raw_broker)) if raw_broker else None
    raw_hoshou = kwargs.get("hoshou_fee_jpy", 0)
    t.hoshou_fee_jpy = Decimal(str(raw_hoshou)) if raw_hoshou else None
    return t


class TestComputeLineDrafts:
    """Tests for compute_line_drafts() — pure function, no ORM."""

    def test_rent_line_always_present(self) -> None:
        terms = _make_terms(monthly_rent_jpy=80000)
        drafts = compute_line_drafts(terms)
        rent = [d for d in drafts if d.line_type == "rent"]
        assert len(rent) == 1
        assert rent[0].amount_jpy == Decimal("80000")

    def test_rent_is_exempt(self) -> None:
        """家賃 must be non-taxable (消費税法 6条 別表第一 13号)."""
        terms = _make_terms(monthly_rent_jpy=80000)
        drafts = compute_line_drafts(terms)
        rent = [d for d in drafts if d.line_type == "rent"][0]
        assert rent.tax_treatment == "exempt"
        assert rent.tax_amount_jpy == Decimal("0")

    def test_management_fee_is_taxable(self) -> None:
        """共益費 is taxable at 10%."""
        terms = _make_terms(monthly_rent_jpy=80000, management_fee_jpy=5000)
        drafts = compute_line_drafts(terms)
        mgmt = [d for d in drafts if d.line_type == "management"][0]
        assert mgmt.tax_treatment == "taxable"
        # 5000 * 10% = 500 (ceil)
        assert mgmt.tax_amount_jpy == Decimal("500")

    def test_management_fee_absent_when_zero(self) -> None:
        terms = _make_terms(monthly_rent_jpy=80000, management_fee_jpy=0)
        drafts = compute_line_drafts(terms)
        mgmt = [d for d in drafts if d.line_type == "management"]
        assert len(mgmt) == 0

    def test_shikikin_is_exempt(self) -> None:
        """敷金 must be non-taxable."""
        terms = _make_terms(monthly_rent_jpy=80000, shikikin_months=1)
        drafts = compute_line_drafts(terms)
        shikikin = [d for d in drafts if d.line_type == "shikikin"][0]
        assert shikikin.tax_treatment == "exempt"
        assert shikikin.amount_jpy == Decimal("80000")
        assert shikikin.tax_amount_jpy == Decimal("0")

    def test_reikin_is_exempt(self) -> None:
        """礼金 must be non-taxable."""
        terms = _make_terms(monthly_rent_jpy=80000, reikin_months=1)
        drafts = compute_line_drafts(terms)
        reikin = [d for d in drafts if d.line_type == "reikin"][0]
        assert reikin.tax_treatment == "exempt"

    def test_brokerage_is_taxable(self) -> None:
        """仲介手数料 must be taxable at 10%."""
        terms = _make_terms(monthly_rent_jpy=80000, brokerage_rate=1)
        drafts = compute_line_drafts(terms)
        brokerage = [d for d in drafts if d.line_type == "brokerage"][0]
        assert brokerage.tax_treatment == "taxable"
        # 80000 * 10% = 8000
        assert brokerage.tax_amount_jpy == Decimal("8000")

    def test_brokerage_rate_1_1_max(self) -> None:
        """Legal max brokerage rate is 1.1 months."""
        terms = _make_terms(monthly_rent_jpy=100000, brokerage_rate="1.1")
        drafts = compute_line_drafts(terms)
        brokerage = [d for d in drafts if d.line_type == "brokerage"][0]
        # 100000 * 1.1 = 110000
        assert brokerage.amount_jpy == Decimal("110000")
        # tax: 110000 * 10% = 11000
        assert brokerage.tax_amount_jpy == Decimal("11000")

    def test_hoshou_is_exempt(self) -> None:
        terms = _make_terms(monthly_rent_jpy=80000, hoshou_fee_jpy=30000)
        drafts = compute_line_drafts(terms)
        hoshou = [d for d in drafts if d.line_type == "hoshou"][0]
        assert hoshou.tax_treatment == "exempt"
        assert hoshou.amount_jpy == Decimal("30000")

    def test_no_deposit_lines_when_excluded(self) -> None:
        """include_deposit_lines=False skips all one-time deposit lines."""
        terms = _make_terms(
            monthly_rent_jpy=80000,
            shikikin_months=1,
            reikin_months=1,
            brokerage_rate=1,
        )
        drafts = compute_line_drafts(terms, include_deposit_lines=False)
        line_types = [d.line_type for d in drafts]
        assert "shikikin" not in line_types
        assert "reikin" not in line_types
        assert "brokerage" not in line_types
        assert "rent" in line_types

    def test_koushinryo_is_exempt(self) -> None:
        terms = _make_terms(monthly_rent_jpy=100000, koushinryo_months=1)
        drafts = compute_line_drafts(terms)
        kou = [d for d in drafts if d.line_type == "koushinryo"][0]
        assert kou.tax_treatment == "exempt"
        assert kou.amount_jpy == Decimal("100000")


class TestComputeTotalsFromDrafts:
    """Tests for compute_totals_from_drafts() — no ORM."""

    def test_subtotal_and_tax(self) -> None:
        terms = _make_terms(monthly_rent_jpy=80000, management_fee_jpy=5000)
        drafts = compute_line_drafts(terms, include_deposit_lines=False)
        totals = compute_totals_from_drafts(drafts)
        # subtotal = 80000 + 5000 = 85000
        assert totals.subtotal_jpy == Decimal("85000")
        # tax = 0 (rent exempt) + 500 (management 10%) = 500
        assert totals.tax_amount_jpy == Decimal("500")
        assert totals.total_jpy == Decimal("85500")

    def test_empty_list_returns_zero(self) -> None:
        totals = compute_totals_from_drafts([])
        assert totals.subtotal_jpy == Decimal("0")
        assert totals.tax_amount_jpy == Decimal("0")
        assert totals.total_jpy == Decimal("0")

    def test_all_exempt_invoice_has_zero_tax(self) -> None:
        """All-exempt invoice: rent only → tax = 0."""
        terms = _make_terms(monthly_rent_jpy=80000)
        drafts = compute_line_drafts(terms)
        totals = compute_totals_from_drafts(drafts)
        assert totals.tax_amount_jpy == Decimal("0")
        assert totals.total_jpy == totals.subtotal_jpy

    def test_taxable_brokerage_adds_to_total(self) -> None:
        terms = _make_terms(monthly_rent_jpy=100000, brokerage_rate=1)
        drafts = compute_line_drafts(terms, include_deposit_lines=True)
        totals = compute_totals_from_drafts(drafts)
        # rent=100000 (exempt) + brokerage=100000 (taxable, tax=10000)
        assert totals.subtotal_jpy == Decimal("200000")
        assert totals.tax_amount_jpy == Decimal("10000")
        assert totals.total_jpy == Decimal("210000")
