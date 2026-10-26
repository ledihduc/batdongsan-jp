"""Repository for JpPaymentIntent.

Multi-tenant isolation: every list query MUST filter by org_id.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.payment_intent import JpPaymentIntent


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpPaymentIntentRepository:
    """Org-scoped CRUD for jp_payment_intents."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id_org(
        self, intent_id: int, org_id: str
    ) -> Optional[JpPaymentIntent]:
        return (
            self.db.query(JpPaymentIntent)
            .filter(
                JpPaymentIntent.id == intent_id,
                JpPaymentIntent.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def get_by_provider_intent_id(
        self, provider_intent_id: str
    ) -> Optional[JpPaymentIntent]:
        """Lookup by provider's intent ID (for webhook correlation)."""
        return (
            self.db.query(JpPaymentIntent)
            .filter(JpPaymentIntent.provider_intent_id == provider_intent_id)
            .first()
        )

    def list_by_invoice(
        self, invoice_id: str, org_id: str
    ) -> list[JpPaymentIntent]:
        """All intents for one invoice — org scoped."""
        return (
            self.db.query(JpPaymentIntent)
            .filter(
                JpPaymentIntent.invoice_id == invoice_id,
                JpPaymentIntent.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .all()
        )

    def create(
        self,
        org_id: str,
        invoice_id: str,
        amount_jpy: Decimal,
        method: str,
        provider: str = "komoju",
    ) -> JpPaymentIntent:
        row = JpPaymentIntent(
            org_id=org_id,
            invoice_id=invoice_id,
            amount_jpy=amount_jpy,
            method=method,
            provider=provider,
            status="pending",
        )
        self.db.add(row)
        self.db.flush()
        return row

    def update_status(
        self,
        intent: JpPaymentIntent,
        status: str,
        provider_intent_id: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> JpPaymentIntent:
        intent.status = status
        if provider_intent_id is not None:
            intent.provider_intent_id = provider_intent_id
        if metadata is not None:
            intent.metadata_ = metadata
        self.db.flush()
        return intent
