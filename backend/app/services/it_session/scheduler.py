"""IT重説 session scheduler service.

Responsibilities:
  create_session() — create a JpItSession row and request a Zoom meeting.
  capture_tenant_consent() — record tenant consent timestamp before session entry.
"""

from __future__ import annotations

import logging
from datetime import datetime

from sqlalchemy.orm import Session

from app.domain.jp.it_session import JpItSession
from app.repositories.jp.it_session import JpItSessionRepository
from app.services.it_session.zoom_adapter import get_zoom_adapter

logger = logging.getLogger(__name__)


async def create_session(
    org_id: str,
    viewing_id: int,
    takken_shi_id: int,
    scheduled_at: datetime,
    db: Session,
) -> JpItSession:
    """Create an IT重説 session and request a Zoom meeting.

    Args:
        org_id: Broker org ID.
        viewing_id: Parent JpViewing.id.
        takken_shi_id: User ID of the 宅建士.
        scheduled_at: Session start time (UTC).
        db: SQLAlchemy session.

    Returns:
        Newly created JpItSession with zoom_meeting_id and zoom_join_url populated.
    """
    repo = JpItSessionRepository(db)

    # Request Zoom meeting
    zoom = get_zoom_adapter()
    topic = f"IT重説 — viewing_id={viewing_id}"
    try:
        meeting = await zoom.create_meeting(
            topic=topic,
            scheduled_at=scheduled_at,
        )
    except Exception as exc:
        logger.error(
            "Zoom meeting creation failed for viewing=%d: %s", viewing_id, exc
        )
        raise RuntimeError(f"Failed to create Zoom meeting: {exc}") from exc

    # Persist session row
    session = repo.create(
        org_id=org_id,
        viewing_id=viewing_id,
        takken_shi_id=takken_shi_id,
        scheduled_at=scheduled_at,
        zoom_meeting_id=meeting.meeting_id,
        zoom_join_url=meeting.join_url,
    )
    logger.info(
        "IT重説 session created: id=%d viewing=%d zoom_id=%s",
        session.id, viewing_id, meeting.meeting_id,
    )
    return session


async def capture_tenant_consent(
    session_id: int,
    org_id: str,
    db: Session,
) -> JpItSession:
    """Record tenant's explicit consent to enter the IT重説 session.

    Consent must be recorded before the tenant is given the join URL.
    This satisfies the 宅地建物取引業法 35条 consent requirement.

    Args:
        session_id: JpItSession.id
        org_id: Broker org ID (for isolation).
        db: SQLAlchemy session.

    Returns:
        Updated JpItSession with tenant_consent_at set.

    Raises:
        ValueError: if session not found or consent already given.
    """
    repo = JpItSessionRepository(db)
    session = repo.get_by_id_org(session_id, org_id)
    if session is None:
        raise ValueError(f"IT session {session_id} not found")

    if session.tenant_consent_at is not None:
        logger.info(
            "Tenant consent already recorded for session=%d at %s",
            session_id, session.tenant_consent_at,
        )
        return session

    if session.status == "cancelled":
        raise ValueError(f"Cannot consent to a cancelled session (id={session_id})")

    session = repo.record_tenant_consent(session)
    logger.info("Tenant consent captured for IT session=%d", session_id)
    return session
