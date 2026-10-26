"""Repository for JpContractRenewal — 更新 renewal records.

Multi-tenant isolation: every list query MUST filter by org_id.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.contract_renewal import JpContractRenewal


class JpContractRenewalRepository:
    """Org-scoped CRUD for jp_contract_renewals."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get(self, renewal_id: int, org_id: str) -> Optional[JpContractRenewal]:
        """Fetch one renewal by ID — org scoped."""
        return (
            self.db.query(JpContractRenewal)
            .filter(
                JpContractRenewal.id == renewal_id,
                JpContractRenewal.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def get_by_contract(
        self, contract_id: int, org_id: str, status: Optional[str] = None
    ) -> Optional[JpContractRenewal]:
        """Get the active (non-expired) renewal for a contract."""
        q = self.db.query(JpContractRenewal).filter(
            JpContractRenewal.contract_id == contract_id,
            JpContractRenewal.org_id == org_id,  # MULTI-TENANT ISOLATION
        )
        if status:
            q = q.filter(JpContractRenewal.status == status)
        return q.order_by(JpContractRenewal.created_at.desc()).first()

    def exists_for_contract(self, contract_id: int, org_id: str) -> bool:
        """Return True if a non-expired renewal already exists for this contract."""
        return (
            self.db.query(JpContractRenewal)
            .filter(
                JpContractRenewal.contract_id == contract_id,
                JpContractRenewal.org_id == org_id,  # MULTI-TENANT ISOLATION
                JpContractRenewal.status.notin_(["expired"]),
            )
            .first()
        ) is not None

    def list_by_org(self, org_id: str, status: Optional[str] = None) -> list[JpContractRenewal]:
        """List all renewals for an org, optionally filtered by status."""
        q = self.db.query(JpContractRenewal).filter(
            JpContractRenewal.org_id == org_id,  # MULTI-TENANT ISOLATION
        )
        if status:
            q = q.filter(JpContractRenewal.status == status)
        return q.order_by(JpContractRenewal.created_at.desc()).all()

    def create(
        self,
        org_id: str,
        contract_id: int,
        scheduled_at: datetime,
    ) -> JpContractRenewal:
        """Create a new pending renewal row."""
        row = JpContractRenewal(
            org_id=org_id,
            contract_id=contract_id,
            scheduled_at=scheduled_at,
            status="pending",
        )
        self.db.add(row)
        self.db.flush()
        return row

    def update_status(
        self,
        renewal: JpContractRenewal,
        status: str,
        *,
        invoice_id: Optional[str] = None,
        renewal_fee_jpy: Optional[Decimal] = None,
        notified_at: Optional[datetime] = None,
    ) -> JpContractRenewal:
        """Update status and optional fields."""
        renewal.status = status
        if invoice_id is not None:
            renewal.invoice_id = invoice_id
        if renewal_fee_jpy is not None:
            renewal.renewal_fee_jpy = renewal_fee_jpy
        if notified_at is not None:
            renewal.notified_at = notified_at
        self.db.flush()
        return renewal
