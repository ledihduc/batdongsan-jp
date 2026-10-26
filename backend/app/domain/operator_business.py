"""SQLAlchemy ORM models for operator doanh-nghiệp (business operator) KYC.

New table: operator_business_profiles

AC coverage:
  - AC-49/50b: GPKD verification status
  - AC-65: legal representative change audit
  - AS-06: 1 pháp nhân = 1 user (UNIQUE user_id)

CCCD hash pattern mirrors existing HostProfile (one-way bcrypt, compare-only).
GPKD/CCCD document paths stored as file-system paths on encrypted volume;
mediated by sensitive_file_service.py.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


class OperatorBusinessProfile(Base):
    """Business operator KYC profile.

    1:1 with User (user_id UNIQUE — enforces AS-06: 1 pháp nhân = 1 user).
    GPKD = Giấy phép kinh doanh (business registration certificate).
    Legal representative CCCD stored as bcrypt hash (compare-only).
    """

    __tablename__ = "operator_business_profiles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # 1:1 with legal-rep user (AS-06)
    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        unique=True,
        index=True,
    )

    # Business identity
    business_name: Mapped[str] = mapped_column(String(300), nullable=False)
    business_registration_number: Mapped[str] = mapped_column(String(50), nullable=False)

    # GPKD document (encrypted-at-rest path)
    gpkd_document_path: Mapped[str] = mapped_column(String(500), nullable=False)
    # JSON array of ngành codes (validate at admin review — Q6.3)
    gpkd_industry_codes_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    gpkd_issued_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    # Drives AC-50/AC-61 expiry cron
    gpkd_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Legal representative identity
    legal_representative_name: Mapped[str] = mapped_column(String(300), nullable=False)
    # Bcrypt hash — mirrors existing CCCD pattern in HostProfile (compare-only)
    legal_representative_cccd_number_hash: Mapped[Optional[str]] = mapped_column(
        String(200), nullable=True
    )
    # Encrypted-at-rest file paths
    legal_representative_cccd_front_path: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True
    )
    legal_representative_cccd_back_path: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True
    )
    #: Ảnh chân dung người đại diện chụp lúc eKYC chủ nhà (mig 0140).
    legal_representative_selfie_path: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True
    )
    legal_representative_phone: Mapped[str] = mapped_column(String(50), nullable=False)

    # Verification state machine: pending | verified | rejected | revoked
    verification_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending", index=True
    )
    verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # Admin who verified (nullable — pending state)
    verified_by_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    # AC-65: legal rep change audit (most-recent predecessor)
    previous_legal_rep_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    legal_rep_changed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=_now_utc, onupdate=_now_utc
    )

    def __repr__(self) -> str:
        return (
            f"<OperatorBusinessProfile id={self.id} user={self.user_id} "
            f"business='{self.business_name}' status={self.verification_status}>"
        )
