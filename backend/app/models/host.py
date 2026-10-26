from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

# ── Phase 02: Host onboarding + audit trail ────────────────────────────────────


class HostProfile(Base):
    """1-1 with User (user_id unique). Stores KYC info, CCCD refs, bank details."""
    __tablename__ = "host_profiles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # FK to users — deliberately no ORM relationship to avoid circular imports in repos
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True
    )
    verified: Mapped[bool] = mapped_column(Boolean, default=False)
    # Ảnh bìa storefront chủ nhà (migration 0063) — chỉ host mới có (gate cấu trúc,
    # tránh vanity-creep cho member thường).
    cover_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    # CCCD file paths — stored server-side only; never returned in API responses directly
    cccd_front_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    cccd_back_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    # CCCD number stored as one-way bcrypt hash — compare-only, no plaintext
    cccd_number_hash: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    bank_account_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    bank_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    bank_account_holder: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    tax_id: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    avg_response_hours: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rating: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    # Số review (migration 0060) — badge "chủ nhà tin cậy" cần ngưỡng ≥5.
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    # Cỡ mẫu ĐÃ KIỂM (migration 0087). `review_count` đếm mọi đánh giá kể cả
    # loại không chứng minh được quan hệ; huy hiệu uy tín dùng cột này.
    verified_review_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    # Số lịch hẹn ĐÃ phản hồi — mẫu mà `avg_response_hours` dựa vào. Bằng 0 thì
    # con số giờ phản hồi không có nghĩa, dù cột kia có giá trị.
    response_sample: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    # Liên hệ công khai (migration 0088). Bất biến của repo là SĐT masked; hai
    # cột này là lối MỞ CÓ CHỦ Ý, do chính người bán bật. Mặc định TẮT.
    show_phone: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )
    zalo: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    # Trang Facebook công khai của người bán (migration 0129). Backend chỉ
    # nhận URL thuộc facebook.com/fb.com hoặc username và chuẩn hoá thành URL;
    # không cho trường này trở thành một open redirect tuỳ ý.
    facebook: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    # Sàn/đơn vị đang hợp tác (migration 0089) — TỰ KHAI, chỉ hiển thị.
    agency: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    payout_schedule: Mapped[Optional[str]] = mapped_column(String(20), default="monthly")
    # Phase 04 analytics: monthly revenue target (nullable, Option A per BA §6.1 AC-18)
    monthly_revenue_goal: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)

    # ── Phase delegation (migration 0028) ────────────────────────────────────
    # AC-50: operator individual KYC expiry alerts (30-day window)
    kyc_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # AC-50: re-KYC 30-day grace period (delegation paused → grace window open)
    kyc_grace_period_until: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


# ── Phase 04 analytics: Revenue Sources ───────────────────────────────────────


class RevenueSource(Base):
    """Per-host named revenue channel (e.g. Trực tiếp, Marketplace nội bộ, Khác).

    FK cascade: deleting a host cascades deletes all their sources.
    Soft-delete: set is_archived=True rather than hard-delete (name reuse allowed
    after archive via service-layer partial unique).
    UNIQUE(host_id, name) prevents duplicate channel names per host.
    """
    __tablename__ = "revenue_sources"
    __table_args__ = (
        UniqueConstraint("host_id", "name", name="uq_revenue_sources_host_name"),
        Index("ix_revenue_sources_host_id", "host_id"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    # Hex color displayed in analytics charts, default grey
    color_hex: Mapped[str] = mapped_column(String(7), nullable=False, default="#666666")
    is_archived: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)

    # Relationships — lazy load to avoid N+1; back_populates declared on child side
    reservations: Mapped[list["Reservation"]] = relationship(
        "Reservation", back_populates="revenue_source", lazy="select"
    )
    contracts: Mapped[list["Contract"]] = relationship(
        "Contract", back_populates="revenue_source", lazy="select"
    )


class ChangeLog(Base):
    """Audit trail for all contract/invoice/host_profile mutations (Phase 03+ write here)."""
    __tablename__ = "change_logs"
    __table_args__ = (
        # NFR-03: composite index for on_behalf_of audit range queries
        Index("ix_change_logs_on_behalf_created", "on_behalf_of_user_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    entity_type: Mapped[str] = mapped_column(
        String(50), index=True
    )  # 'contract' | 'invoice' | 'host_profile' | ...
    entity_id: Mapped[int] = mapped_column(Integer, index=True)
    actor_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    action: Mapped[str] = mapped_column(
        String(30)
    )  # 'create' | 'update' | 'status_change' | 'delete'
    before_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    after_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)

    # ── Phase delegation (migration 0032) ────────────────────────────────────
    # AC-23, AC-32: owner id when actor was an operator (dual-identity logging)
    on_behalf_of_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    # Which delegation authorized this action.
    # FK constraint exists in DB (migration 0032 Postgres-only) but NOT declared
    # here to avoid table resolution error when app.domain not imported.
    acted_via_delegation_id: Mapped[Optional[str]] = mapped_column(
        String(36), nullable=True
    )
    # AC-62: client-claim timestamp (NULL for server-side actions — uses created_at)
    acted_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # AC-44 4-tier retention: hot | warm | cold | legal_hold
    retention_tier: Mapped[str] = mapped_column(
        String(10), nullable=False, default="hot"
    )
    # Scope snapshot at action time — so later revocation doesn't break historical queries
    scope_snapshot_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)


class CCCDAccessLog(Base):
    """PDPL compliance audit: every CCCD file read/write is logged."""
    __tablename__ = "cccd_access_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # actor = user who triggered the access (host or admin)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    file_path: Mapped[str] = mapped_column(String(500))
    action: Mapped[str] = mapped_column(String(20))  # 'upload' | 'read' | 'delete'
    accessed_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)
    ip_address: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)



class EkycChuNha(Base):
    """eKYC của CHỦ NHÀ (mig 0140): CCCD hai mặt + ảnh chân dung + GPKD.

    Bản NHÁP của chủ nhà — chụp dần từng ảnh, kể cả trên điện thoại khác qua
    link (`EkycLink`). Bấm "Nộp" mới chép sang `operator_business_profiles`
    (status 'pending') để admin duyệt ở hàng đợi KYC sẵn có; duyệt/từ chối ở
    đó cập nhật ngược lại đây và `host_profiles.verified`.
    Ảnh lưu đường dẫn TƯƠNG ĐỐI trong kho nhạy cảm (`sensitive_file_service`),
    không bao giờ qua `/uploads` công khai.
    """

    __tablename__ = "ekyc_chu_nha"

    NHAP = "nhap"
    CHO_DUYET = "cho_duyet"
    DA_DUYET = "da_duyet"
    TU_CHOI = "tu_choi"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True
    )
    trang_thai: Mapped[str] = mapped_column(String(20), default=NHAP)
    ho_ten: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    #: Băm bcrypt + 4 số cuối để hiển thị — không lưu số CCCD thô.
    so_cccd_hash: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    so_cccd_cuoi: Mapped[Optional[str]] = mapped_column(String(4), nullable=True)
    ten_kinh_doanh: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    so_gpkd: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    cccd_truoc: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    cccd_sau: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    chan_dung: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    gpkd: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    ly_do_tu_choi: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    nop_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    duyet_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)


class EkycLink(Base):
    """Link làm eKYC trên thiết bị khác (mig 0140) — token chỉ lưu dạng băm.

    Mở link là được chụp/nộp hồ sơ eKYC của ĐÚNG người tạo link, KHÔNG đăng nhập
    được gì khác; hết hạn sau 24 giờ.
    """

    __tablename__ = "ekyc_link"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    het_han: Mapped[datetime] = mapped_column(DateTime)
    dung_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
