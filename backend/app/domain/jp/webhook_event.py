"""SQLAlchemy 2.0 model for JpWebhookEvent — audit log of incoming JP provider webhooks.

Table: jp_webhook_events

Idempotency guarantee: external_event_id has a UNIQUE constraint.
Handlers MUST check this table before acting on any event.
Protocol:
  1. HMAC verification at route level (reject immediately if invalid).
  2. Insert row with processed_at=None — if IntegrityError, already processed → 200.
  3. Dispatch to internal handler.
  4. Update processed_at on success.

Design decisions:
- Managed by migration 0152_jp_webhook_events.
- Payload stored as JSONB for full audit/replay capability.
- No org_id — webhook events are identified by provider_intent_id correlation.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from sqlalchemy import DateTime, Integer, JSON, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpWebhookEvent(Base):
    """Audit log entry for one incoming JP provider webhook.

    Uniqueness: external_event_id UNIQUE prevents double-processing.
    Handlers: check this table first — if row exists and processed_at is set,
    return 200 immediately (idempotent).

    Insert flow (route handler):
      try:
          db.add(JpWebhookEvent(external_event_id=..., ...))
          db.commit()
      except IntegrityError:
          db.rollback()
          return {"status": "already_processed"}  # 200
    """

    __tablename__ = "jp_webhook_events"

    __table_args__ = (
        UniqueConstraint(
            "external_event_id",
            name="uq_jp_webhook_events_external_event_id",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    provider: Mapped[str] = mapped_column(
        String(32), nullable=False,
        comment="Source provider (komoju | cloudsign | zoom).",
    )
    event_type: Mapped[str] = mapped_column(
        String(100), nullable=False,
        comment="Provider event type string (e.g. 'payment.succeeded').",
    )

    # Idempotency key — provider-assigned event ID (UNIQUE enforced in DB)
    external_event_id: Mapped[str] = mapped_column(
        String(256), nullable=False,
        comment="Provider-assigned event ID. UNIQUE constraint enforces idempotency.",
    )
    idempotency_key: Mapped[Optional[str]] = mapped_column(
        String(256), nullable=True,
        comment="Computed key (provider:event_id). Alias for clarity.",
    )

    # Full payload stored for replay
    payload: Mapped[Any] = mapped_column(
        JSON, nullable=False,
        comment="Raw webhook payload. Stored for audit and replay.",
    )

    received_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
        comment="When we received the webhook.",
    )
    processed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True,
        comment="When we finished processing. Null = pending/in-flight.",
    )
