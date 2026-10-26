"""Repository for JpUserConsent — APPI consent records.

Append-only design: consent rows are never deleted.
To revoke: update revoked_at on the row.
To re-grant after revocation: insert a new row.

Multi-tenant isolation: filtered by user_id (no org_id on consent — user-scoped).
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.user_consent import JpUserConsent


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpUserConsentRepository:
    """CRUD for jp_user_consents."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_active(
        self, user_id: int, purpose: str
    ) -> Optional[JpUserConsent]:
        """Get the current active (not revoked) consent for user+purpose."""
        return (
            self.db.query(JpUserConsent)
            .filter(
                JpUserConsent.user_id == user_id,
                JpUserConsent.purpose == purpose,
                JpUserConsent.revoked_at.is_(None),
            )
            .order_by(JpUserConsent.granted_at.desc())
            .first()
        )

    def list_active_for_user(self, user_id: int) -> list[JpUserConsent]:
        """All active (not revoked) consents for a user."""
        return (
            self.db.query(JpUserConsent)
            .filter(
                JpUserConsent.user_id == user_id,
                JpUserConsent.revoked_at.is_(None),
            )
            .all()
        )

    def list_all_for_user(self, user_id: int) -> list[JpUserConsent]:
        """Full history (including revoked) for DSR export."""
        return (
            self.db.query(JpUserConsent)
            .filter(JpUserConsent.user_id == user_id)
            .order_by(JpUserConsent.granted_at.asc())
            .all()
        )

    def grant(
        self,
        user_id: int,
        purpose: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        consent_version: str = "1.0",
    ) -> JpUserConsent:
        """Insert a new consent grant row.

        Does NOT check for existing active consent — caller must decide
        whether to revoke first or allow duplicate (re-grant).
        """
        row = JpUserConsent(
            user_id=user_id,
            purpose=purpose,
            consent_version=consent_version,
            granted_at=_now_utc(),
            ip_address=ip_address,
            user_agent=user_agent,
        )
        self.db.add(row)
        self.db.flush()
        return row

    def revoke(
        self, user_id: int, purpose: str
    ) -> Optional[JpUserConsent]:
        """Set revoked_at on the current active consent.

        Returns the updated row, or None if no active consent found.
        """
        row = self.get_active(user_id, purpose)
        if row is None:
            return None
        row.revoked_at = _now_utc()
        self.db.flush()
        return row
