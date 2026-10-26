"""Repository for listing_sales_assignments — JP sales agent listing access control.

Used by require_role_scope to check if a sales agent (仲介) is assigned to a listing.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.sales_assignment import ListingSalesAssignment


def _now_utc() -> datetime:
    return datetime.utcnow()


class ListingSalesAssignmentRepository:
    """Org-scoped CRUD for listing_sales_assignments.

    Multi-tenant isolation: every list query MUST filter by org_id.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def is_assigned(self, listing_id: str, sales_user_id: int, org_id: str) -> bool:
        """Return True if the sales agent has an active assignment to this listing.

        This is the primary access-control check for the 'sales' role scope.
        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        return (
            self.db.query(ListingSalesAssignment)
            .filter(
                ListingSalesAssignment.listing_id == listing_id,
                ListingSalesAssignment.sales_user_id == sales_user_id,
                ListingSalesAssignment.org_id == org_id,  # MULTI-TENANT ISOLATION
                ListingSalesAssignment.is_active.is_(True),
            )
            .first()
        ) is not None

    def list_by_listing_org(self, listing_id: str, org_id: str) -> list[ListingSalesAssignment]:
        """List all active assignments for a listing within an org.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        return (
            self.db.query(ListingSalesAssignment)
            .filter(
                ListingSalesAssignment.listing_id == listing_id,
                ListingSalesAssignment.org_id == org_id,  # MULTI-TENANT ISOLATION
                ListingSalesAssignment.is_active.is_(True),
            )
            .all()
        )

    def list_by_sales_user_org(self, sales_user_id: int, org_id: str) -> list[str]:
        """Return listing_ids assigned to this sales agent within an org.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        rows = (
            self.db.query(ListingSalesAssignment.listing_id)
            .filter(
                ListingSalesAssignment.sales_user_id == sales_user_id,
                ListingSalesAssignment.org_id == org_id,  # MULTI-TENANT ISOLATION
                ListingSalesAssignment.is_active.is_(True),
            )
            .all()
        )
        return [r.listing_id for r in rows]

    def create(
        self,
        *,
        listing_id: str,
        sales_user_id: int,
        org_id: Optional[str],
    ) -> ListingSalesAssignment:
        """Create and flush a new active assignment."""
        now = _now_utc()
        assignment = ListingSalesAssignment(
            listing_id=listing_id,
            sales_user_id=sales_user_id,
            org_id=org_id,
            region="jp",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        self.db.add(assignment)
        self.db.flush()
        return assignment

    def deactivate(self, assignment: ListingSalesAssignment) -> ListingSalesAssignment:
        """Soft-delete: set is_active=False to revoke the assignment."""
        assignment.is_active = False
        assignment.updated_at = _now_utc()
        self.db.flush()
        return assignment
