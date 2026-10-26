"""P08 active-stay collaboration records.

Contract, Invoice and MeterReading remain the financial/operational sources of
truth.  These tables only model collaboration which did not previously have a
durable home: support and requested contract changes.
"""

from app.models._shared import *  # noqa: F401,F403


class StaySupportCase(Base):
    __tablename__ = "stay_support_cases"
    __table_args__ = (
        Index("ix_stay_support_contract_status", "contract_id", "status"),
        Index("ix_stay_support_assignee_status", "assignee_user_id", "status"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    contract_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    opened_by_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    opened_by_role: Mapped[str] = mapped_column(String(20), nullable=False)
    assignee_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    category: Mapped[str] = mapped_column(String(40), nullable=False)
    priority: Mapped[str] = mapped_column(String(16), default="NORMAL", nullable=False)
    status: Mapped[str] = mapped_column(String(24), default="OPEN", nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    evidence_urls: Mapped[list] = mapped_column(JSONList, default=list)
    sla_due_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    resolved_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)


class StaySupportEvent(Base):
    __tablename__ = "stay_support_events"
    __table_args__ = (Index("ix_stay_support_event_case_created", "case_id", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    case_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("stay_support_cases.id", ondelete="CASCADE"), nullable=False, index=True
    )
    actor_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    actor_role: Mapped[str] = mapped_column(String(20), nullable=False)
    event_type: Mapped[str] = mapped_column(String(40), nullable=False)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    evidence_urls: Mapped[list] = mapped_column(JSONList, default=list)
    payload: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)


class StayChangeRequest(Base):
    __tablename__ = "stay_change_requests"
    __table_args__ = (
        Index("ix_stay_change_contract_status", "contract_id", "status"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    contract_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    requester_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    requester_role: Mapped[str] = mapped_column(String(20), nullable=False)
    request_type: Mapped[str] = mapped_column(String(20), nullable=False)  # RENEWAL | MOVE_OUT
    proposed_end_date: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="PENDING", nullable=False, index=True)
    reviewed_by_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    review_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)
