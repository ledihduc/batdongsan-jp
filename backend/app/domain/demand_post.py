"""Tin NHU CẦU — "Cần thuê" / "Cần mua".

Vì sao là BẢNG RIÊNG chứ không phải một `transaction_type` nữa của `houses`:

  * `houses` bắt buộc `address`, `area`, `price`, `category_id` — người ĐANG TÌM
    nhà không có địa chỉ, không có diện tích, không có ảnh. Nhét vào đó thì hoặc
    phải nới ràng buộc của tin thật (mở cửa cho tin rác), hoặc bắt người dùng
    bịa số.
  * Tin nhu cầu mà nằm trong `houses` sẽ tự động lọt vào bản đồ, sitemap/SEO,
    và bộ đếm "tin đang đăng" trên hồ sơ người bán — sai ở cả bốn chỗ.
  * Vòng đời khác hẳn: tin rao tồn tại đến khi bán/cho thuê xong, còn nhu cầu
    NGUỘI theo thời gian. Ở đây nhu cầu tự hết hạn sau 30 ngày (`expires_at`),
    có thể gia hạn. Không có cơ chế này thì sau nửa năm danh sách toàn nhu cầu
    chết — đúng thứ đã giết các trang "cần mua cần bán" đời cũ.

Khu vực lưu dạng mã + danh sách phường (JSON) chứ không phải toạ độ: người tìm
nhà nghĩ theo "quận 7, Bình Thạnh", không nghĩ theo một điểm trên bản đồ.

SĐT KHÔNG lưu ở đây. Liên hệ đi qua chat trong app. Đăng nhu cầu kèm số điện
thoại công khai là mồi cho môi giới gọi rác, và người dùng sẽ không đăng lần
thứ hai.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from sqlalchemy import Date, DateTime, Float, ForeignKey, Index, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


class DemandPost(Base):
    """Một tin nhu cầu do người dùng đăng."""

    __tablename__ = "demand_posts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # Bắt buộc đăng nhập: nhu cầu phải liên hệ lại được, và ẩn danh thì không
    # chặn được spam.
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )

    # 'rent' = cần thuê · 'buy' = cần mua.
    kind: Mapped[str] = mapped_column(String(10), index=True)

    # Khu vực mong muốn. `ward_slugs` là JSON list — người tìm nhà thường nhắm
    # vài phường/quận cùng lúc, ép chọn một là làm sai nhu cầu thật.
    province_code: Mapped[Optional[str]] = mapped_column(String(32), nullable=True, index=True)
    province_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    ward_slugs: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    area_label: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)

    # Loại hình mong muốn — id trong bảng `categories` (12 loại đang bật).
    category_ids: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    # Ngân sách (đ). Thuê = mỗi tháng, mua = tổng.
    budget_min: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    budget_max: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    area_min: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    bedrooms_min: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Riêng CẦN THUÊ.
    move_in_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    duration_months: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    occupants: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Riêng CẦN MUA. 'cash' | 'loan' · 'live' | 'invest'.
    payment_method: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    purpose: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    legal_ok: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    # Yêu cầu bắt buộc dạng chip (chỗ để xe, giờ tự do, thú cưng…).
    needs: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # 'open' | 'closed' (người đăng tự đóng khi tìm được).
    status: Mapped[str] = mapped_column(String(20), default="open", index=True)
    # Hết hạn tính KHI ĐỌC (`expires_at > now`), không cần cron dọn.
    expires_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now_utc, index=True)


# Truy vấn chính của màn danh sách: lọc theo loại + khu vực, còn hạn, mới nhất.
Index(
    "ix_demand_posts_feed",
    DemandPost.kind,
    DemandPost.province_code,
    DemandPost.status,
    DemandPost.expires_at,
)
