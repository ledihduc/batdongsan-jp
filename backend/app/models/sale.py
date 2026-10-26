"""Hồ sơ SALE và liên kết SALE ↔ CHỦ PHÒNG (spec mục 3).

Vì sao là bảng riêng chứ không nhét vào `users`:
  - Không phải ai cũng là sale. Nhồi 8 cột rỗng vào `users` cho 2.263 tài khoản
    để phục vụ vài chục sale là sai chỗ.
  - `sale_code` phải UNIQUE và tra cứu thường xuyên — cần chỉ mục riêng.

Quan hệ: mỗi toà có tối đa một sale đang hoạt động; một chủ có nhiều toà với
các sale khác nhau. Chỉ mục duy nhất một phần trên `building_id` với
`status='active'` — không thể ép bằng UNIQUE thường vì liên kết cũ (`ended`)
vẫn phải nằm lại để tra lịch sử.
"""

from app.models._shared import *  # noqa: F401,F403
from sqlalchemy import text


class SaleProfile(Base):
    """Hồ sơ công khai của sale. Trang `/sale/:id` lấy dữ liệu từ đây."""

    __tablename__ = "sale_profiles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        index=True,
    )
    # Mã liên kết CỐ ĐỊNH, dạng "SL-8K4D2Q". Sale đọc cho chủ phòng nghe nên
    # bảng chữ bỏ 0/O/1/I/L. Đổi được — mã cũ hết hiệu lực, liên kết cũ giữ
    # nguyên (spec mục 2).
    sale_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    display_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    avatar_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    cover_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    # Khu vực phục vụ, ví dụ ["Thủ Đức", "Quận 7"].
    service_areas: Mapped[list] = mapped_column(JSONList, default=list)
    verified: Mapped[bool] = mapped_column(Boolean, default=False)
    trusted: Mapped[bool] = mapped_column(Boolean, default=False)
    #: % giá thuê tháng đầu mà sale được hưởng khi chốt (mig 0132). Mỗi chủ
    #: nhà một mức, nên đây là mặc định của sale chứ không phải luật sàn.
    hoa_hong_phan_tram: Mapped[int] = mapped_column(
        Integer, default=50, server_default="50", nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=now_utc, onupdate=now_utc
    )


class SaleApplication(Base):
    """Hồ sơ xin trở thành Sale; chỉ Admin mới được cấp quyền Sale.

    User luôn đăng ký Customer trước. Bảng này lưu bộ hồ sơ tách biệt để việc
    nộp đơn, yêu cầu bổ sung, duyệt/từ chối đều có trạng thái và audit; không
    dùng một nút đổi ``users.account_type`` ở client.
    """

    __tablename__ = "sale_applications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    applicant_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    # Snapshot liên hệ tại lúc nộp để Admin đối chiếu; hồ sơ gốc User vẫn là
    # nguồn đăng nhập/PII hiện hành.
    full_name: Mapped[str] = mapped_column(String(200))
    email: Mapped[str] = mapped_column(String(200), default="")
    phone: Mapped[str] = mapped_column(String(50), default="")
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    service_areas: Mapped[list] = mapped_column(JSONList, default=list)
    evidence_urls: Mapped[list] = mapped_column(JSONList, default=list)
    # SUBMITTED | IN_REVIEW | REQUEST_CHANGES | APPROVED | REJECTED | WITHDRAWN
    status: Mapped[str] = mapped_column(String(32), default="SUBMITTED", index=True)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    submitted_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    reviewed_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    review_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    rejection_code: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    withdrawn_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    approved_sale_profile_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("sale_profiles.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=now_utc, onupdate=now_utc
    )


class ActivityPolicyVersion(Base):
    """Admin policy version for deposits; old transactions keep their snapshot."""

    __tablename__ = "activity_policy_versions"
    __table_args__ = (
        UniqueConstraint("policy_version", name="uq_activity_policy_version"),
        CheckConstraint(
            "short_stay_primary_deposit_bps >= 0 AND short_stay_primary_deposit_bps <= 10000",
            name="ck_activity_policy_short_deposit_bps",
        ),
        CheckConstraint(
            "long_term_platform_deposit_bps >= 0 AND long_term_platform_deposit_bps <= 10000",
            name="ck_activity_policy_long_deposit_bps",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    policy_version: Mapped[int] = mapped_column(Integer, nullable=False)
    # Basis points avoid float arithmetic: 10% = 1000, 50% = 5000.
    short_stay_primary_deposit_bps: Mapped[int] = mapped_column(
        Integer, default=1000, nullable=False
    )
    long_term_platform_deposit_bps: Mapped[int] = mapped_column(
        Integer, default=5000, nullable=False
    )
    effective_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    reason: Mapped[str] = mapped_column(String(500), nullable=False)
    created_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class ActivityAuditEvent(Base):
    """Append-only audit envelope for new Activity v2 commands."""

    __tablename__ = "activity_audit_events"
    __table_args__ = (
        UniqueConstraint(
            "actor_user_id", "action", "idempotency_key",
            name="uq_activity_audit_actor_action_key",
        ),
        Index("ix_activity_audit_target_created", "target_type", "target_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    actor_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    action: Mapped[str] = mapped_column(String(80), index=True)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    target_type: Mapped[str] = mapped_column(String(80), nullable=False)
    target_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    payload: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class SaleApplicationWebSession(Base):
    """Short-lived bridge from mobile Customer authentication to the web form.

    Database rows only contain SHA-256 digests. The raw ticket is carried in a
    URL fragment; the resulting web secret belongs in an HttpOnly web cookie.
    """

    __tablename__ = "sale_application_web_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    ticket_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True, index=True)
    web_session_hash: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, unique=True, index=True
    )
    ticket_expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    web_session_expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, index=True
    )
    exchanged_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class SaleOwnerLink(Base):
    """Liên kết sale ↔ chủ phòng. Nguồn sự thật cho MỌI kiểm tra quyền.

    `status`:
      - `pending`  — chủ phòng đã nhập mã, chờ xác nhận (dự phòng cho luồng
                     cần duyệt hai chiều; hiện tại tạo thẳng `active`).
      - `active`   — đang hiệu lực.
      - `transfer_pending` — đang chuyển sang sale khác.
      - `ended`    — đã ngắt; giữ lại để tra lịch sử.
    """

    __tablename__ = "sale_owner_links"
    __table_args__ = (
        Index(
            "uq_sale_owner_links_building_active",
            "building_id",
            unique=True,
            postgresql_where=text("status = 'active'"),
            sqlite_where=text("status = 'active'"),
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    sale_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    owner_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    # NULL chỉ dành cho dữ liệu cũ chưa xác định được toà; không cấp quyền.
    building_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("buildings.id", ondelete="CASCADE"),
        nullable=True, index=True,
    )
    status: Mapped[str] = mapped_column(String(20), default="active", index=True)
    linked_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    ended_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # Ai bấm nút: thường là chủ phòng (họ nhập mã), nhưng chuyển giao thì là
    # sale hoặc admin. Cần cho nhật ký.
    created_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    end_reason: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)


class Deal(Base):
    """Giao dịch đã chốt qua sale (migration 0086).

    Luồng ba bên, cố ý KHÔNG cho sale khởi tạo:
        khách bấm chốt → `pending`
        chủ phòng xác nhận → `confirmed`  ← chỉ trạng thái này mới được đếm
        chủ phòng từ chối → `rejected`

    `sale_id` do backend suy từ `rooms.managed_by_sale_id`; app gửi lên cái gì
    cũng bị bỏ qua.
    """

    __tablename__ = "deals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True
    )
    house_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("houses.id", ondelete="SET NULL"), nullable=True
    )
    owner_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    sale_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    customer_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    deal_type: Mapped[str] = mapped_column(String(10))  # rent | sale
    amount: Mapped[int] = mapped_column(BigInteger, default=0)
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    note: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    confirmed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    confirmed_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reject_reason: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    # P07 CRM projection. `status` remains the transaction authority; Sale may
    # move only this operational pipeline and can never confirm rental here.
    pipeline_stage: Mapped[Optional[str]] = mapped_column(
        String(32), nullable=True, index=True
    )
    loss_reason_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    lost_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


class RentalJourney(Base):
    """Auditable post-view workflow shared by customer, sale, and owner."""

    __tablename__ = "rental_journeys"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    appointment_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("viewing_appointments.id", ondelete="RESTRICT"),
        unique=True,
        index=True,
    )
    room_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True, index=True
    )
    house_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("houses.id", ondelete="SET NULL"), nullable=True, index=True
    )
    customer_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    sale_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    owner_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    status: Mapped[str] = mapped_column(String(40), index=True)
    total_deposit: Mapped[int] = mapped_column(
        BigInteger, default=0, server_default="0", nullable=False
    )
    # Snapshot at journey creation.  NULL identifies a pre-Activity-v2 record
    # and keeps its established 50/50 calculation instead of backfilling a
    # later Admin policy over historical cọc.
    deposit_policy_version: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    platform_deposit_bps: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    contract_urls: Mapped[list] = mapped_column(JSONList, default=list)
    contract_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    contract_submitted_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    contract_submitted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True
    )
    #: Hợp đồng sinh ra khi chốt thuê (mig 0131). Không có cột này thì từ hồ
    #: sơ thuê không lần ra được hợp đồng nào vừa ký cho phòng nào — app phải
    #: đoán bằng room_id + ngày, và đoán sai khi phòng từng cho thuê nhiều lần.
    contract_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="SET NULL"), nullable=True
    )
    cancel_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=now_utc, onupdate=now_utc
    )


class RentalJourneyPayment(Base):
    __tablename__ = "rental_journey_payments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    journey_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("rental_journeys.id", ondelete="CASCADE"),
        index=True,
    )
    kind: Mapped[str] = mapped_column(String(20))  # APP_DEPOSIT | OWNER_DEPOSIT
    amount: Mapped[int] = mapped_column(BigInteger, default=0, server_default="0")
    status: Mapped[str] = mapped_column(String(20), default="PENDING", index=True)
    proof_urls: Mapped[list] = mapped_column(JSONList, default=list)
    submitted_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    submitted_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    acknowledged_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    acknowledged_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=now_utc, onupdate=now_utc
    )
    __table_args__ = (
        UniqueConstraint("journey_id", "kind", name="uq_rental_journey_payment_kind"),
    )


class RentalJourneyReport(Base):
    __tablename__ = "rental_journey_reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    journey_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("rental_journeys.id", ondelete="CASCADE"),
        index=True,
    )
    reporter_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    reported_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    reason_code: Mapped[str] = mapped_column(String(50), index=True)
    detail: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    evidence_urls: Mapped[list] = mapped_column(JSONList, default=list)
    status: Mapped[str] = mapped_column(
        String(20), default="PENDING", server_default="PENDING", index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    __table_args__ = (
        UniqueConstraint(
            "journey_id",
            "reporter_id",
            "reason_code",
            name="uq_rental_journey_report_reason",
        ),
    )


class RentalJourneyEvent(Base):
    __tablename__ = "rental_journey_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    journey_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("rental_journeys.id", ondelete="CASCADE"),
        index=True,
    )
    actor_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    actor_role: Mapped[str] = mapped_column(String(20))
    event_type: Mapped[str] = mapped_column(String(50), index=True)
    from_status: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    to_status: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    payload: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)
