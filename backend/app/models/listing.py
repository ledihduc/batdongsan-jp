from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

class House(Base):
    __tablename__ = "houses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(Integer, index=True)
    title: Mapped[str] = mapped_column(String(300))
    description: Mapped[str] = mapped_column(Text, default="")
    category_id: Mapped[int] = mapped_column(Integer, index=True)
    price: Mapped[float] = mapped_column(Float)
    area: Mapped[float] = mapped_column(Float, default=0)
    address: Mapped[str] = mapped_column(String(300), default="")
    city: Mapped[str] = mapped_column(String(100), default="")
    district: Mapped[str] = mapped_column(String(100), default="")
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    bedrooms: Mapped[int] = mapped_column(Integer, default=0)
    bathrooms: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(20), default="published", index=True)
    # ── Tin đăng như một bài viết (migration 0090) ───────────────────────────
    # Ghim bằng MỐC THỜI GIAN chứ không phải cờ boolean: nhiều tin ghim thì còn
    # xếp được với nhau, và biết cái nào ghim sau.
    pinned_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # Đếm THẬT, tăng ở GET /api/houses/{id}. Không backfill số ảo.
    view_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    # Cache — tính lại từ social_post_likes / social_comments (target_type='house').
    like_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    comment_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)

    images: Mapped[list] = mapped_column(JSONList, default=list)
    amenities: Mapped[list] = mapped_column(JSONList, default=list)

    listing_type: Mapped[str] = mapped_column(String(20), default="single")
    total_units: Mapped[int] = mapped_column(Integer, default=1)
    available_units: Mapped[int] = mapped_column(Integer, default=1)
    gender_pref: Mapped[str] = mapped_column(String(10), default="any")

    # Phase 08 — Marketplace ↔ Ops integration
    # product_type: 'apartment' (legacy guest-posted) | 'boarding_house' (synced
    # from ops Room) | 'homestay' (synced from ops Room with is_homestay=true).
    product_type: Mapped[str] = mapped_column(
        String(20), default="apartment", index=True
    )
    # Phòng nguồn. KHÔNG còn UNIQUE từ migration 0092: tin đăng là QUẢNG CÁO có
    # vòng đời (đăng → tìm được khách → đóng), hết hạn thuê thì rao lại bằng tin
    # MỚI. Ba lượt khách = ba tin, vẫn một phòng.
    #
    # Điều cần giữ nay do partial unique `uq_tin_dang_rao` lo: một phòng, một
    # kênh, chỉ MỘT tin ĐANG RAO (`status='published'`). Tin cũ đã đóng không
    # tính. Ràng buộc đó chỉ tồn tại ở Postgres nên `host_building.gan-tin` còn
    # kiểm thêm ở tầng ứng dụng để báo lỗi đọc được.
    source_room_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True, index=True
    )
    #: HẠNG PHÒNG của tin NGẮN HẠN (migration 0130).
    #:
    #: Khách sạn/homestay bán HẠNG, không bán số phòng: khách đặt "Deluxe", lễ
    #: tân gán 302 lúc nhận. Neo tin vào một phòng lẻ (`source_room_id`) buộc
    #: mười phòng giống hệt nhau phải đăng mười tin trùng, và "còn trống mấy
    #: phòng" thành câu không ai trả lời được.
    #:
    #: Dài hạn KHÔNG dùng cột này: thuê tháng là thuê ĐÚNG căn đó, khách đi xem
    #: chính căn đó — neo theo phòng mới đúng.
    loai_phong_id: Mapped[Optional[int]] = mapped_column(
        Integer,
        ForeignKey("loai_phong.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    last_synced_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # ── Vòng đời tin (migration 0092) ─────────────────────────────────────────
    #: Mốc đóng tin. None = đang rao.
    #: PIPELINE của tin (mig 0100): 'ngan_han' | 'dai_han' | 'mat_bang' | 'ban'.
    #:
    #: Tường minh, KHÔNG suy từ `product_type`. Bản cũ khớp chuỗi con
    #: ('homestay'/'short' trong `product_type`) — tức nghiệp vụ phụ thuộc vào
    #: việc ai đó đặt tên danh mục thế nào, và mặt bằng thì rơi hết vào
    #: 'dai_han' nên chốt mặt bằng đóng nhầm tin căn hộ cùng phòng.
    kenh: Mapped[str] = mapped_column(
        String(20), default="dai_han", server_default="dai_han", index=True
    )
    ket_thuc_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    #: 'da_cho_thue' | 'da_ban' | 'het_han' | 'chu_go'
    ly_do_ket_thuc: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    # ── Geo-search (migration 0037) ───────────────────────────────────────────
    # province_code = slug tỉnh trong data/vietnam-provinces.json (vd "tp-ho-chi-minh").
    # Chuẩn hoá từ `city` free-text để lọc theo tỉnh/thành ổn định (accent-insensitive).
    province_code: Mapped[Optional[str]] = mapped_column(String(32), nullable=True, index=True)
    district_code: Mapped[Optional[str]] = mapped_column(String(64), nullable=True, index=True)
    # geocode_status: pending | geocoded | failed | manual — phục vụ backfill idempotent.
    geocode_status: Mapped[str] = mapped_column(String(16), default="pending", index=True)
    geocoded_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # Lý do admin từ chối tin (migration 0038) — host xem để sửa.
    rejection_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    # Pháp lý (migration 0040) — chỉ tin mua bán: red_book|pink_book|sale_contract|pending.
    legal_status: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    # Cấu hình khung giờ chủ nhà mở nhận đặt xem (migration 0041). null = mở mặc định
    # (mọi thứ trong tuần, mọi slot). {"version":1,"weekdays":[0..6],"slots":["08:00-09:00",...]}.
    availability_config: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # ── Sao chất lượng (migration 0042) — pivot mảng thuê ─────────────────────
    # quality_criteria: {"pccc":bool,"full_furniture":bool,"kitchen":bool,
    #   "private_bathroom":bool,"air_conditioner":bool}. null = chưa khai.
    quality_criteria: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    # self_star: chủ tự khai (suy từ criteria). verified_star: sau thẩm định.
    quality_self_star: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    quality_verified_star: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    quality_verified_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True
    )

    # ── Listing v2 (migration 0039) ───────────────────────────────────────────
    # transaction_type: 'rent' (cho thuê, default) | 'sale' (mua bán).
    transaction_type: Mapped[str] = mapped_column(String(10), default="rent", index=True)
    # 0075 — TỰ KHAI ai đăng: 'owner' (chủ nhà) | 'broker' (đăng hộ/môi giới) |
    # '' (tin cũ, chưa từng được hỏi). Rỗng thì KHÔNG hiển thị nhãn nào.
    seller_type: Mapped[str] = mapped_column(String(10), default="", index=True)
    # Nhãn căn trong toà ("Căn 1201"). Đặt ở đây chứ không ở quan hệ vì nó là
    # thuộc tính của chính căn đó, còn nghĩa kể cả khi gỡ khỏi album.
    unit_label: Mapped[str] = mapped_column(String(50), default="")
    # is_trusted: admin đánh cờ "Uy tín" — ảnh hưởng hiển thị badge, KHÔNG boost rank v1.
    is_trusted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    trusted_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # trusted_by_admin_id: FK users.id ON DELETE SET NULL (migration-level FK, Postgres only).
    # Khai báo Integer không khai báo ForeignKey ở ORM để tránh phụ thuộc khi SQLite.
    trusted_by_admin_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    # ward_slug: canonical slug phường/xã sau sáp nhập 01/07/2025.
    ward_slug: Mapped[Optional[str]] = mapped_column(String(80), nullable=True, index=True)
    # ward_slug_legacy: slug phường/xã trước sáp nhập (pre-2025).
    ward_slug_legacy: Mapped[Optional[str]] = mapped_column(String(80), nullable=True, index=True)

    # ── Tìm kiếm nâng cao (migration 0071) ────────────────────────────────────
    # direction: hướng nhà (phong thuỷ). Slug: east|west|south|north|
    #   northeast|southeast|northwest|southwest. null = chưa khai (tin cũ).
    direction: Mapped[Optional[str]] = mapped_column(String(12), nullable=True, index=True)
    # rating_avg/count: cache điểm đánh giá (tính từ bảng reviews) để lọc/sort
    #   nhanh — cập nhật khi có review mới; backfill trong migration.
    rating_avg: Mapped[float] = mapped_column(Float, default=0, index=True)
    rating_count: Mapped[int] = mapped_column(Integer, default=0)

    # ── BĐS công nghiệp P3 (migration 0046) ───────────────────────────────────
    # Tin CN dùng chung bảng houses với product_type='industrial'; thuộc tính
    # riêng KCN gom vào 1 cột JSON (theo tiền lệ quality_criteria/availability_config
    # — không làm phình bảng houses với cột thưa). Shape:
    #   {"area_ha": float, "power_mva": float, "fire_safety": bool, "kcn_legal": str}
    # null = tin thường (không phải CN).
    industrial_attrs: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # NOTE: cột PostGIS `geom geometry(Point,4326)` sống ở DB (Postgres), KHÔNG khai
    # báo ở ORM để tránh phụ thuộc geoalchemy2 khi dev chạy SQLite. Đồng bộ từ
    # lat/lng bằng DB trigger (xem migration 0037); truy cập bằng raw SQL.


class ViewingAppointment(Base):
    """Lịch khách đặt để XEM phòng, và (loai='chot') lịch hẹn gặp để CHỐT.

    Neo được vào cả hai đầu (mig 0095):
      - `house_id` — tin đăng. Đường cũ, vẫn là đường chính khi khách đi từ tin.
      - `room_id`  — phòng trong dự án. Cần vì (a) phòng chưa gắn tin thì không
        có `house_id` nào để neo, và (b) chỉ qua phòng mới lần ra được TOÀ, mà
        chủ nhà là `buildings.host_id` chứ không phải `houses.host_id`.

    Ít nhất một trong hai phải có; cả hai cùng có là trường hợp thường gặp nhất
    (tin sinh từ phòng) và được điền cả hai để mọi truy vấn đều bắt được.
    """

    __tablename__ = "viewing_appointments"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    house_id: Mapped[Optional[int]] = mapped_column(
        Integer, index=True, nullable=True
    )
    room_id: Mapped[Optional[int]] = mapped_column(
        Integer, index=True, nullable=True
    )
    # 'xem' — khách đi xem, chủ nhà không phải chốt gì.
    # 'chot' — hẹn gặp để CHỐT phòng (R7). Hai việc khác nhau; gộp một loại thì
    # "đã xem 5 lượt" và "đang chốt 5 phòng" thành cùng một con số.
    loai: Mapped[str] = mapped_column(
        String(10), default="xem", server_default="xem", index=True
    )
    guest_id: Mapped[int] = mapped_column(Integer, index=True)
    booking_date: Mapped[str] = mapped_column(String(20), default="")
    booking_time: Mapped[str] = mapped_column(String(50), default="")
    message: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    # Mốc host phản hồi lần đầu (pending→khác) — tính avg_response_hours (mig 0058).
    responded_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True
    )
    # ── Phiếu hẹn (migration 0114) ──────────────────────────────────────────
    #: 'truc_tiep' (xem tại căn hộ) | 'video' (gọi video Zalo). Rỗng = lịch cũ.
    hinh_thuc: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    #: Số người cùng đi xem, để sale biết đón mấy người.
    so_nguoi: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    #: Người đi xem — có khi không phải chủ tài khoản (đặt hộ).
    ten_khach: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    #: SĐT nhận Zalo — có khi khác SĐT đăng nhập.
    sdt_khach: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    # ── Xin đổi giờ vì bận (migration 0115) ────────────────────────────────
    #: JSON [{"ngay","gio"}] — các giờ bên bán đề xuất khi bận giờ khách chọn.
    de_xuat_gio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    #: Vì sao xin đổi — khách cần biết, không thì tưởng bị từ chối khéo.
    ly_do_doi: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    #: Giờ cũ bị đổi ("2026-09-16 10:00-11:00").
    gio_cu: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    #: Ai bấm đổi giờ (sale hay chủ nhà).
    nguoi_doi: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    # ── Canonical viewing v2 (migration 0122) ─────────────────────────────
    # Legacy `status` stays for old clients. New commands write both values in
    # one transaction; old rows are projected/backfilled additively.
    canonical_status: Mapped[Optional[str]] = mapped_column(
        String(32), nullable=True, index=True
    )
    canonical_version: Mapped[int] = mapped_column(
        Integer, default=1, server_default="1", nullable=False
    )
    confirmed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    cancelled_by_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    cancelled_by_role: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    cancel_reason_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    cancel_reason_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)


class HouseViewDay(Base):
    """Lượt xem tin THEO NGÀY (giờ VN) — migration 0135.

    `houses.view_count` chỉ là tổng dồn, không vẽ được biểu đồ "Hiệu quả bài
    đăng" của sale theo ngày. Mỗi lượt mở trang chi tiết tin cộng 1 vào đúng
    một dòng (tin, ngày); chỉ có số liệu từ ngày bắt đầu ghi.
    """

    __tablename__ = "house_view_days"
    house_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("houses.id", ondelete="CASCADE"), primary_key=True
    )
    ngay: Mapped[date] = mapped_column(Date, primary_key=True)
    so_luot: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class Wishlist(Base):
    __tablename__ = "wishlists"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer)
    house_id: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    __table_args__ = (UniqueConstraint("user_id", "house_id", name="uq_user_house"),)


class SavedPost(Base):
    """Bài cộng đồng đã lưu (migration 0054).

    Tin BĐS dùng bảng `wishlists` sẵn có — không gộp chung, vì hai thứ khác
    nhau về nghiệp vụ: wishlist là ý định thuê/mua (chủ nhà xem được như lead),
    còn lưu bài viết chỉ là đánh dấu đọc lại, KHÔNG được lộ cho ai.
    """

    __tablename__ = "saved_posts"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True)
    post_id: Mapped[int] = mapped_column(Integer, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    __table_args__ = (
        UniqueConstraint("user_id", "post_id", name="uq_saved_post_user_post"),
    )


class ContentReport(Base):
    """Báo cáo nội dung dùng chung cho tin BĐS và bài cộng đồng (mig 0054).

    Hai luồng KHÁC NHAU tuy cùng bảng, phân biệt bằng `reason`:
      - `wrong_info` → **báo sai cho người đăng**: gửi thông báo cho chủ nội
        dung để họ tự sửa. Không phải tố cáo, không vào hàng đợi xử phạt.
      - còn lại (spam/scam/inappropriate/duplicate) → **báo cáo vi phạm**: vào
        hàng đợi admin, người đăng KHÔNG được biết ai báo.

    Reel có bảng `reel_reports` riêng từ trước — cố ý không gộp lại ở đợt này
    để tránh migration dữ liệu rủi ro cho tính năng đang chạy.
    """

    __tablename__ = "content_reports"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # 'house' | 'post'
    target_type: Mapped[str] = mapped_column(String(20), index=True)
    target_id: Mapped[int] = mapped_column(Integer, index=True)
    reporter_id: Mapped[int] = mapped_column(Integer, index=True)
    # 'feedback' (báo sai cho người đăng) | 'violation' (tố cáo cho admin).
    # PHẢI nằm trong khoá unique: một người có quyền vừa nhắc chủ tin sửa sai,
    # vừa tố cáo vi phạm — gộp chung sẽ chặn mất một trong hai.
    kind: Mapped[str] = mapped_column(
        String(12), default="violation", server_default="violation", index=True
    )
    reason: Mapped[str] = mapped_column(String(30), default="other")
    detail: Mapped[str] = mapped_column(Text, default="")
    # pending → reviewed | dismissed
    status: Mapped[str] = mapped_column(
        String(20), default="pending", index=True, server_default="pending"
    )
    reviewed_by: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)
    __table_args__ = (
        # 1 người chỉ báo 1 lần / nội dung — chống spam báo cáo để dìm đối thủ.
        UniqueConstraint(
            "target_type", "target_id", "reporter_id", "kind",
            name="uq_content_report_target_reporter_kind",
        ),
    )


class Review(Base):
    __tablename__ = "reviews"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True)
    house_id: Mapped[int] = mapped_column(Integer, index=True)
    # Điểm TỔNG do khách cho TRỰC TIẾP (không phải TB các mục con) — mẫu Airbnb.
    rating: Mapped[int] = mapped_column(Integer)
    # Đánh giá này có bằng chứng quan hệ thật không (đã xem nhà / đã chốt giao
    # dịch / đã ở) — migration 0087. Đánh giá tạo TRƯỚC 05/09/2026 đều false vì
    # hồi đó cổng `review_requires_stay` còn tắt: ai đăng nhập cũng chấm được
    # bất kỳ tin nào. Huy hiệu uy tín chỉ đếm dòng true.
    verified_relationship: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )
    comment: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    # 6 tiêu chí con kiểu Airbnb (migration 0058) — nullable, chỉ để hiển thị.
    cleanliness: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    accuracy: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    checkin: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    communication: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    location: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    value: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

