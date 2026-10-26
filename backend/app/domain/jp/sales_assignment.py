"""SQLAlchemy 2.0 model for sales agent listing assignments.

Table: listing_sales_assignments

Used by require_role_scope to determine if a sales agent (仲介) is authorized
to access a specific listing. Sales role is scoped to 'assigned' listings only.

Design decisions:
- Managed by migration 0148_listing_sales_assignments (additive, nullable, idempotent).
- listing_id stored as string (no FK) to avoid cross-module dep on core listing.
- org_id: multi-tenant isolation. Every repository query MUST filter by org_id.
- Soft delete via is_active rather than hard delete for audit trail.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


class ListingSalesAssignment(Base):
    """Sales agent (仲介) assignment to a specific listing.

    A listing may have multiple sales agents assigned.
    is_active=False represents a soft-deleted/revoked assignment.

    Org scoping:
        Every repository query on this model MUST include:
            .filter(ListingSalesAssignment.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "listing_sales_assignments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Listing reference (no FK to avoid cross-schema dep on core listing table)
    listing_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Listing UUID. No FK to keep JP domain isolated from core.",
    )

    # Sales agent user ID
    sales_user_id: Mapped[int] = mapped_column(
        Integer, nullable=False, index=True,
        comment="User ID of the assigned sales agent (仲介担当)",
    )

    # Multi-tenant broker org isolation
    org_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    # Soft delete — is_active=False means assignment revoked
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True,
        comment="False = assignment revoked (soft delete for audit trail)",
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=_now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
