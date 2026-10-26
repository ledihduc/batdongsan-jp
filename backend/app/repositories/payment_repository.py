"""PaymentRepository — host-scoped CRUD for payments."""

from __future__ import annotations

from typing import Optional

from app import models
from app.repositories.base import HostScopedRepository


class PaymentRepository(HostScopedRepository[models.Payment]):
    model_class = models.Payment
    host_field_name = "host_id"

    def list(  # type: ignore[override]
        self, invoice_id: Optional[int] = None
    ) -> list[models.Payment]:
        q = self._base_query()
        if invoice_id is not None:
            q = q.filter(models.Payment.invoice_id == invoice_id)
        return q.order_by(models.Payment.paid_at.asc()).all()

    def sum_for_invoice(self, invoice_id: int) -> float:
        """Sum of all payments against an invoice (host-scoped)."""
        rows = (
            self._base_query()
            .filter(models.Payment.invoice_id == invoice_id)
            .all()
        )
        return float(sum(r.amount for r in rows))
