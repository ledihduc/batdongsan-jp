"""SQLAlchemy ORM model for tenant-reported unauthorized operator flags.

New table: tenant_authority_flags

AC coverage:
  - AC-63: tenant can report unauthorized operator activity
  - Admin 48h SLA to review (reviewed_at - created_at <= 48h)
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


def _new_uuid() -> str:
    return str(uuid.uuid4())


class TenantAuthorityFlag(Base):
    """Tenant report of unauthorized operator activity (AC-63).

    Admin 48h SLA: reviewed_at - created_at <= 48h.
    delegation_id nullable: set if system can correlate to a delegation.
    """

    __tablename__ = "tenant_authority_flags"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)

    # Reporting tenant
    tenant_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    # Reported operator user
    reported_operator_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    # Correlated delegation (if system can identify it)
    delegation_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("delegations.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    report_reason: Mapped[str] = mapped_column(Text, nullable=False)

    # Admin review: pending | valid | invalid
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending", index=True
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    reviewed_by_admin_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now_utc)

    def __repr__(self) -> str:
        return (
            f"<TenantAuthorityFlag id={self.id} tenant={self.tenant_id} "
            f"operator={self.reported_operator_user_id} status={self.status}>"
        )
