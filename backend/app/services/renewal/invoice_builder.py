"""Pure function: compute renewal invoice lines.

This module contains NO database imports — it is testable without a DB session.
The ORM wrapper lives in cron.py.

JP 更新料 (renewal fee) tax rules:
  - 更新料 itself is typically non-taxable (residential lease extension).
    See NTA guidance on 住宅用家屋の更新料.
  - 事務手数料 (admin fee) if charged separately — taxable 10%.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class InvoiceLineDraft:
    """Proposed invoice line for renewal — not yet persisted.

    Fields:
        label:           Display label (e.g. "更新料" or "事務手数料")
        line_type:       Maps to LINE_TYPE_VALUES in invoice_line domain.
        amount_jpy:      Gross amount in JPY (before tax).
        tax_treatment:   'exempt' | 'taxable' | 'zero_rated'
        tax_amount_jpy:  Consumption tax in JPY (0 if exempt).
    """

    label: str
    line_type: str
    amount_jpy: Decimal
    tax_treatment: str
    tax_amount_jpy: Decimal


# Standard JP consumption tax rate
_TAX_RATE = Decimal("0.10")

# Default renewal fee ratio: 1 month's rent (can be overridden per org config)
_DEFAULT_RENEWAL_FEE_RATIO = Decimal("1")


def compute_renewal_lines(
    *,
    monthly_rent_jpy: Decimal,
    renewal_fee_ratio: Decimal = _DEFAULT_RENEWAL_FEE_RATIO,
    admin_fee_jpy: Decimal = Decimal("0"),
) -> list[InvoiceLineDraft]:
    """Compute invoice lines for a contract renewal.

    Args:
        monthly_rent_jpy:   Monthly rent amount (used to compute 更新料).
        renewal_fee_ratio:  Multiplier applied to rent (default 1.0 = 1 month).
        admin_fee_jpy:      Optional admin fee (taxable). 0 = no admin fee.

    Returns:
        List of InvoiceLineDraft objects (typically 1–2 lines).

    Pure function — no DB access. Raises ValueError on negative inputs.
    """
    if monthly_rent_jpy <= 0:
        raise ValueError(
            f"monthly_rent_jpy must be positive, got {monthly_rent_jpy}"
        )
    if renewal_fee_ratio < 0:
        raise ValueError(
            f"renewal_fee_ratio must be non-negative, got {renewal_fee_ratio}"
        )
    if admin_fee_jpy < 0:
        raise ValueError(
            f"admin_fee_jpy must be non-negative, got {admin_fee_jpy}"
        )

    lines: list[InvoiceLineDraft] = []

    # 更新料 — residential renewal fee: exempt from consumption tax
    koushinryo = (monthly_rent_jpy * renewal_fee_ratio).quantize(Decimal("1"))
    if koushinryo > 0:
        lines.append(
            InvoiceLineDraft(
                label="更新料",
                line_type="koushinryo",
                amount_jpy=koushinryo,
                tax_treatment="exempt",
                tax_amount_jpy=Decimal("0"),
            )
        )

    # 事務手数料 — admin fee: taxable 10% if charged
    if admin_fee_jpy > 0:
        tax = (admin_fee_jpy * _TAX_RATE).quantize(Decimal("1"))
        lines.append(
            InvoiceLineDraft(
                label="更新事務手数料",
                line_type="other",
                amount_jpy=admin_fee_jpy,
                tax_treatment="taxable",
                tax_amount_jpy=tax,
            )
        )

    return lines
