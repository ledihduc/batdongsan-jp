"""InvoiceRepository — host-scoped CRUD for invoices + line items + credit notes."""

from __future__ import annotations

from typing import Optional

from app import models
from app.repositories.base import HostScopedRepository


class InvoiceRepository(HostScopedRepository[models.Invoice]):
    model_class = models.Invoice
    host_field_name = "host_id"

    def list(  # type: ignore[override]
        self,
        status: Optional[str] = None,
        contract_id: Optional[int] = None,
        month: Optional[str] = None,  # 'YYYY-MM' — matches period_start prefix
    ) -> list[models.Invoice]:
        q = self._base_query()
        if status is not None:
            q = q.filter(models.Invoice.status == status)
        if contract_id is not None:
            q = q.filter(models.Invoice.contract_id == contract_id)
        if month is not None:
            q = q.filter(models.Invoice.period_start.like(f"{month}%"))
        return q.order_by(models.Invoice.issued_date.desc()).all()

    def get_by_public_token(self, token: str) -> Optional[models.Invoice]:
        """Public route lookup — bypasses host_id filter on purpose (anon access)."""
        return (
            self.db.query(models.Invoice)
            .filter(models.Invoice.public_token == token)
            .first()
        )

    def get_for_contract_period(
        self, contract_id: int, period_start: str, period_end: str
    ) -> Optional[models.Invoice]:
        """Return existing invoice for (contract, period) — used for idempotent batch gen."""
        return (
            self._base_query()
            .filter(
                models.Invoice.contract_id == contract_id,
                models.Invoice.period_start == period_start,
                models.Invoice.period_end == period_end,
            )
            .first()
        )

    def list_line_items(self, invoice_id: int) -> list[models.InvoiceLineItem]:
        return (
            self.db.query(models.InvoiceLineItem)
            .filter(models.InvoiceLineItem.invoice_id == invoice_id)
            .order_by(models.InvoiceLineItem.sort_order.asc(), models.InvoiceLineItem.id.asc())
            .all()
        )

    def list_payments(self, invoice_id: int) -> list[models.Payment]:
        return (
            self.db.query(models.Payment)
            .filter(models.Payment.invoice_id == invoice_id)
            .order_by(models.Payment.paid_at.asc())
            .all()
        )

    def list_credit_notes(self, invoice_id: int) -> list[models.CreditNote]:
        return (
            self.db.query(models.CreditNote)
            .filter(models.CreditNote.original_invoice_id == invoice_id)
            .order_by(models.CreditNote.created_at.asc())
            .all()
        )

    def list_unpaid(self) -> list[models.Invoice]:
        return (
            self._base_query()
            .filter(models.Invoice.status.in_(("sent", "overdue")))
            .all()
        )
