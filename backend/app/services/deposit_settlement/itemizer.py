"""Pure function: compute net deposit refund from itemized deductions.

This module contains NO database imports — it is testable without a DB session.
ORM wrappers live in refund_invoice.py.

JP 敷金精算 (deposit settlement) rules:
  - Refund = gross_shikikin - sum(valid deductions)
  - Refund must be >= 0 (owner cannot charge beyond deposit)
  - Each deduction must have label, amount_jpy, and reason (see ガイドライン)
  - 国土交通省 ガイドライン: tenant responsible for intentional/negligent damage only.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Any


@dataclass(frozen=True)
class DeductionItem:
    """One validated deduction item in the settlement."""

    label: str
    amount_jpy: Decimal
    reason: str


@dataclass(frozen=True)
class RefundBreakdown:
    """Result of compute_net_refund() — pure data, no DB."""

    gross_jpy: Decimal
    deductions: list[DeductionItem]
    total_deductions_jpy: Decimal
    net_refund_jpy: Decimal


def compute_net_refund(
    gross_shikikin_jpy: Decimal,
    deductions: list[dict[str, Any]],
) -> tuple[Decimal, RefundBreakdown]:
    """Compute the net refund amount and itemized breakdown.

    Args:
        gross_shikikin_jpy: Original security deposit in JPY (must be positive).
        deductions:         List of deduction dicts from API / DB JSON.
                            Each must have: label (str), amount_jpy (int/Decimal), reason (str).

    Returns:
        Tuple of (net_refund_jpy, RefundBreakdown).

    Raises:
        ValueError: if gross is non-positive, any deduction has negative amount,
                    or total deductions exceed the gross deposit.
    """
    if gross_shikikin_jpy <= 0:
        raise ValueError(
            f"gross_shikikin_jpy must be positive, got {gross_shikikin_jpy}"
        )

    parsed_items: list[DeductionItem] = []
    for idx, item in enumerate(deductions):
        label = str(item.get("label", "")).strip()
        if not label:
            raise ValueError(f"Deduction[{idx}] missing 'label'")

        raw_amount = item.get("amount_jpy", 0)
        try:
            amount = Decimal(str(raw_amount))
        except Exception:
            raise ValueError(
                f"Deduction[{idx}] 'amount_jpy' not numeric: {raw_amount!r}"
            )

        if amount < 0:
            raise ValueError(
                f"Deduction[{idx}] amount_jpy must be >= 0, got {amount}"
            )

        reason = str(item.get("reason", "")).strip()
        parsed_items.append(DeductionItem(label=label, amount_jpy=amount, reason=reason))

    total_deductions = sum((d.amount_jpy for d in parsed_items), Decimal("0"))
    net_refund = gross_shikikin_jpy - total_deductions

    if net_refund < 0:
        raise ValueError(
            f"Total deductions ({total_deductions} JPY) exceed gross deposit "
            f"({gross_shikikin_jpy} JPY). Net refund cannot be negative."
        )

    breakdown = RefundBreakdown(
        gross_jpy=gross_shikikin_jpy,
        deductions=parsed_items,
        total_deductions_jpy=total_deductions,
        net_refund_jpy=net_refund,
    )

    return net_refund, breakdown
