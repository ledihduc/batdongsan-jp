from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True)
    type: Mapped[str] = mapped_column(String(50), default="")
    title: Mapped[str] = mapped_column(String(200), default="")
    body: Mapped[str] = mapped_column(Text, default="")
    related_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)

    # ── Phase delegation (migration 0035) — multi-channel notifications ───────
    # Delivery channel: in_app | push | email | sms | zalo (zalo = v1.1 placeholder)
    channel: Mapped[str] = mapped_column(String(20), nullable=False, default="in_app")
    # Delivery status lifecycle: queued | sent | delivered | failed | bounced
    delivery_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="queued"
    )
    # Vendor message ID (SES message id, eSMS ref) for read-receipt tracking (NFR-14)
    external_message_id: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    # NFR-14: high-value approval early-SMS trigger (set when opened)
    read_receipt_opened_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


class UserPushToken(Base):
    __tablename__ = "user_push_tokens"
    __table_args__ = (
        UniqueConstraint("user_id", "device_id", name="uq_user_push_token_device"),
        Index("ix_user_push_tokens_user_id", "user_id"),
        Index("ix_user_push_tokens_token", "token"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, nullable=False)
    device_id: Mapped[str] = mapped_column(String(120), nullable=False)
    token: Mapped[str] = mapped_column(String(500), nullable=False)
    platform: Mapped[str] = mapped_column(String(20), nullable=False, default="unknown")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    sender_id: Mapped[int] = mapped_column(Integer, index=True)
    receiver_id: Mapped[int] = mapped_column(Integer, index=True)
    house_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True, index=True)
    body: Mapped[str] = mapped_column(Text)
    read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)




class PushOutbox(Base):
    """Hàng đợi gửi FCM — ghi CÙNG transaction với dữ liệu nghiệp vụ (mig 0101).

    Gọi FCM thẳng trong hàm xử lý hỏng theo hai chiều: FCM lỗi thì kéo đổ giao
    dịch (bán một căn hộ thất bại vì Google trả 503 là vô lý), và gọi trước khi
    commit thì có thể báo "đã bán" rồi giao dịch rollback — người dùng nhận tin
    về một việc chưa từng xảy ra.

    Ở đây ý định gửi và dữ liệu nghiệp vụ cùng sống hoặc cùng chết. Tiến trình
    khác đọc hàng đợi và gửi.
    """

    __tablename__ = "push_outbox"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text)
    loai: Mapped[str] = mapped_column(String(50))
    related_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    #: "loại sự kiện + đối tượng" (vd `tin_da_dong:phong-13`). Một người bị
    #: đóng ba tin cùng lúc chỉ nhận MỘT push.
    khoa_gom: Mapped[str] = mapped_column(String(100))
    tao_luc: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    #: None = còn chờ gửi.
    gui_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    so_lan_thu: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    loi_cuoi: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
