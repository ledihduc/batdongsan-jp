"""P10 RoomType-first inventory, additive beside legacy Room reservations."""
from app.models._shared import *  # noqa: F401,F403


class ShortStayRatePlan(Base):
    __tablename__ = "short_stay_rate_plans"
    __table_args__ = (UniqueConstraint("room_type_id", "code", name="uq_short_rate_plan_code"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_type_id: Mapped[int] = mapped_column(Integer, ForeignKey("loai_phong.id", ondelete="CASCADE"), nullable=False, index=True)
    code: Mapped[str] = mapped_column(String(40), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    nightly_price: Mapped[float] = mapped_column(Float, nullable=False)
    min_nights: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    cancellation_policy: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)


class RoomTypeInventory(Base):
    __tablename__ = "room_type_inventory"
    __table_args__ = (UniqueConstraint("room_type_id", "date", name="uq_room_type_inventory_date"), CheckConstraint("capacity >= 0 AND reserved >= 0 AND reserved <= capacity", name="ck_room_type_inventory_bounds"))
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_type_id: Mapped[int] = mapped_column(Integer, ForeignKey("loai_phong.id", ondelete="CASCADE"), nullable=False, index=True)
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    reserved: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)


class RoomTypeBookingRequest(Base):
    __tablename__ = "room_type_booking_requests"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_type_id: Mapped[int] = mapped_column(Integer, ForeignKey("loai_phong.id", ondelete="RESTRICT"), nullable=False, index=True)
    rate_plan_id: Mapped[int] = mapped_column(Integer, ForeignKey("short_stay_rate_plans.id", ondelete="RESTRICT"), nullable=False)
    guest_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    sale_user_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    check_in_date: Mapped[date] = mapped_column(Date, nullable=False)
    check_out_date: Mapped[date] = mapped_column(Date, nullable=False)
    guest_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="REQUESTED", nullable=False, index=True)
    quote_snapshot: Mapped[dict] = mapped_column(JSON, nullable=False)
    cancellation_policy_snapshot: Mapped[dict] = mapped_column(JSON, nullable=False)
    assigned_room_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True)
    reservation_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("reservations.id", ondelete="SET NULL"), nullable=True)
    workflow_data: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    cancellation_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)


class ShortStayWorkflowEvent(Base):
    __tablename__ = "short_stay_workflow_events"
    __table_args__ = (Index("ix_short_workflow_request_created", "request_id", "created_at"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    request_id: Mapped[int] = mapped_column(Integer, ForeignKey("room_type_booking_requests.id", ondelete="CASCADE"), nullable=False, index=True)
    actor_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    actor_role: Mapped[str] = mapped_column(String(20), nullable=False)
    event_type: Mapped[str] = mapped_column(String(40), nullable=False)
    from_status: Mapped[str] = mapped_column(String(30), nullable=False)
    to_status: Mapped[str] = mapped_column(String(30), nullable=False)
    payload: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)
