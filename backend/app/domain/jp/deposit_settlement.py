"""SQLAlchemy 2.0 model for JpDepositSettlement — 敷金精算 deposit settlement.

Table: jp_deposit_settlements

Deposit settlement flow:
  owner creates draft → itemizes deductions → tenant reviews →
  tenant signs (accepted | disputed) → payout processed (refunded)

Design decisions:
- Managed by migration 0157_deposit_settlements (additive, nullable, idempotent).
- deductions_json: list of {label, amount_jpy, reason} — flexible itemization.
- Dual-approval required (owner_signed_at + tenant_signed_at) before payout.
- org_id: multi-tenant isolation. Every repository list() MUST filter by org_id.
- refund_jpy = gross_shikikin_jpy - sum(deductions). Must be >= 0.
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
SETTLEMENT_STATUS_VALUES = ("draft", "tenant_review", "accepted", "disputed", "refunded")


class JpDepositSettlement(Base):
    """JP security deposit settlement record (敷金精算).

    Tracks the full lifecycle of returning a tenant's security deposit:
    from owner itemizing deductions to final refund payout.

    Security invariant: payout requires both owner_signed_at and tenant_signed_at.

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(JpDepositSettlement.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_deposit_settlements"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Multi-tenant broker org isolation
    org_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    # Parent contract (no FK — cross-domain boundary)
    contract_id: Mapped[int] = mapped_column(
        Integer, nullable=False, index=True,
        comment="Platform contract ID. No FK — cross-domain boundary.",
    )

    # Status in the settlement state machine
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="draft",
        comment="draft | tenant_review | accepted | disputed | refunded",
    )

    # Original deposit amount
    gross_shikikin_jpy: Mapped[Decimal] = mapped_column(
        Numeric(12, 0), nullable=False,
        comment="Original security deposit amount in JPY.",
    )

    # Itemized deductions: [{label: str, amount_jpy: int, reason: str}]
    deductions_json: Mapped[Optional[Any]] = mapped_column(
        JSON, nullable=True,
        comment="Owner deductions: [{label, amount_jpy, reason}].",
    )

    # Net refund (computed from gross - deductions)
    refund_jpy: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(12, 0), nullable=True,
        comment="Net refund to tenant. Null until itemizer runs. Must be >= 0.",
    )

    # Reference to refund invoice
    refund_invoice_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True,
        comment="JpInvoice.id for the refund. Null until generated.",
    )

    # Dual-approval timestamps
    owner_signed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="When owner confirmed the settlement itemization.",
    )
    tenant_signed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="When tenant accepted the settlement.",
    )

    # Payout timestamp
    payout_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="When refund payout was processed.",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
