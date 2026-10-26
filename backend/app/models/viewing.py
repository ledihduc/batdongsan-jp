"""Canonical viewing v2 entities; legacy appointment columns remain intact."""

from app.models._shared import *  # noqa: F401,F403


class ViewingProposal(Base):
    __tablename__ = "viewing_proposals"
    __table_args__ = (
        UniqueConstraint(
            "appointment_id",
            "booking_date",
            "booking_time",
            name="uq_viewing_proposal_slot",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    appointment_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("viewing_appointments.id", ondelete="CASCADE"), index=True
    )
    proposed_by_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT")
    )
    proposed_by_role: Mapped[str] = mapped_column(String(20))
    booking_date: Mapped[str] = mapped_column(String(20))
    booking_time: Mapped[str] = mapped_column(String(50))
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="PENDING", index=True)
    accepted_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class ViewingResult(Base):
    __tablename__ = "viewing_results"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    appointment_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("viewing_appointments.id", ondelete="RESTRICT"),
        unique=True,
        index=True,
    )
    status: Mapped[str] = mapped_column(String(24), index=True)
    reason_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    reason_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    submitted_by_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT")
    )
    submitted_by_role: Mapped[str] = mapped_column(String(20))
    submitted_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)


class ViewingIssue(Base):
    __tablename__ = "viewing_issues"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    appointment_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("viewing_appointments.id", ondelete="CASCADE"), index=True
    )
    reporter_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT")
    )
    reporter_role: Mapped[str] = mapped_column(String(20))
    issue_code: Mapped[str] = mapped_column(String(50))
    detail: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    evidence_urls: Mapped[list] = mapped_column(JSONList, default=list)
    status: Mapped[str] = mapped_column(String(20), default="OPEN", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class ViewingEvent(Base):
    __tablename__ = "viewing_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    appointment_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("viewing_appointments.id", ondelete="CASCADE"), index=True
    )
    actor_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    actor_role: Mapped[str] = mapped_column(String(20))
    event_type: Mapped[str] = mapped_column(String(50))
    from_status: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    to_status: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    payload: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)
