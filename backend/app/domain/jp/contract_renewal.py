"""SQLAlchemy 2.0 model for JpContractRenewal — 更新 renewal cycle.

Table: jp_contract_renewals

JP rental contract renewal flow:
  60 days before contract.expires_at → cron creates renewal row (pending)
  → invoice generated (invoiced)
  → tenant confirms (confirmed)
  → contract extended (renewed) | grace expires (expired)

Design decisions:
- Managed by migration 0156_contract_renewals (additive, nullable, idempotent).
- No FK to contracts table — cross-domain boundary (same pattern as applications).
- org_id: multi-tenant isolation. Every repository list() MUST filter by org_id.
- Cron idempotency: only one renewal row per (contract_id) with non-expired status.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import DateTime, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


# Valid status values — state machine
RENEWAL_STATUS_VALUES = ("pending", "invoiced", "confirmed", "renewed", "expired")


class JpContractRenewal(Base):
    """JP contract renewal record (更新).

    Created by cron 60 days before contract expiry.
    Drives the renewal fee invoice and tenant confirmation flow.

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(JpContractRenewal.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_contract_renewals"

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

    # When renewal process should trigger (contract.expires_at - 60d)
    scheduled_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
        comment="When renewal notification/invoice should fire.",
    )

    # 更新料 (renewal fee) in JPY — populated when invoice is generated
    renewal_fee_jpy: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(12, 0), nullable=True,
        comment="更新料 in JPY. Null until invoice is generated.",
    )

    # Status in the renewal state machine
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending",
        comment="pending | invoiced | confirmed | renewed | expired",
    )

    # Invoice reference (populated when invoiced)
    invoice_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True,
        comment="JpInvoice.id once generated. Null until invoiced.",
    )

    # When tenant was notified
    notified_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="When tenant notification was enqueued.",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
