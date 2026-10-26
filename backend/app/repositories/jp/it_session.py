"""Repository for JpItSession.

Multi-tenant isolation: every list query MUST filter by org_id.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.it_session import JpItSession


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpItSessionRepository:
    """Org-scoped CRUD for jp_it_sessions."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id_org(
        self, session_id: int, org_id: str
    ) -> Optional[JpItSession]:
        return (
            self.db.query(JpItSession)
            .filter(
                JpItSession.id == session_id,
                JpItSession.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def list_by_viewing(
        self, viewing_id: int, org_id: str
    ) -> list[JpItSession]:
        return (
            self.db.query(JpItSession)
            .filter(
                JpItSession.viewing_id == viewing_id,
                JpItSession.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .all()
        )

    def create(
        self,
        org_id: str,
        viewing_id: int,
        takken_shi_id: int,
        scheduled_at: datetime,
        zoom_meeting_id: Optional[str] = None,
        zoom_join_url: Optional[str] = None,
    ) -> JpItSession:
        row = JpItSession(
            org_id=org_id,
            viewing_id=viewing_id,
            takken_shi_id=takken_shi_id,
            scheduled_at=scheduled_at,
            zoom_meeting_id=zoom_meeting_id,
            zoom_join_url=zoom_join_url,
            status="scheduled",
        )
        self.db.add(row)
        self.db.flush()
        return row

    def record_tenant_consent(
        self, session: JpItSession
    ) -> JpItSession:
        """Record that tenant gave IT重説 consent."""
        session.tenant_consent_at = _now_utc()
        self.db.flush()
        return session

    def update_status(
        self, session: JpItSession, status: str
    ) -> JpItSession:
        session.status = status
        self.db.flush()
        return session
