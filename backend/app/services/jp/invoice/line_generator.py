"""JP invoice line generator — produces invoice lines from JpRentalTerms.

JP consumption tax rules encoded here:
  家賃 (rent)         → 非課税 (exempt) — 住宅の貸付, 消費税法 6条 別表第一 13号
  共益費 (management) → 課税 10%        — サービス提供として課税対象
  敷金 (shikikin)     → 非課税 (exempt) — 預り金性質
  礼金 (reikin)       → 非課税 (exempt) — 慣行上非課税
  更新料 (koushinryo) → 非課税 (exempt) — 賃料の一部と解釈
  仲介手数料 (brokerage) → 課税 10%    — 役務提供として課税対象
  保証金 (hoshou)     → 非課税 (exempt) — 預り金/敷金性質

Reference: https://www.nta.go.jp/taxes/shiraberu/taxanswer/shohi/6225.htm

Architecture:
  compute_line_drafts() — pure function, no ORM, fully testable.
  generate_invoice_lines() — wraps drafts into JpInvoiceLine ORM objects.
  compute_totals_from_drafts() — pure aggregation over drafts.
  compute_totals() — aggregation over ORM rows (for route layer).
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal
from typing import TYPE_CHECKING, Optional

# JP consumption tax rate (10% as of 2019)
JP_CONSUMPTION_TAX_RATE = Decimal("0.10")

# Deferred import — JpInvoiceLine only needed for ORM conversion
if TYPE_CHECKING:
    from app.domain.jp.invoice_line import JpInvoiceLine
    from app.domain.jp.rental_terms import JpRentalTerms


@dataclass
class InvoiceLineDraft:
    """Pure-Python value object for one invoice line.

    Used as intermediate representation before ORM insertion.
    Avoids SQLAlchemy mapper dependency in unit tests.
    """
    line_type: str
    amount_jpy: Decimal
    tax_treatment: str   # taxable | exempt | zero_rated
    tax_amount_jpy: Decimal
    description: str


@dataclass
class InvoiceTotals:
    """Summary totals for an invoice."""
    subtotal_jpy: Decimal
    tax_amount_jpy: Decimal
    total_jpy: Decimal


def _taxable_amount(amount: Decimal) -> Decimal:
    """Compute 10% consumption tax, rounded up (切り上げ, JP convention)."""
    raw = amount * JP_CONSUMPTION_TAX_RATE
    return Decimal(math.ceil(raw))


def _make_line(
    line_type: str,
    amount_jpy: Decimal,
    tax_treatment: str,
    description: str,
) -> InvoiceLineDraft:
    """Build one InvoiceLineDraft with correct tax_amount_jpy."""
    if tax_treatment == "taxable":
        tax_amount = _taxable_amount(amount_jpy)
    else:
        tax_amount = Decimal("0")

    return InvoiceLineDraft(
        line_type=line_type,
        amount_jpy=amount_jpy,
        tax_treatment=tax_treatment,
        tax_amount_jpy=tax_amount,
        description=description,
    )


def compute_line_drafts(
    terms: "JpRentalTerms",
    period_label: str = "",
    include_deposit_lines: bool = True,
) -> list[InvoiceLineDraft]:
    """Compute invoice line drafts from JpRentalTerms — pure function, no ORM.

    Returns InvoiceLineDraft objects (not ORM rows). Safe to call in tests
    without a database or SQLAlchemy mapper configured.

    Args:
        terms: The JpRentalTerms row (or any duck-typed object with the same attrs).
        period_label: Human-readable period suffix (e.g. '2025年1月分').
        include_deposit_lines: If False, skip one-time deposit/fee lines.

    Returns:
        List of InvoiceLineDraft value objects.
    """
    drafts: list[InvoiceLineDraft] = []

    # --- 家賃 (monthly rent) — always present, exempt ---
    rent_label = f"家賃 {period_label}".strip()
    drafts.append(_make_line("rent", terms.monthly_rent_jpy, "exempt", rent_label))

    # --- 共益費 (management fee) — taxable if present ---
    if terms.management_fee_jpy and terms.management_fee_jpy > 0:
        drafts.append(
            _make_line(
                "management",
                terms.management_fee_jpy,
                "taxable",
                f"共益費 {period_label}".strip(),
            )
        )

    if include_deposit_lines:
        rent = terms.monthly_rent_jpy

        # --- 敷金 (security deposit) — exempt ---
        if terms.shikikin_months and terms.shikikin_months > 0:
            amount = (rent * terms.shikikin_months).quantize(
                Decimal("1"), rounding=ROUND_HALF_UP
            )
            drafts.append(
                _make_line("shikikin", amount, "exempt",
                           f"敷金 ({terms.shikikin_months}ヶ月分)")
            )

        # --- 礼金 (key money) — exempt ---
        if terms.reikin_months and terms.reikin_months > 0:
            amount = (rent * terms.reikin_months).quantize(
                Decimal("1"), rounding=ROUND_HALF_UP
            )
            drafts.append(
                _make_line("reikin", amount, "exempt",
                           f"礼金 ({terms.reikin_months}ヶ月分)")
            )

        # --- 更新料 (renewal fee) — exempt ---
        if terms.koushinryo_months and terms.koushinryo_months > 0:
            amount = (rent * terms.koushinryo_months).quantize(
                Decimal("1"), rounding=ROUND_HALF_UP
            )
            drafts.append(
                _make_line("koushinryo", amount, "exempt",
                           f"更新料 ({terms.koushinryo_months}ヶ月分)")
            )

        # --- 仲介手数料 (brokerage) — taxable ---
        if terms.brokerage_rate and terms.brokerage_rate > 0:
            amount = (rent * terms.brokerage_rate).quantize(
                Decimal("1"), rounding=ROUND_HALF_UP
            )
            drafts.append(
                _make_line("brokerage", amount, "taxable",
                           f"仲介手数料 ({terms.brokerage_rate}ヶ月分)")
            )

        # --- 保証金/保証料 (guarantee/hoshou) — exempt ---
        if terms.hoshou_fee_jpy and terms.hoshou_fee_jpy > 0:
            drafts.append(
                _make_line("hoshou", terms.hoshou_fee_jpy, "exempt", "保証料")
            )

    return drafts


def generate_invoice_lines(
    terms: "JpRentalTerms",
    org_id: str,
    invoice_id: str,
    period_label: str = "",
    include_deposit_lines: bool = True,
) -> "list[JpInvoiceLine]":
    """Generate JpInvoiceLine ORM rows from a JpRentalTerms record.

    Wraps compute_line_drafts() and converts to SQLAlchemy model instances.
    Returned objects are NOT flushed — caller owns the transaction.
    """
    # Late import to avoid SA mapper init at module load time
    from app.domain.jp.invoice_line import JpInvoiceLine as _JpInvoiceLine  # noqa: PLC0415

    drafts = compute_line_drafts(
        terms=terms,
        period_label=period_label,
        include_deposit_lines=include_deposit_lines,
    )
    lines = []
    for draft in drafts:
        line = _JpInvoiceLine(
            org_id=org_id,
            region="jp",
            invoice_id=invoice_id,
            line_type=draft.line_type,
            amount_jpy=draft.amount_jpy,
            tax_treatment=draft.tax_treatment,
            tax_amount_jpy=draft.tax_amount_jpy,
            description=draft.description,
        )
        lines.append(line)
    return lines


def compute_totals_from_drafts(drafts: list[InvoiceLineDraft]) -> InvoiceTotals:
    """Compute invoice summary from InvoiceLineDraft objects (no ORM needed)."""
    subtotal = sum((d.amount_jpy for d in drafts), Decimal("0"))
    tax = sum((d.tax_amount_jpy for d in drafts), Decimal("0"))
    return InvoiceTotals(
        subtotal_jpy=subtotal,
        tax_amount_jpy=tax,
        total_jpy=subtotal + tax,
    )


def compute_totals(lines: "list[JpInvoiceLine]") -> InvoiceTotals:
    """Compute invoice summary from a list of JpInvoiceLine ORM rows."""
    subtotal = sum((ln.amount_jpy for ln in lines), Decimal("0"))
    tax = sum((ln.tax_amount_jpy for ln in lines), Decimal("0"))
    return InvoiceTotals(
        subtotal_jpy=subtotal,
        tax_amount_jpy=tax,
        total_jpy=subtotal + tax,
    )
