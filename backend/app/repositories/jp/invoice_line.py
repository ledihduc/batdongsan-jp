"""Repository for JpInvoiceLine.

Multi-tenant isolation: every list query MUST filter by org_id.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.domain.jp.invoice_line import JpInvoiceLine


class JpInvoiceLineRepository:
    """Org-scoped CRUD for jp_invoice_lines."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def list_by_invoice(
        self, invoice_id: str, org_id: str
    ) -> list[JpInvoiceLine]:
        """All lines for one invoice — org scoped."""
        return (
            self.db.query(JpInvoiceLine)
            .filter(
                JpInvoiceLine.invoice_id == invoice_id,
                JpInvoiceLine.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .all()
        )

    def bulk_insert(self, lines: list[JpInvoiceLine]) -> None:
        """Add multiple lines in one flush."""
        for line in lines:
            self.db.add(line)
        self.db.flush()
