"""SQLAlchemy 2.0 model for JP 内見 (naiken) viewing appointments.

Table: jp_viewings

内見 flow:
  tenant creates request with ≤3 preferred slots
  → agent selects and confirms one slot
  → both parties notified

State machine: requested → confirmed → completed | cancelled

Business rules (enforced in service layer, not DB):
  - Max 3 requested_slots per viewing request
  - Each slot must be during business hours (10:00-19:00 JST)
  - Confirmed slot must be ≥24h from creation time (lead time)
  - Only agent can confirm/complete; only creator or agent can cancel

Design decisions:
- Managed by migration 0146_jp_viewings (additive, nullable, idempotent).
- requested_slots stored as JSON (JSONB on Postgres) for flexibility.
- No FK constraints on listing_id/tenant_id/agent_id to keep JP domain independent.
- org_id: multi-tenant isolation. Every repository list() MUST filter by org_id.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from sqlalchemy import DateTime, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


# Valid status values — single source of truth for state machine validation.
VIEWING_STATUS_VALUES = ("requested", "confirmed", "completed", "cancelled")


class JpViewing(Base):
    """JP viewing appointment request.

    requested_slots is a JSON array of ISO 8601 datetime strings.
    Slot validation (count ≤3, business hours, lead ≥24h) is enforced by
    app/services/jp/viewing/scheduler.py, not at DB level.

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(JpViewing.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_viewings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Multi-tenant broker org isolation
    org_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    # Listing reference (no FK to keep JP domain isolated from core)
    listing_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Listing UUID",
    )

    # Tenant who made the request
    tenant_id: Mapped[int] = mapped_column(
        Integer, nullable=False, index=True,
        comment="User ID of the tenant requesting the viewing",
    )

    # Agent assigned to confirm — nullable until sales assignment is resolved
    agent_id: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True, index=True,
        comment="User ID of the sales agent. Nullable until assigned.",
    )

    # Preferred viewing slots — JSON array of ISO 8601 strings
    # Service layer enforces: max 3 slots, 10-19 JST business hours, lead ≥24h
    requested_slots: Mapped[Any] = mapped_column(
        JSON, nullable=False,
        comment="JSON array of ISO timestamp strings. Max 3 entries. Business hours only.",
    )

    # The confirmed slot chosen by the agent
    confirmed_slot_ts: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True,
        comment="The confirmed viewing datetime. Must be one of the requested_slots values.",
    )

    # State machine status
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="requested",
        comment="State: requested | confirmed | completed | cancelled",
    )

    # Optional notes
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=_now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
