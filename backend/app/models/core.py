from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    # `''` = KHÔNG CÓ. Đăng nhập được bằng email HOẶC số điện thoại (mig 0097)
    # nên mỗi vế đều có thể trống — miễn là có ít nhất một.
    #
    # Tính duy nhất KHÔNG khai ở đây mà bằng UNIQUE MỘT PHẦN trong migration
    # (`WHERE <> ''`). Khai `unique=True` thì SQLite trong test dựng UNIQUE
    # thường, và người thứ hai không có email sẽ bị chặn — đúng lỗi đã gặp với
    # `houses.source_room_id`.
    email: Mapped[str] = mapped_column(String(200), index=True)
    password_hash: Mapped[str] = mapped_column(String(200))
    #: Dạng chuẩn `0xxxxxxxxx`. Mọi đường ghi đi qua `services/dinh_danh.py`.
    phone: Mapped[str] = mapped_column(String(50), default="", index=True)
    avatar_path: Mapped[str] = mapped_column(String(500), default="")
    role: Mapped[str] = mapped_column(String(20), default="guest")
    # Vai trò NGHIỆP VỤ, tách khỏi `role` (vốn là quyền JWT: guest/host/admin).
    # `role` gộp lẫn chủ phòng thật với người chỉ đăng tin bán, nên không dùng
    # được để phân biệt sale với chủ phòng. Giá trị: customer|sale|owner|admin.
    account_type: Mapped[str] = mapped_column(
        String(20), default="customer", server_default="customer",
        nullable=False, index=True,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    # Mốc đổi mật khẩu gần nhất (migration 0066). Token có `iat` TRƯỚC mốc này
    # bị từ chối -> đổi mật khẩu đuổi được mọi phiên cũ mà không cần blacklist.
    # NULL = chưa từng đổi (mọi token đều hợp lệ).
    password_changed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True
    )

    birthday: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    id_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # ── Phase delegation (migration 0027) ────────────────────────────────────
    # role = primary login persona {'guest','host','admin','operator'};
    # is_operator_capable = can accept delegation invites (may be True for host who
    # also operates for other owners — AC-56). Both flags orthogonal.
    is_operator_capable: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # AC-64: sole ownership self-declaration; user-level (applies to all properties)
    sole_ownership_attested_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True
    )
    # 1:1 backref to OperatorBusinessProfile (NULL for cá nhân operators).
    # FK constraint exists in DB (migration 0027) but NOT declared here in ORM to avoid
    # table resolution error when app/domain models are not yet imported.
    # The FK is enforced at migration level (Postgres-only per 0027 upgrade()).
    business_operator_profile_id: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True
    )


class Category(Base):
    """Loại hình BĐS. `group_key` gom vào 3 NHÓM master (migration 0074):
    stay_long (lưu trú dài hạn) · stay_short (lưu trú ngắn hạn) · business
    (kinh doanh). Nhóm quyết định MÀU PIN trên bản đồ và bước 1 của form đăng
    tin. Màu không nằm ở đây — xem design token phía app."""

    __tablename__ = "categories"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    icon: Mapped[str] = mapped_column(String(50), default="")
    group_key: Mapped[str] = mapped_column(String(16), default="", index=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    # Loại đã bỏ (Penthouse/Studio gộp vào Căn hộ) → ẩn khỏi mọi chỗ CHỌN danh
    # mục, nhưng vẫn tra được tên cho dữ liệu lịch sử.
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Amenity(Base):
    __tablename__ = "amenities"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    icon: Mapped[str] = mapped_column(String(50), default="")


