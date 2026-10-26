"""SQLAlchemy 2.0 model for JpPaymentIntent — payment request to JP payment provider.

Table: jp_payment_intents

One intent per payment attempt. Komoju returns a provider_intent_id which is
used for status polling and webhook correlation.

Status state machine:
  pending → processing → succeeded | failed | expired

Design decisions:
- Managed by migration 0151_jp_payment_intents.
- All amounts stored as Numeric (exact) — never float.
- metadata JSONB stores provider-specific extras (konbini voucher, bank ref, etc.).
- org_id: multi-tenant isolation.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any, Optional

from sqlalchemy import DateTime, Integer, JSON, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


# Valid status values — state machine
PAYMENT_STATUS_VALUES = ("pending", "processing", "succeeded", "failed", "expired")

# Valid payment method values
PAYMENT_METHOD_VALUES = ("card", "konbini", "bank_transfer")


class JpPaymentIntent(Base):
    """Payment intent tracking row for a JP payment via Komoju (or future providers).

    Lifecycle:
      1. Created (pending) when user initiates payment.
      2. Provider returns intent_id → stored in provider_intent_id.
      3. Webhook updates status to processing → succeeded | failed | expired.

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(JpPaymentIntent.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_payment_intents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    invoice_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Invoice UUID. No FK — cross-domain boundary.",
    )

    provider: Mapped[str] = mapped_column(
        String(32), nullable=False, default="komoju",
        comment="Payment provider name (komoju etc.).",
    )
    provider_intent_id: Mapped[Optional[str]] = mapped_column(
        String(128), nullable=True, index=True,
        comment="Provider's opaque payment intent ID for correlation and status polls.",
    )

    method: Mapped[str] = mapped_column(
        String(20), nullable=False,
        comment="card | konbini | bank_transfer",
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending",
        comment="pending | processing | succeeded | failed | expired",
    )

    amount_jpy: Mapped[Decimal] = mapped_column(
        Numeric(12, 0), nullable=False,
        comment="Total amount in JPY.",
    )

    # Extra provider data (konbini voucher code, bank transfer details, etc.)
    metadata_: Mapped[Optional[Any]] = mapped_column(
        "metadata",
        JSON, nullable=True,
        comment="Freeform provider metadata (konbini voucher code, bank ref, etc.).",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
