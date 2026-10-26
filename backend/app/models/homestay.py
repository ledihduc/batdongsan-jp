from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

# ── Phase 07: Homestay Core — Availability / PricingRule / Reservation ────────


class Availability(Base):
    """Per-day per-room availability ledger.

    One row per (room_id, date). Status drives calendar render colour:
        - available: bookable
        - blocked:   host manually blocked (maintenance, owner stay, …)
        - reserved:  tied to an active Reservation

    When status='reserved', reservation_id is the owning Reservation. The
    Postgres exclusion constraint on `reservations` is the authoritative
    no-overlap guard; this table is the projection used by calendar UI.
    """
    __tablename__ = "availability"
    __table_args__ = (
        UniqueConstraint("room_id", "date", name="uq_availability_room_date"),
        Index("ix_availability_host_date", "host_id", "date"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="CASCADE"), index=True
    )
    date: Mapped[str] = mapped_column(String(20), index=True)  # ISO YYYY-MM-DD
    status: Mapped[str] = mapped_column(String(20), default="available")
    reservation_id: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True, index=True
    )
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=now_utc, onupdate=now_utc
    )


class PricingRule(Base):
    """Homestay nightly price rule with priority resolution.

    Resolution order at a given date (highest wins):
        manual (priority 1000) > holiday (500) > weekend (200) > base (100)

    A rule applies if start_date ≤ date ≤ end_date AND:
        - room_id matches OR house_id matches (if set), and host_id matches.
    For weekend rules, weekday_mask is a bitmask over Mon-Sun (Mon=bit0, …,
    Sun=bit6). Default for weekend = 0b1100000 (Fri+Sat).
    """
    __tablename__ = "pricing_rules"
    __table_args__ = (
        Index("ix_pricing_rules_host_room", "host_id", "room_id"),
        Index("ix_pricing_rules_dates", "start_date", "end_date"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    room_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="CASCADE"), nullable=True
    )
    house_id: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True
    )
    # Type: base | weekend | holiday | manual
    rule_type: Mapped[str] = mapped_column(String(20))
    start_date: Mapped[str] = mapped_column(String(20))  # ISO date
    end_date: Mapped[str] = mapped_column(String(20))
    price_per_night: Mapped[float] = mapped_column(Float)
    priority: Mapped[int] = mapped_column(Integer, default=100)
    weekday_mask: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    holiday_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=now_utc, onupdate=now_utc
    )


class Reservation(Base):
    """Homestay reservation (per-night booking, distinct from nhà trọ Contract).

    Status lifecycle:
        pending → approved → checked_in → checked_out
                     ↓
                 rejected | cancelled | no_show

    Concurrent-booking safety:
        - Phase 01 (Postgres) will add EXCLUDE USING gist on
          (room_id, daterange(check_in_date, check_out_date, '[)'))
          WHERE status IN ('pending','approved','checked_in').
        - Until then, reservation_service.create_reservation() enforces an
          app-level overlap check inside a single transaction. Not
          race-condition-proof but acceptable for current single-host scale.

    cancel_policy_snapshot stores the policy JSON at creation time so future
    policy changes do not retroactively alter refund maths.
    """
    __tablename__ = "reservations"
    __table_args__ = (
        Index("ix_reservations_host_status", "host_id", "status"),
        Index("ix_reservations_room_dates", "room_id", "check_in_date", "check_out_date"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="RESTRICT"), index=True
    )
    guest_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    guest_name: Mapped[str] = mapped_column(String(300))
    guest_phone: Mapped[str] = mapped_column(String(50), default="")
    guest_email: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    check_in_date: Mapped[str] = mapped_column(String(20))   # ISO YYYY-MM-DD inclusive
    check_out_date: Mapped[str] = mapped_column(String(20))  # exclusive
    # NULL mode is the original nightly product; never infer rates from base_price.
    booking_mode: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    check_in_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    check_out_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    booking_code: Mapped[Optional[str]] = mapped_column(String(32), nullable=True, unique=True)
    price_snapshot: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    nights: Mapped[int] = mapped_column(Integer)
    total_amount: Mapped[float] = mapped_column(Float)
    deposit_paid: Mapped[float] = mapped_column(Float, default=0)
    # Activity v2 policy snapshot.  ``deposit_paid`` remains money actually
    # received; these three nullable fields describe the requirement that was
    # quoted for a newly created reservation.
    activity_deposit_policy_version: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    activity_primary_deposit_bps: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    activity_primary_deposit_amount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    # Status: pending | approved | rejected | checked_in | checked_out | cancelled | no_show
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    cancel_policy_snapshot: Mapped[str] = mapped_column(
        Text, default='{"version":"v1","rigid_24h":true}'
    )
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    refund_amount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rejection_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    # Source: marketplace | direct | manual
    # Dual-write window: keep String column until Phase 3.5 drop (revision 0017).
    source: Mapped[str] = mapped_column(String(20), default="manual")
    # Phase 04 analytics — FK to revenue_sources. NOT NULL enforced by 0018
    # after service layer dual-writes on every INSERT path.
    source_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("revenue_sources.id", ondelete="SET NULL"), nullable=False
    )
    # Commission fields: NULL = legacy/no-commission booking (AC-04 backward-compat).
    # commission_amount = commission_rate × total_amount (computed, not manual).
    commission_rate: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    commission_amount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # ── Quầy lễ tân (migration 0112) ─────────────────────────────────────────
    #: Ghi chú kiểm phòng lúc trả: "ga dính vết mực", "thiếu 1 khăn".
    ghi_chu_kiem_phong: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # ── Đặt qua sale (migration 0113) ────────────────────────────────────────
    #: Sale dẫn khách về — ẢNH CHỤP lúc đặt, không đổi theo người phụ trách sau.
    #: Rỗng với đơn cũ và ca vãng lai chủ nhà tự ghi tại quầy.
    sale_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    #: Tin đăng khách đã bấm vào để đặt (rỗng nếu đặt từ trang toà của sale).
    house_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("houses.id", ondelete="SET NULL"), nullable=True
    )
    #: Số người ở (mig 0116). Rỗng với đơn cũ và ca vãng lai tại quầy.
    so_khach: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=now_utc, onupdate=now_utc
    )

    # ORM relationship — back_populates on RevenueSource.reservations
    revenue_source: Mapped[Optional["RevenueSource"]] = relationship(
        "RevenueSource", back_populates="reservations", lazy="select"
    )


class ReservationPhuThu(Base):
    """Món LÀM TĂNG số phải thu của một ca thuê (migration 0112).

    Minibar, dịch vụ phòng, phụ thu quá giờ, bồi thường hỏng mất. Giữ đơn giá ×
    số lượng chứ không chỉ một cục tiền: phiếu in ra cho khách phải đọc hiểu
    "2 chai nước × 10.000đ", không phải "phụ thu 20.000đ".
    """

    __tablename__ = "reservation_phu_thu"

    #: Loại món — để báo cáo tách được doanh thu phòng và doanh thu dịch vụ.
    MINIBAR = "minibar"
    DICH_VU = "dich_vu"
    QUA_GIO = "qua_gio"
    BOI_THUONG = "boi_thuong"
    KHAC = "khac"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    reservation_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("reservations.id", ondelete="CASCADE"), index=True
    )
    loai: Mapped[str] = mapped_column(String(20), default=DICH_VU, server_default="dich_vu")
    ten: Mapped[str] = mapped_column(String(200))
    don_gia: Mapped[float] = mapped_column(Float, default=0, server_default="0")
    so_luong: Mapped[float] = mapped_column(Float, default=1, server_default="1")
    thanh_tien: Mapped[float] = mapped_column(Float, default=0, server_default="0")
    ghi_chu: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    nguoi_ghi: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class ReservationThanhToan(Base):
    """Lần TIỀN ĐỔI TAY của một ca thuê (migration 0112).

    `thu` = nhận của khách, `hoan` = trả lại khách. Tách khỏi phụ thu vì đó là
    hai khái niệm khác nhau: phụ thu làm tăng số PHẢI thu, còn đây là số ĐÃ thu.
    Trộn vào một bảng thì mọi phép cộng phải nhớ dấu, và sẽ có người quên.

    Cọc vẫn nằm ở `reservations.deposit_paid` (dữ liệu cũ) — công thức "đã thu"
    cộng cả hai nguồn ở MỘT chỗ: `services/ca_thue_service.py`.
    """

    __tablename__ = "reservation_thanh_toan"

    THU = "thu"
    HOAN = "hoan"
    TIEN_MAT = "tien_mat"
    CHUYEN_KHOAN = "chuyen_khoan"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    reservation_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("reservations.id", ondelete="CASCADE"), index=True
    )
    loai: Mapped[str] = mapped_column(String(10), default=THU, server_default="thu")
    so_tien: Mapped[float] = mapped_column(Float, default=0, server_default="0")
    hinh_thuc: Mapped[str] = mapped_column(
        String(20), default=TIEN_MAT, server_default="tien_mat"
    )
    ghi_chu: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    nguoi_ghi: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
