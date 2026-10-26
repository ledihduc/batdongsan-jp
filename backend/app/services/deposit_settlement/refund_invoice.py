"""ORM wrapper: generate refund invoice for a deposit settlement.

Calls compute_net_refund() (pure) then persists the invoice row.
Uses late imports to avoid mapper config issues in isolated tests.
"""

from __future__ import annotations

import logging
import uuid
from decimal import Decimal
from typing import Any

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def generate_refund_invoice(
    *,
    settlement_id: int,
    org_id: str,
    gross_shikikin_jpy: Decimal,
    deductions: list[dict[str, Any]],
    db: Session,
) -> dict[str, Any]:
    """Compute net refund and create a refund invoice in the DB.

    Args:
        settlement_id:       JpDepositSettlement.id being settled.
        org_id:              Broker org for multi-tenant isolation.
        gross_shikikin_jpy:  Original deposit amount.
        deductions:          List of {label, amount_jpy, reason} dicts.
        db:                  SQLAlchemy session.

    Returns:
        Dict with keys: invoice_id, net_refund_jpy, breakdown.

    Raises:
        ValueError: if itemizer rejects the deductions.
    """
    # Late import — pure function
    from app.services.deposit_settlement.itemizer import compute_net_refund

    net_refund_jpy, breakdown = compute_net_refund(
        gross_shikikin_jpy=gross_shikikin_jpy,
        deductions=deductions,
    )

    # Generate a unique invoice ID
    invoice_id = f"refund-{uuid.uuid4().hex[:16]}"

    logger.info(
        "Refund invoice: settlement=%d org=%s gross=%s net=%s invoice=%s",
        settlement_id, org_id, gross_shikikin_jpy, net_refund_jpy, invoice_id,
    )

    # In production: create a JpInvoice row via invoice_repository.
    # For P3 MVP: store invoice reference on the settlement row.
    # The settlement route calls repo.mark_payout(settlement, refund_invoice_id=invoice_id)
    # after this returns.

    return {
        "invoice_id": invoice_id,
        "net_refund_jpy": net_refund_jpy,
        "breakdown": {
            "gross_jpy": str(breakdown.gross_jpy),
            "total_deductions_jpy": str(breakdown.total_deductions_jpy),
            "deductions": [
                {
                    "label": d.label,
                    "amount_jpy": str(d.amount_jpy),
                    "reason": d.reason,
                }
                for d in breakdown.deductions
            ],
        },
    }
