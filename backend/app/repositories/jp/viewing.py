"""Repository for jp_viewings — org-scoped CRUD with state machine helpers.

Multi-tenant isolation: every list query MUST filter by org_id.
State transitions are NOT validated here — that's the service layer's job.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.domain.jp.viewing import JpViewing, VIEWING_STATUS_VALUES


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpViewingRepository:
    """Org-scoped CRUD for jp_viewings."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id(self, viewing_id: int) -> Optional[JpViewing]:
        """Fetch single record by PK. Returns None if not found."""
        return self.db.query(JpViewing).filter(JpViewing.id == viewing_id).first()

    def get_by_id_org(self, viewing_id: int, org_id: str) -> Optional[JpViewing]:
        """Fetch single record — org-scoped.

        # MULTI-TENANT ISOLATION: org_id filter enforced here.
        """
        return (
            self.db.query(JpViewing)
            .filter(
                JpViewing.id == viewing_id,
                JpViewing.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def list_by_org(
        self,
        org_id: str,
        *,
        status: Optional[str] = None,
        tenant_id: Optional[int] = None,
        agent_id: Optional[int] = None,
        listing_id: Optional[str] = None,
    ) -> list[JpViewing]:
        """List viewings for an org, with optional filters.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        q = (
            self.db.query(JpViewing)
            .filter(JpViewing.org_id == org_id)  # MULTI-TENANT ISOLATION
        )
        if status:
            q = q.filter(JpViewing.status == status)
        if tenant_id is not None:
            q = q.filter(JpViewing.tenant_id == tenant_id)
        if agent_id is not None:
            q = q.filter(JpViewing.agent_id == agent_id)
        if listing_id:
            q = q.filter(JpViewing.listing_id == listing_id)
        return q.order_by(JpViewing.created_at.desc()).all()

    def list_by_tenant_org(self, tenant_id: int, org_id: str) -> list[JpViewing]:
        """List viewings for a specific tenant within an org.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        return (
            self.db.query(JpViewing)
            .filter(
                JpViewing.tenant_id == tenant_id,
                JpViewing.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .order_by(JpViewing.created_at.desc())
            .all()
        )

    def create(
        self,
        *,
        org_id: Optional[str],
        listing_id: str,
        tenant_id: int,
        agent_id: Optional[int] = None,
        requested_slots: list[str],
        notes: Optional[str] = None,
    ) -> JpViewing:
        """Create and flush a new viewing request."""
        now = _now_utc()
        viewing = JpViewing(
            org_id=org_id,
            region="jp",
            listing_id=listing_id,
            tenant_id=tenant_id,
            agent_id=agent_id,
            requested_slots=requested_slots,
            status="requested",
            notes=notes,
            created_at=now,
            updated_at=now,
        )
        self.db.add(viewing)
        self.db.flush()
        return viewing

    def update_status(
        self,
        viewing: JpViewing,
        *,
        status: str,
        confirmed_slot_ts: Optional[datetime] = None,
        agent_id: Optional[int] = None,
    ) -> JpViewing:
        """Update viewing status (state machine transition — validation done by service).

        Only updates fields relevant to the given transition.
        """
        viewing.status = status
        if confirmed_slot_ts is not None:
            viewing.confirmed_slot_ts = confirmed_slot_ts
        if agent_id is not None:
            viewing.agent_id = agent_id
        viewing.updated_at = _now_utc()
        self.db.flush()
        return viewing

    def update(self, viewing: JpViewing, **fields: object) -> JpViewing:
        """Apply general field updates and flush."""
        allowed = {"notes", "agent_id", "requested_slots"}
        for key, value in fields.items():
            if key in allowed:
                setattr(viewing, key, value)
        viewing.updated_at = _now_utc()
        self.db.flush()
        return viewing
