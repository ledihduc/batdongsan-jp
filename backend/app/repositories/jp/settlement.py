"""Repository for JpDepositSettlement — 敷金精算 records.

Multi-tenant isolation: every list query MUST filter by org_id.
"""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.domain.jp.deposit_settlement import JpDepositSettlement


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


class JpDepositSettlementRepository:
    """Org-scoped CRUD for jp_deposit_settlements."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get(self, settlement_id: int, org_id: str) -> Optional[JpDepositSettlement]:
        """Fetch one settlement by ID — org scoped."""
        return (
            self.db.query(JpDepositSettlement)
            .filter(
                JpDepositSettlement.id == settlement_id,
                JpDepositSettlement.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def get_by_contract(
        self, contract_id: int, org_id: str
    ) -> Optional[JpDepositSettlement]:
        """Get the active settlement for a contract."""
        return (
            self.db.query(JpDepositSettlement)
            .filter(
                JpDepositSettlement.contract_id == contract_id,
                JpDepositSettlement.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .order_by(JpDepositSettlement.created_at.desc())
            .first()
        )

    def list_by_org(
        self, org_id: str, status: Optional[str] = None
    ) -> list[JpDepositSettlement]:
        """List settlements for an org, optionally filtered by status."""
        q = self.db.query(JpDepositSettlement).filter(
            JpDepositSettlement.org_id == org_id,  # MULTI-TENANT ISOLATION
        )
        if status:
            q = q.filter(JpDepositSettlement.status == status)
        return q.order_by(JpDepositSettlement.created_at.desc()).all()

    def create(
        self,
        org_id: str,
        contract_id: int,
        gross_shikikin_jpy: Decimal,
    ) -> JpDepositSettlement:
        """Create a new draft settlement."""
        row = JpDepositSettlement(
            org_id=org_id,
            contract_id=contract_id,
            gross_shikikin_jpy=gross_shikikin_jpy,
            status="draft",
        )
        self.db.add(row)
        self.db.flush()
        return row

    def update_deductions(
        self,
        settlement: JpDepositSettlement,
        deductions: list[dict[str, Any]],
        refund_jpy: Decimal,
    ) -> JpDepositSettlement:
        """Update itemized deductions and computed refund."""
        settlement.deductions_json = deductions
        settlement.refund_jpy = refund_jpy
        settlement.status = "tenant_review"
        self.db.flush()
        return settlement

    def tenant_sign(self, settlement: JpDepositSettlement) -> JpDepositSettlement:
        """Record tenant acceptance of the settlement."""
        settlement.tenant_signed_at = _now_utc()
        settlement.status = "accepted"
        self.db.flush()
        return settlement

    def owner_sign(self, settlement: JpDepositSettlement) -> JpDepositSettlement:
        """Record owner sign-off on the settlement."""
        settlement.owner_signed_at = _now_utc()
        self.db.flush()
        return settlement

    def mark_payout(
        self,
        settlement: JpDepositSettlement,
        refund_invoice_id: Optional[str] = None,
    ) -> JpDepositSettlement:
        """Mark settlement as refunded."""
        settlement.payout_at = _now_utc()
        settlement.status = "refunded"
        if refund_invoice_id is not None:
            settlement.refund_invoice_id = refund_invoice_id
        self.db.flush()
        return settlement
