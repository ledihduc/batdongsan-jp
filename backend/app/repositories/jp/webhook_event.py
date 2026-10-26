"""Repository for JpWebhookEvent — webhook audit log with idempotency support.

Idempotency: external_event_id has DB UNIQUE constraint.
Use try_insert_idempotent() for safe insert-or-skip.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any, Optional

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.domain.jp.webhook_event import JpWebhookEvent

logger = logging.getLogger(__name__)


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpWebhookEventRepository:
    """CRUD + idempotency helpers for jp_webhook_events."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_external_id(
        self, external_event_id: str
    ) -> Optional[JpWebhookEvent]:
        return (
            self.db.query(JpWebhookEvent)
            .filter(JpWebhookEvent.external_event_id == external_event_id)
            .first()
        )

    def try_insert_idempotent(
        self,
        provider: str,
        event_type: str,
        external_event_id: str,
        payload: dict[str, Any],
    ) -> tuple[JpWebhookEvent, bool]:
        """Insert webhook event row; return (row, is_new).

        is_new=False means event was already seen → caller should skip processing.
        Uses savepoint for nested transaction safety on Postgres.
        """
        # Fast-path: check existence before attempting insert
        existing = self.get_by_external_id(external_event_id)
        if existing:
            logger.info(
                "Webhook duplicate detected: provider=%s event_id=%s",
                provider, external_event_id,
            )
            return existing, False

        row = JpWebhookEvent(
            provider=provider,
            event_type=event_type,
            external_event_id=external_event_id,
            idempotency_key=f"{provider}:{external_event_id}",
            payload=payload,
            received_at=_now_utc(),
        )
        try:
            self.db.add(row)
            self.db.flush()
            return row, True
        except IntegrityError:
            self.db.rollback()
            logger.info(
                "Webhook race-condition duplicate: provider=%s event_id=%s",
                provider, external_event_id,
            )
            existing = self.get_by_external_id(external_event_id)
            return existing, False  # type: ignore[return-value]

    def mark_processed(self, row: JpWebhookEvent) -> None:
        """Set processed_at to now."""
        row.processed_at = _now_utc()
        self.db.flush()
