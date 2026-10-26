"""Cụm DỊCH VỤ — danh mục nghề và yêu cầu khách gửi.

Tách hẳn khỏi cụm thi công (`construction_*`). Trước đây tính năng này mượn
bảng của mảng nhà thầu; khi mảng đó bị gỡ khỏi sản phẩm thì một tính năng đang
sống không thể tiếp tục treo lên cụm sắp bị xoá.

Mô hình cố ý ĐƠN GIẢN, đúng với cách vận hành thật: khách chọn nghề → để lại
tên + số điện thoại + mô tả → admin nhận thông báo, gọi lại, tự xếp thợ. Không
có sàn thầu, không đấu giá, không báo giá — những thứ đó là thứ vừa được gỡ.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    Integer,
    JSON,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


class Service(Base):
    """Một nghề trong danh mục dịch vụ (Sửa điện, Thông tắc, Vệ sinh nhà…)."""

    __tablename__ = "services"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    slug: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    # Tên Material Icon phía app (chuỗi, không phải codepoint — Flutter web
    # tree-shake icon nên tra động bằng codepoint sẽ ra ô vuông trống).
    icon: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)


class ServiceRequest(Base):
    """Yêu cầu dịch vụ của khách + phần vận hành của admin.

    Vòng đời: new → contacted → scheduled → done (hoặc cancelled / spam).
    `contacted_at` ghi TỰ ĐỘNG lần đầu admin đổi trạng thái — đây là số đo duy
    nhất nói được dịch vụ có sống hay không (khách gửi 22h mà 9h hôm sau mới
    gọi là mất khách). Bắt admin tự bấm thì sẽ không ai bấm.
    """

    __tablename__ = "service_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # null = khách vãng lai. KHÔNG ép đăng nhập: người đang cần thợ gấp mà bắt
    # tạo tài khoản là mất khách ngay tại đó.
    user_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    service_slug: Mapped[str] = mapped_column(String(40), index=True)

    name: Mapped[str] = mapped_column(String(200))
    phone: Mapped[str] = mapped_column(String(50), index=True)
    area: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    budget: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    images: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    province_code: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    location_text: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    status: Mapped[str] = mapped_column(String(20), default="new", index=True)
    scheduled_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    contacted_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    admin_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    source: Mapped[str] = mapped_column(String(30), default="app")
    # Id của bản ghi gốc bên `construction_leads` (nếu được chuyển sang) — giữ
    # để việc sao dữ liệu chạy lại được mà không nhân đôi.
    legacy_lead_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=_now_utc, index=True
    )
