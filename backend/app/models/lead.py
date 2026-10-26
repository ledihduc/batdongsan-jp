"""Lead 'gọi lại' NHẸ (redesign v2 — thu lead không cần login).

Khách để lại Tên + SĐT tại "khoảnh khắc giá trị" (lưu tin, đặt lịch xem, quan
tâm làm đơn vị…) mà KHÔNG buộc đăng nhập. TÁCH khỏi `ConstructionLead` (RFQ báo
giá) một cách CÓ CHỦ ĐÍCH: lead ở đây KHÔNG lọt vào pool đơn vị báo giá — chỉ để
admin gọi lại / remarketing. Bản đồ bảng: docs/model_tables.txt.
"""

from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types


class ContactLead(Base):
    __tablename__ = "contact_leads"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # null = khách chưa đăng nhập (đa số ca thu lead).
    user_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True, index=True)
    name: Mapped[str] = mapped_column(String(200))
    phone: Mapped[str] = mapped_column(String(50), index=True)
    # Khoảnh khắc tạo lead: save_home, booking_consult, contact_host,
    # provider_interest, … — để admin biết ngữ cảnh mà tư vấn đúng.
    source: Mapped[str] = mapped_column(String(50), index=True)
    context: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    world: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    province_code: Mapped[Optional[str]] = mapped_column(String(32), nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(20), default="new", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)
