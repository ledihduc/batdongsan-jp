"""SQLAlchemy ORM model for owner death certificate processing.

New table: owner_death_certificates

AC coverage:
  - AC-58: admin verification of death certificate (24h SLA)
  - AC-58b: heir/executor onboarding
  - AC-58d: executor can approve delegation_approvals
  - US-A6/A7: admin panel for death cert review
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


def _new_uuid() -> str:
    return str(uuid.uuid4())


class OwnerDeathCertificate(Base):
    """Death certificate submission + admin verification record.

    UUID PK for consistency with delegation domain (non-guessable).
    UNIQUE owner_user_id: one active death cert per owner.
    Document paths stored on encrypted-at-rest volume (mediated by sensitive_file_service).
    Admin 24h SLA: verified_at should be set within 24h of created_at (US-A7).
    """

    __tablename__ = "owner_death_certificates"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)
    # UNIQUE: one record per deceased owner (prevents duplicate submissions)
    owner_user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        unique=True,
        index=True,
    )

    # Document paths — encrypted-at-rest volume, mediated by sensitive_file_service
    death_certificate_path: Mapped[str] = mapped_column(String(500), nullable=False)
    # Heir's notarized POA (optional at submission, may be uploaded later)
    notarized_poa_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Who submitted (heir or admin-on-behalf)
    submitted_by_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    # Admin verification: pending | verified | rejected
    verification_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending", index=True
    )
    verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    verified_by_admin_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    # Executor (heir who takes over delegation approval rights — AC-58b/d)
    executor_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    executor_onboarded_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now_utc)

    def __repr__(self) -> str:
        return (
            f"<OwnerDeathCertificate id={self.id} owner={self.owner_user_id} "
            f"status={self.verification_status}>"
        )
