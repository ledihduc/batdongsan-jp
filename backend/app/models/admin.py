"""Backoffice quản trị (Admin V2) — phân quyền, phiên, nhật ký, case, sự kiện.

Vì sao là trục RIÊNG chứ không dùng `users.role`:
  - `users.role` (guest/host/admin) là quyền JWT của app; `account_type` và
    workspace customer/sale/owner là vai NGHIỆP VỤ. Nhân viên quản trị cần
    quyền nhỏ theo hành động (moderator không được đụng tiền), nên phải có
    bảng phân quyền riêng, đọc từ DB ở MỌI request nhạy cảm.
  - `users.role == 'admin'` được giữ làm "quản trị viên kiểu cũ" ⇔ SUPER_ADMIN
    (migration 0137 cấp sẵn), để màn Admin Flutter vẫn chạy như lối tắt khẩn.

Danh mục quyền/vai là CODE (`app/services/admin_v2/permissions.py`), bảng chỉ là
bản đồng bộ để truy vấn/kiểm toán; `ensure_catalog()` bổ sung khi khởi động.
"""

from app.models._shared import *  # noqa: F401,F403
from sqlalchemy import text


class AdminRole(Base):
    __tablename__ = "admin_roles"

    code: Mapped[str] = mapped_column(String(40), primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class AdminPermission(Base):
    __tablename__ = "admin_permissions"

    code: Mapped[str] = mapped_column(String(80), primary_key=True)
    module: Mapped[str] = mapped_column(String(40), index=True)
    description: Mapped[str] = mapped_column(Text, default="")


class AdminRolePermission(Base):
    __tablename__ = "admin_role_permissions"

    role_code: Mapped[str] = mapped_column(
        String(40), ForeignKey("admin_roles.code", ondelete="CASCADE"), primary_key=True
    )
    permission_code: Mapped[str] = mapped_column(
        String(80), ForeignKey("admin_permissions.code", ondelete="CASCADE"), primary_key=True
    )


class AdminUserRole(Base):
    """Một lần cấp vai cho một nhân viên. Thu hồi = điền `revoked_at`, không xoá
    (lịch sử ai từng có quyền gì là dữ liệu kiểm toán)."""

    __tablename__ = "admin_user_roles"
    __table_args__ = (
        Index(
            "uq_admin_user_roles_active",
            "user_id", "role_code",
            unique=True,
            postgresql_where=text("revoked_at IS NULL"),
            sqlite_where=text("revoked_at IS NULL"),
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    role_code: Mapped[str] = mapped_column(
        String(40), ForeignKey("admin_roles.code", ondelete="RESTRICT"), index=True
    )
    granted_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    granted_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    grant_reason: Mapped[str] = mapped_column(String(500), default="")
    revoked_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    revoked_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    revoke_reason: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)


class AdminSession(Base):
    """Phiên đăng nhập backoffice. Token admin mang `sid`; thu hồi phiên là chặn
    ngay ở request kế tiếp (khác JWT app thường sống 7 ngày không thu hồi được)."""

    __tablename__ = "admin_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    expires_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    #: Lần gần nhất nhập lại mật khẩu — thao tác cực nhạy cần mốc này còn mới.
    reauth_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    revoked_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    revoked_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    revoke_reason: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    ip_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)


class AdminActionLog(Base):
    """Nhật ký thao tác backoffice — APPEND-ONLY.

    Ghi trong CÙNG transaction với thao tác (rollback thì nhật ký cũng mất —
    không có dòng "đã làm" cho việc chưa làm). Trên Postgres có trigger chặn
    UPDATE/DELETE. `response` giữ kết quả để trả lại khi client gửi lại cùng
    `Idempotency-Key` (retry không tạo thao tác trùng).
    """

    __tablename__ = "admin_action_logs"
    __table_args__ = (
        UniqueConstraint(
            "actor_user_id", "action", "idempotency_key",
            name="uq_admin_action_logs_actor_action_key",
        ),
        Index("ix_admin_action_logs_entity", "entity_type", "entity_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    request_id: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    actor_user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    admin_session_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    action: Mapped[str] = mapped_column(String(80), index=True)
    permission: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    entity_type: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    entity_id: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    before_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    after_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    response_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    idempotency_key: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    result: Mapped[str] = mapped_column(String(20), default="success")
    ip_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)


class AdminCase(Base):
    """Lớp ĐIỀU PHỐI của đội vận hành trên một đối tượng nghiệp vụ.

    KHÔNG thay trạng thái nghiệp vụ (tin vẫn `pending_review`, cọc vẫn
    `PENDING`): chỉ giữ ai phụ trách, ưu tiên, hạn SLA, ghi chú nội bộ.
    """

    __tablename__ = "admin_cases"
    __table_args__ = (
        UniqueConstraint("source_type", "source_id", name="uq_admin_cases_source"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    source_type: Mapped[str] = mapped_column(String(40), index=True)
    source_id: Mapped[str] = mapped_column(String(64))
    assignee_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # low | normal | high | urgent
    priority: Mapped[str] = mapped_column(String(10), default="normal")
    sla_due_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # open | in_progress | waiting | done
    status: Mapped[str] = mapped_column(String(20), default="open", index=True)
    internal_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    #: Chỉ dùng cho việc TẠO TAY (`source_type='manual'`) — việc từ hàng đợi lấy
    #: tiêu đề từ bản ghi nguồn.
    title: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    done_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    legal_hold: Mapped[bool] = mapped_column(Boolean, default=False)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)


class AdminCaseEvent(Base):
    __tablename__ = "admin_case_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    case_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("admin_cases.id", ondelete="CASCADE"), index=True
    )
    actor_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    kind: Mapped[str] = mapped_column(String(40))  # assign | note | priority | status
    payload: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class AdminChangeRequest(Base):
    """Maker-checker: người đề xuất ≠ người duyệt. Dùng cho cấp SUPER_ADMIN,
    hoàn tiền vượt ngưỡng… Thao tác chỉ chạy khi một người KHÁC phê duyệt."""

    __tablename__ = "admin_change_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    kind: Mapped[str] = mapped_column(String(40), index=True)
    payload: Mapped[dict] = mapped_column(JSON)
    reason: Mapped[str] = mapped_column(Text)
    # PENDING | APPROVED | REJECTED | CANCELLED
    status: Mapped[str] = mapped_column(String(20), default="PENDING", index=True)
    requested_by: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    requested_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    decided_by: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    decided_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    decision_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    result_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)


class AdminEvent(Base):
    """Outbox sự kiện realtime cho backoffice.

    Ghi cùng transaction với thao tác → chỉ "tồn tại" sau commit. Luồng SSE đọc
    bảng theo `id > cursor`, nên chạy nhiều worker/container vẫn đúng và mất
    kết nối thì nối lại từ cursor. Payload CHỈ có id/loại/trạng thái — không PII.
    """

    __tablename__ = "admin_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    event_type: Mapped[str] = mapped_column(String(60), index=True)
    entity_type: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    entity_id: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    status: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)


class PrivateDocument(Base):
    """Chứng từ RIÊNG TƯ (hợp đồng, ảnh cọc, CCCD, giấy phép…).

    Chỉ lưu `object_key` trong kho riêng (không mount tĩnh). Xem qua signed URL
    sống ngắn, mỗi lần cấp/mở đều ghi nhật ký. `legacy_upload_name` dùng khi
    chứng từ cũ nằm ở `/uploads` được chuyển vào kho riêng — cổng tĩnh sẽ chặn
    đúng tên đó khi bật PRIVATE_UPLOADS_ENFORCED.
    """

    __tablename__ = "private_documents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    object_key: Mapped[str] = mapped_column(String(200), unique=True)
    owner_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # contract | deposit_proof | kyc | death_certificate | business_license | payment_proof | other
    category: Mapped[str] = mapped_column(String(40), index=True)
    source_type: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    source_id: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    content_type: Mapped[str] = mapped_column(String(80), default="application/octet-stream")
    size_bytes: Mapped[int] = mapped_column(Integer, default=0)
    sha256: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    legacy_upload_name: Mapped[Optional[str]] = mapped_column(
        String(200), nullable=True, unique=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
