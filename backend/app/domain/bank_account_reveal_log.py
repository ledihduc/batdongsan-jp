"""SQLAlchemy ORM model for bank account reveal audit log.

New table: bank_account_reveal_logs

AC coverage:
  - AC-53: PDPL audit trail for bank account number reveals
  - Mirrors CCCDAccessLog pattern (app/models.py) for consistent audit trail

Every time an operator views an owner's bank account number (full digits),
one row is written here. The actual reveal is a read-layer concern (phase-07);
this table tracks that a reveal occurred.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


def _new_uuid() -> str:
    return str(uuid.uuid4())


class BankAccountRevealLog(Base):
    """PDPL audit trail for bank account number reveals (AC-53).

    consent_token: one-time owner consent reference (owner explicitly approved reveal).
    ip_address: for anti-fraud auditing (same PDPL PII consideration as CCCDAccessLog).
    """

    __tablename__ = "bank_account_reveal_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_uuid)

    # Account owner
    owner_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    # Who accessed (operator)
    operator_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    # The active delegation that authorized this access
    delegation_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("delegations.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    revealed_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=_now_utc)
    # One-time owner consent reference (64-char token)
    consent_token: Mapped[str] = mapped_column(String(64), nullable=False)
    # IPv6 max 45 chars
    ip_address: Mapped[str] = mapped_column(String(50), nullable=False)

    def __repr__(self) -> str:
        return (
            f"<BankAccountRevealLog id={self.id} owner={self.owner_user_id} "
            f"operator={self.operator_user_id} at={self.revealed_at}>"
        )
