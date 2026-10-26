from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

# ── Phase 03: Nhà trọ Core — Building / Room / Tenant / Contract ──────────────


class Building(Base):
    """A physical rental property building owned by a host."""
    __tablename__ = "buildings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(300))
    address: Mapped[str] = mapped_column(String(500), default="")
    city: Mapped[str] = mapped_column(String(100), default="")
    district: Mapped[str] = mapped_column(String(100), default="")
    ward: Mapped[str] = mapped_column(String(100), default="")
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)

    # ── Phase delegation (migration 0029) ────────────────────────────────────
    # AC-55c: NULL = unknown (default 6h approve-then-file);
    # TRUE = district confirmed pre-file acceptance; FALSE = explicitly rejected.
    district_pre_file_accepted: Mapped[Optional[bool]] = mapped_column(
        Boolean, nullable=True, default=None
    )

    # ── Bàn giao sale → chủ nhà (migration 0083) ─────────────────────────────
    # Sale dựng dự án và đăng phòng khi CHƯA tìm được chủ nhà, nên host_id lúc
    # đầu là sale. `claim_code` là mã sale đưa cho chủ nhà; chủ nhà nhập mã →
    # host_id chuyển sang họ, sale ở lại làm operator.
    # Chỉ cho bàn giao khi toà CHƯA có hoá đơn/hợp đồng — đổi host_id sau khi
    # đã phát sinh tiền là đẩy payout sang tài khoản khác (xem AC-51).
    claim_code: Mapped[Optional[str]] = mapped_column(
        String(10), nullable=True, unique=True, index=True
    )
    claimed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_by_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    # Hiện dự án + bảng giá từng phòng ra trang cá nhân (migration 0084).
    # Mặc định bật vì mục đích chính là rao; tắt khi không muốn lộ giá.
    # SALE PHỤ TRÁCH — mặt tiền CÔNG KHAI của toà (migration 0093).
    #
    # Toà cần HAI người: `host_id` là chủ nhà (vận hành, sở hữu — RIÊNG TƯ), còn
    # đây là người khách nhìn thấy và liên hệ. Sale bỏ công tìm ra chủ nhà, nên
    # quan hệ đó là thứ họ sở hữu; khách và sale khác chỉ được đi qua sale.
    #
    # NULL = toà đã bàn giao nhưng chủ nhà chưa liên kết sale nào. KHÔNG được
    # lấp bằng `host_id` — lấp thế là đưa danh tính chủ nhà ra ô công khai, đúng
    # cái lỗi cột này sinh ra để bịt.
    sale_id: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True, index=True
    )

    # MÃ MỜI SALE (migration 0102) — chiều NGƯỢC của `claim_code`.
    #
    #   claim_code   sale tạo toà  → CHỦ NHÀ nhập → host_id chuyển sang họ
    #   ma_moi_sale  chủ nhà tạo   → SALE nhập    → sale_id trỏ về sale đó
    #
    # Hai cột riêng vì nhầm lẫn thì mất toà: chủ nhà đưa nhầm `claim_code` cho
    # sale, sale nhập vào là thành chủ sở hữu. Dùng MỘT LẦN — mã còn hiệu lực
    # mãi là một chìa khoá lang thang trong tin nhắn Zalo.
    ma_moi_sale: Mapped[Optional[str]] = mapped_column(
        String(10), nullable=True
    )

    is_public: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False, index=True
    )

    # ── Giá tiện ích MẶC ĐỊNH của cả toà (migration 0104) ────────────────────
    #
    # Trước đó đơn giá điện/nước không được lưu ở đâu cả: nó là tham số của
    # `GenerateBatchRequest` với hằng số cứng 3500/15000, nên mỗi lần chốt tiền
    # tháng chủ nhà phải gõ lại, và cả lô dùng chung MỘT giá.
    #
    # Đặt ở toà vì đó là mức đúng cho gần như mọi trường hợp — một toà 20 phòng
    # xài chung công tơ tổng, cùng một giá. Phòng nào tính khác thì ghi đè ở
    # `Room.gia_dien` (xem `services/gia_tien_ich.py`).
    #
    # NULL ≠ 0. `0` nghĩa là MIỄN PHÍ (nhiều nhà trọ bao nước); `None` nghĩa là
    # chưa khai. Gộp hai thứ vào `0` thì không bao giờ khai được "bao nước".
    gia_dien: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    #: Tài khoản nhận tiền (mig 0139): BIN NAPAS · số TK · chủ TK. NULL = dùng
    #: tầng trên (phòng → toà → hồ sơ chủ nhà) — xem services/tai_khoan_nhan.py.
    tk_ngan_hang: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    tk_so: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    tk_chu: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    gia_nuoc: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    phi_dich_vu: Mapped[Optional[float]] = mapped_column(Float, nullable=True)


class LoaiPhong(Base):
    """HẠNG PHÒNG của một toà lưu trú ngắn hạn (migration 0111).

    Khách đặt homestay/khách sạn chọn HẠNG ("Studio VIP", "Phòng đôi hướng
    vườn"), số phòng do lễ tân gán lúc nhận. Vì vậy những gì chung của cả hạng
    (sức chứa, diện tích, giường, ảnh, tiện nghi, GIÁ) nằm ở đây, không chép
    lại ở từng phòng: mười phòng giống hệt nhau mà gõ giá mười lần thì sai một
    phòng không ai thấy.

    Trước đây hạng chỉ là chuỗi tự do trên `room_kenh.loai_phong` — gõ lệch một
    dấu là đẻ ra hạng mới, và không chỗ nào trả lời được "hạng này còn trống
    mấy phòng", thứ quyết định có nhận khách hay không.

    Quan hệ với KÊNH: hạng là thuộc tính VẬT LÝ của phòng (một phòng đúng một
    hạng); kênh là CÁCH BÁN (một phòng nhiều kênh). Đừng trộn hai trục.

    Giá hiệu lực giải quyết ở một chỗ — `loai_phong_service.gia_hieu_luc`:
    `room_kenh.gia_*` (ghi đè riêng phòng) ?? giá của hạng. `None` = chưa khai,
    `0` = miễn phí — hai thứ khác nhau.
    """

    __tablename__ = "loai_phong"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    building_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("buildings.id", ondelete="CASCADE"), index=True
    )
    ten: Mapped[str] = mapped_column(String(120))
    mo_ta: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    suc_chua: Mapped[int] = mapped_column(Integer, default=2, server_default="2")
    dien_tich: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    #: "King 1m8", "2 giường đơn" — chữ, vì thị trường gọi đủ kiểu.
    giuong: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    anh: Mapped[list] = mapped_column(JSONList, default=list)
    tien_nghi: Mapped[list] = mapped_column(JSONList, default=list)
    gia_theo_gio: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    gia_qua_dem: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    gia_theo_ngay: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    thu_tu: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    #: Tắt hạng = ngừng nhận khách mới cho cả nhóm phòng, không phải xoá.
    dang_ban: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true"
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class Room(Base):
    """A single rentable room within a Building.

    State machine: vacant ↔ occupied (via contract), vacant ↔ maintenance (manual).
    Transitions validated in room_state_service — NOT here in the model.
    """
    __tablename__ = "rooms"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    building_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("buildings.id", ondelete="CASCADE"), index=True
    )
    code: Mapped[str] = mapped_column(String(50))  # e.g. "P01", "A-101"
    area_m2: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    capacity: Mapped[int] = mapped_column(Integer, default=1)  # max tenants
    base_price: Mapped[float] = mapped_column(Float, default=0)
    # Status: vacant | occupied | maintenance
    status: Mapped[str] = mapped_column(String(20), default="vacant", index=True)
    maintenance_start: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # ISO date
    maintenance_end: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    images: Mapped[list] = mapped_column(JSONList, default=list)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)

    # Phase 08 — Marketplace integration
    is_listed_on_marketplace: Mapped[bool] = mapped_column(
        Boolean, default=False, index=True
    )
    marketplace_house_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("houses.id", ondelete="SET NULL"), nullable=True
    )
    # ── Sở hữu & vận hành (migration 0085) ───────────────────────────────────
    # Một dự án chứa được phòng của NHIỀU chủ phòng, nên chủ nằm ở đây chứ
    # không suy từ `buildings.host_id`. Nullable vì phòng cũ backfill dần và
    # sale dựng phòng trước khi tìm được chủ.
    owner_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    managed_by_sale_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Phase 07 hint: Room can be used as a homestay unit (1-room building).
    is_homestay: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    # ── Hạng phòng (migration 0111) ──────────────────────────────────────────
    # NULL = phòng chưa xếp hạng: thuê tháng không cần hạng, và phòng ngắn hạn
    # cũ chưa gán. Xem `LoaiPhong`.
    loai_phong_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("loai_phong.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # ── Giá tiện ích RIÊNG của phòng (migration 0104) ────────────────────────
    #
    # `None` = theo giá của toà (xem `Building.gia_dien`). Chỉ khai ở đây khi
    # phòng này tính khác cả toà — phòng có điều hoà tính điện cao hơn, phòng
    # tầng trệt bao nước.
    #
    # `None` ≠ `0`: `0` là miễn phí, `None` là chưa khai. Thứ tự giải quyết nằm
    # ở ĐÚNG MỘT chỗ — `services/gia_tien_ich.py`.
    gia_dien: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    #: Tài khoản nhận tiền (mig 0139): BIN NAPAS · số TK · chủ TK. NULL = dùng
    #: tầng trên (phòng → toà → hồ sơ chủ nhà) — xem services/tai_khoan_nhan.py.
    tk_ngan_hang: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    tk_so: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    tk_chu: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    gia_nuoc: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    phi_dich_vu: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Hai danh sách KHÁC NHAU, cố ý không gộp:
    #   `dich_vu_gom`    — phí dịch vụ hàng tháng bao gồm những gì (gửi xe, rác)
    #   `do_trong_phong` — phòng có sẵn đồ gì, không tính tiền (giường, tủ)
    # Gộp làm một thì không trả lời được "trả tiền dịch vụ để lấy cái gì".
    #
    # Lưu KEY (`may_giat`), không lưu nhãn — đổi nhãn thì dữ liệu cũ không hỏng.
    # Danh mục key ở `services/tien_ich_phong.py`.
    dich_vu_gom: Mapped[list] = mapped_column(JSONList, default=list)
    do_trong_phong: Mapped[list] = mapped_column(JSONList, default=list)

    # Hồ sơ phòng (migration 0107). `tang` là chữ: "Trệt", "Lửng" nhiều như số.
    # `huong` dùng CHUNG slug với `houses.direction` — phòng lên chợ thành tin,
    # hai bộ từ vựng lệch nhau là lọc theo hướng không ra phòng.
    tang: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    huong: Mapped[Optional[str]] = mapped_column(String(12), nullable=True)

    #: Nước tính THEO NGƯỜI (gia_nuoc = đ/người/tháng) thay vì theo công tơ.
    #: NULL/False = theo chỉ số. Migration 0136.
    nuoc_theo_nguoi: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)


class RoomSuaChua(Base):
    """Một lần sửa chữa / sự cố của phòng (migration 0107).

    Bảo trì trên `rooms` chỉ là MỘT khoảng thời gian đang diễn ra — xong là mất
    dấu. Sổ này giữ từng lần: hỏng gì, ai làm, tốn bao nhiêu, đã xong chưa.
    `chi_phi` là tiền của chủ nhà nên API chỉ trả cho người xem được tài chính.
    """

    __tablename__ = "room_sua_chua"

    DANG_XU_LY = "dang_xu_ly"
    DA_XONG = "da_xong"
    TRANG_THAI = (DANG_XU_LY, DA_XONG)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="CASCADE"), index=True
    )
    host_id: Mapped[int] = mapped_column(Integer, index=True)
    tieu_de: Mapped[str] = mapped_column(String(200))
    mo_ta: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    ngay: Mapped[str] = mapped_column(String(20))  # ISO YYYY-MM-DD
    nguoi_thuc_hien: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    chi_phi: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    trang_thai: Mapped[str] = mapped_column(
        String(20), default=DA_XONG, server_default=DA_XONG
    )
    created_by: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class RoomTaiSan(Base):
    """Một món tài sản / nội thất bàn giao cùng phòng (migration 0108).

    `rooms.do_trong_phong` chỉ trả lời "phòng có điều hoà không" (để lọc tin).
    Bảng này trả lời câu của biên bản bàn giao: điều hoà hãng gì, bao nhiêu BTU,
    còn tốt hay đã hao mòn — thứ chủ nhà đối chiếu lúc khách trả phòng.
    """

    __tablename__ = "room_tai_san"

    TOT = "tot"
    HAO_MON = "hao_mon"
    HONG = "hong"
    TINH_TRANG = (TOT, HAO_MON, HONG)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="CASCADE"), index=True
    )
    host_id: Mapped[int] = mapped_column(Integer, index=True)
    # key của `do_trong_phong` (dieu_hoa, tu_lanh…) để vẽ biểu tượng; NULL = món khác
    loai: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    ten: Mapped[str] = mapped_column(String(120))
    thong_so: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    tinh_trang: Mapped[str] = mapped_column(String(20), default=TOT, server_default=TOT)
    ghi_chu: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_by: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)


class Tenant(Base):
    """A person who can be party to a rental contract.

    Reusable across contracts — one record per real person.
    CCCD number stored as one-way hash (compare only).
    """
    __tablename__ = "tenants"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    full_name: Mapped[str] = mapped_column(String(300))
    cccd_number_hash: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    # 3 số CUỐI của CCCD (migration 0108) — đủ để chủ nhà đối chiếu thẻ. Không
    # lưu đầu số: 9 số đầu cạnh bcrypt hash là dò lại được cả số trong vài phút.
    cccd_duoi: Mapped[Optional[str]] = mapped_column(String(4), nullable=True)
    phone: Mapped[str] = mapped_column(String(50), default="")
    email: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    birthday: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # ISO date
    address_origin: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    cccd_front_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    cccd_back_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)

    # Phase 08 — placeholder tenant from marketplace booking (phone-only, no User).
    is_placeholder: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    # 'viewing_appointment' | 'reservation' — origin booking type.
    created_from_booking_type: Mapped[Optional[str]] = mapped_column(
        String(30), nullable=True
    )
    created_from_booking_id: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True
    )


class Contract(Base):
    """A rental agreement between a host and one-or-more tenants for a room.

    Lifecycle: draft → active → (expired | terminated).
    Soft delete: terminated contracts remain in DB; exclude from default queries.
    Photo arrays stored as JSONList (paths on disk).
    """
    __tablename__ = "contracts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="RESTRICT"), index=True
    )
    start_date: Mapped[str] = mapped_column(String(20))  # ISO date YYYY-MM-DD
    end_date: Mapped[str] = mapped_column(String(20))
    monthly_rent: Mapped[float] = mapped_column(Float)
    deposit: Mapped[float] = mapped_column(Float, default=0)
    # Status: draft | active | expired | terminated
    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    terminated_at: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    actual_end_date: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    deposit_refund_amount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    damage_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    damage_photos: Mapped[list] = mapped_column(JSONList, default=list)
    handover_photos: Mapped[list] = mapped_column(JSONList, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)

    # Phase 08 — 'manual' (default) | 'marketplace' (from booking) | 'imported'.
    # Dual-write window: keep String column until Phase 3.5 drop (revision 0017).
    source: Mapped[str] = mapped_column(String(20), default="manual", index=True)
    # Phase 04 analytics — FK to revenue_sources. NOT NULL enforced by 0018
    # after service layer dual-writes on every INSERT path.
    source_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("revenue_sources.id", ondelete="SET NULL"), nullable=False
    )

    # ORM relationship — back_populates on RevenueSource.contracts
    revenue_source: Mapped[Optional["RevenueSource"]] = relationship(
        "RevenueSource", back_populates="contracts", lazy="select"
    )

    # ── Phase delegation (migration 0030) ────────────────────────────────────
    # AC-55b: CT01 form snapshot for pre-file audit trail (operator pre-files before move-in)
    # JSON type: Postgres → JSONB, SQLite → TEXT (cross-DB compatible)
    kb04_form_data_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    # AC-55b: marks that this contract has had a KB04 pre-file submission
    kb04_pre_filed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # ── Kỳ thanh toán + cọc đã thu (migration 0108) ──────────────────────────
    # NULL = chưa khai. `coc_da_thu` NULL ≠ 0: 0 là đã kiểm và chưa thu đồng nào.
    ngay_thanh_toan: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # 1..31
    # 'chuyen_khoan' | 'tien_mat' | 'ca_hai'
    hinh_thuc_thanh_toan: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    coc_da_thu: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # ── Cho thuê NGOÀI APP (migration 0110) ──────────────────────────────────
    # True = chủ nhà tự tìm khách (Facebook, môi giới, người quen) rồi đánh dấu
    # phòng đã cho thuê; hợp đồng này chỉ ghi nhận, không có giấy tờ trong app và
    # người thuê KHÔNG có tài khoản (đừng chờ họ gửi ảnh công tơ).
    ngoai_luong: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False, server_default="false"
    )
    #: "Thuê qua Facebook, chưa làm giấy tờ" — hợp đồng ngoài luồng thường không
    #: có gì khác để tra.
    ghi_chu: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    #: Số người ở thực tế — nhân với dịch vụ / nước tính theo người.
    #: NULL = đếm người còn ở trên hợp đồng (tối thiểu 1). Migration 0136.
    so_nguoi_o: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)


class ContractTenant(Base):
    """M:N pivot: Contract ↔ Tenant.

    Composite PK (contract_id, tenant_id) — no surrogate key.
    is_primary = True for the tenant responsible for payment.
    """
    __tablename__ = "contract_tenants"
    __table_args__ = (
        Index("ix_contract_tenants_contract_id", "contract_id"),
        Index("ix_contract_tenants_tenant_id", "tenant_id"),
    )

    contract_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="CASCADE"), primary_key=True
    )
    tenant_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="CASCADE"), primary_key=True
    )
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    joined_at: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # ISO date
    left_at: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    # ── Phase delegation (migration 0031) ────────────────────────────────────
    # Millisecond-precision move-in time for AC-55b 6h SLA post-move-in.
    # Dual-write: both joined_at (ISO date, legacy) and joined_at_datetime coexist
    # until phase-11 verifies switchover. Backfilled from joined_at at migration time.
    joined_at_datetime: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


# ── Phase 04: Nhà trọ Ops — Invoice / Payment / Meter / ServiceFee / CreditNote ──


class ServiceFee(Base):
    """Catalog of recurring/one-time service fees per building (Internet, Cleaning…).

    Per-contract opt-in via ContractServiceFee pivot. unit_price is the catalog default;
    actual amount per invoice line is snapshotted to avoid retroactive changes.
    """
    __tablename__ = "service_fees"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    building_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("buildings.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(200))
    unit_price: Mapped[float] = mapped_column(Float, default=0)
    # Billing cycle: monthly | one_time
    billing_cycle: Mapped[str] = mapped_column(String(20), default="monthly")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    #: 'don_gia' (một khoản theo đơn giá) | 'theo_nguoi' (đơn giá × số người ở).
    #: NULL = don_gia. Migration 0136.
    cach_tinh: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class ContractServiceFee(Base):
    """M:N pivot Contract ↔ ServiceFee.

    monthly_amount snapshotted at attach-time (not auto-synced with ServiceFee.unit_price).
    """
    __tablename__ = "contract_service_fees"

    contract_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="CASCADE"), primary_key=True
    )
    service_fee_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("service_fees.id", ondelete="CASCADE"), primary_key=True
    )
    monthly_amount: Mapped[float] = mapped_column(Float, default=0)


class MeterReading(Base):
    """Per-room electricity/water reading recorded by host.

    History row per period. Used by invoice generation: latest reading minus previous
    = usage units for current invoice.
    """
    __tablename__ = "meter_readings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="CASCADE"), index=True
    )
    reading_date: Mapped[str] = mapped_column(String(20), index=True)  # ISO date YYYY-MM-DD
    electricity_kwh: Mapped[float] = mapped_column(Float, default=0)
    water_m3: Mapped[float] = mapped_column(Float, default=0)

    # ── Ảnh + bước duyệt (migration 0106) ────────────────────────────────────
    #
    # Luồng nhà trọ dài hạn: người thuê chụp công tơ gửi lên → chủ nhà xem ảnh
    # rồi duyệt. Trước đó chỉ có con số, chủ nhà tự ghi tự nhập, nên không có gì
    # để đối chiếu khi hai bên cãi nhau về số điện.
    #
    # `trang_thai`: 'cho_duyet' | 'da_duyet' | 'can_chup_lai'. Mặc định
    # `da_duyet` vì chỉ số do CHỦ NHÀ tự nhập thì người nhập chính là người
    # duyệt — bắt họ duyệt lại con số mình vừa gõ là làm hoá đơn đứng chờ vô cớ.
    anh_dien: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    anh_nuoc: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    trang_thai: Mapped[str] = mapped_column(
        String(20), default="da_duyet", server_default="da_duyet", index=True
    )
    #: NULL = chủ nhà tự nhập; có số = người thuê gửi qua app.
    nguoi_gui_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    duyet_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    duyet_boi: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    #: Lý do trả về khi `can_chup_lai` — người thuê cần biết VÌ SAO.
    ly_do_tra_ve: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # ── Ảnh chủ nhà TỰ CHỤP trong app (migration 0109) ───────────────────────
    # Ảnh lấy từ thư viện thì không ai biết chụp lúc nào, ở đâu. Chụp thẳng
    # trong app mới ghi được ba thứ này, và tấm ảnh mới có sức chứng minh.
    # Toạ độ NULL hợp lệ: người dùng có quyền từ chối chia sẻ vị trí.
    chup_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    chup_lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    chup_lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    chup_boi: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    #: 'chu_nha' = chủ nhà tự chụp; NULL / 'nguoi_thue' = người thuê gửi.
    nguon_anh: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)




class RoomKenh(Base):
    """KÊNH BÁN của một phòng — phòng đó được rao thế nào, giá bao nhiêu.

    Vì sao là BẢNG chứ không phải một cột enum trên `Room`:

    1. **Một phòng chạy được nhiều kênh cùng lúc.** Có khách thuê dài thì cho
       thuê dài, chưa có thì chạy theo đêm cho đỡ trống. Enum đơn trị không
       diễn tả nổi.
    2. **Mỗi kênh có tham số riêng** (số đêm tối thiểu · số tháng tối thiểu ·
       cọc mấy tháng). Nhét hết vào `rooms` là chục cột rỗng phần lớn thời gian.
    3. **Giá phải đi kèm ĐƠN VỊ.** `Room.base_price` là một số trần mang bốn
       nghĩa — chính chỗ đó đẻ ra lỗi lấy giá THÁNG nhân với số ĐÊM.

    `Room.base_price` vẫn còn (nhiều chỗ đọc) nhưng là DI SẢN; nguồn đúng để
    hiển thị và tính tiền là bảng này.
    """

    __tablename__ = "room_kenh"
    __table_args__ = (
        UniqueConstraint("room_id", "kenh", name="uq_room_kenh"),
    )

    #: BỐN PIPELINE khai thác. Đây là trục nghiệp vụ chính: mỗi kênh một cách
    #: đặt, một vòng đời, một bộ công cụ cho chủ nhà.
    NGAN_HAN = "ngan_han"   # đặt theo đêm      → reservations
    DAI_HAN = "dai_han"     # hợp đồng tháng    → contracts
    MAT_BANG = "mat_bang"   # thuê kinh doanh   → contracts + kỳ miễn phí sửa
    BAN = "ban"             # mua bán           → deals
    KENH = (NGAN_HAN, DAI_HAN, MAT_BANG, BAN)
    DON_VI_MAC_DINH = {
        NGAN_HAN: "dem",
        DAI_HAN: "thang",
        MAT_BANG: "m2_thang",
        BAN: "tong",
    }

    #: Vòng đời, đặt trên KÊNH chứ không trên PHÒNG: một phòng đang cho thuê
    #: dài hạn vẫn có thể đang được rao bán (bán kèm khách thuê). Hai trạng
    #: thái chạy song song — nhét vào một cột trên `rooms` là ép chọn một.
    DANG_RAO = "dang_rao"
    GIU_CHO = "giu_cho"          # khách đặt cọc giữ chỗ, chưa xuống tiền
    DA_COC = "da_coc"            # đã cọc mua bán
    DA_BAN = "da_ban"            # kết thúc — không cho thuê được nữa
    DA_CHO_THUE = "da_cho_thue"  # kết thúc của kênh thuê
    #: Trạng thái KẾT THÚC — kênh không còn nhận khách mới.
    KET_THUC = (DA_BAN, DA_CHO_THUE)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="CASCADE"), index=True
    )
    kenh: Mapped[str] = mapped_column(String(20))
    gia: Mapped[float] = mapped_column(Float, default=0)
    loai_phong: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    gia_theo_gio: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    gia_qua_dem: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    gia_theo_ngay: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    huy_truoc_gio: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    huy_truoc_dem: Mapped[int] = mapped_column(Integer, default=2, server_default="2")
    huy_truoc_ngay: Mapped[int] = mapped_column(Integer, default=12, server_default="12")
    #: 'dem' | 'thang' | 'm2_thang' | 'tong'
    don_vi: Mapped[str] = mapped_column(String(20))
    #: Số đêm / số tháng tối thiểu. None = không ràng buộc.
    toi_thieu: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    #: Cọc — số tháng (thuê) hoặc phần trăm (bán).
    dat_coc: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    #: Tắt tạm mà KHÔNG mất cấu hình giá. Xoá dòng là mất luôn tham số đã đặt.
    dang_bat: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    #: Vòng đời của riêng kênh này (mig 0098). Xem hằng số ở trên.
    trang_thai: Mapped[str] = mapped_column(
        String(20), default=DANG_RAO, server_default=DANG_RAO, index=True
    )
    #: Mốc chốt (đã bán / đã cho thuê) — không có nó thì "bán tháng trước" và
    #: "bán năm ngoái" là cùng một trạng thái.
    chot_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    chot_boi: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    #: MẶT BẰNG: số tháng miễn tiền thuê để bên thuê sửa chữa. Điều khoản chuẩn
    #: của thuê thương mại, luôn được thương lượng — để trong ghi chú tự do thì
    #: không thống kê được, cũng không nhắc hạn được.
    mien_phi_thang: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=now_utc, onupdate=now_utc
    )


class RoomChiemDung(Base):
    """MỘT dòng thời gian "phòng này bận" cho MỌI kênh (migration 0096).

    Trước đây câu hỏi "phòng còn trống không" có hai người trả lời không biết
    nhau: `reservations` (theo ngày, cho kênh đêm) và `rooms.status` (một cờ
    vacant/occupied, không có ngày, cho kênh tháng). Nên hợp đồng thuê từ 01/10
    không chặn được ai đặt đêm 15/10, và chủ nhà không có "lịch" nào để nhìn —
    chỉ có một bóng đèn bật/tắt.

    Bảng này là nguồn sự thật chung. Mọi kênh ghi vào đây; ràng buộc
    `EXCLUDE USING gist` khiến hai khoảng chồng nhau trên cùng một phòng KHÔNG
    THỂ tồn tại — không nhờ code nhớ kiểm, mà nhờ DB từ chối.

    Quy ước ngày: `tu_ngay` tính, `den_ngay` là ngày TRẢ phòng và KHÔNG tính
    (nửa khoảng `[)`, trùng `reservations.check_out_date`). Nhờ vậy trả sáng
    nay / nhận chiều nay không bị coi là chồng lấn.
    """

    __tablename__ = "room_chiem_dung"
    __table_args__ = (
        Index("ix_room_chiem_dung_nguon", "nguon", "nguon_id"),
        CheckConstraint("den_ngay > tu_ngay", name="ck_room_chiem_dung_ngay"),
    )

    #: Giá trị hợp lệ của `nguon` — ai sinh ra dòng này. Cần để gỡ ĐÚNG dòng khi
    #: đơn/hợp đồng bị huỷ, thay vì xoá theo ngày rồi trúng nhầm của kênh khác.
    RESERVATION = "reservation"
    CONTRACT = "contract"
    THU_CONG = "thu_cong"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("rooms.id", ondelete="CASCADE"), index=True
    )
    tu_ngay: Mapped[date] = mapped_column(Date)
    den_ngay: Mapped[date] = mapped_column(Date)
    # Vietnam wall time; NULL preserves the original whole-date interval.
    tu_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    den_luc: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    #: 'ngan_han' | 'dai_han' | 'khoa' (chủ nhà tự chặn: sửa chữa, để người nhà ở)
    kenh: Mapped[str] = mapped_column(String(20), default="dai_han")
    nguon: Mapped[str] = mapped_column(String(20), default=THU_CONG)
    nguon_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    ghi_chu: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class ContractTaiLieu(Base):
    """Giấy tờ của MỘT hợp đồng: ảnh/PDF hợp đồng đã ký và minh chứng cọc (mig 0138).

    Gắn vào HỢP ĐỒNG chứ không vào hồ sơ chốt thuê: phần lớn hợp đồng do chủ
    nhà tự nhập (không qua sale) nên trước đây không có chỗ nào để ảnh. Ai tải
    cũng được — chủ nhà, khách thuê, sale phụ trách — và bên kia thấy ngay.
    Thuê trước, bổ sung sau: thiếu giấy tờ chỉ là CẢNH BÁO, không chặn ở.
    """

    __tablename__ = "contract_tai_lieu"

    HOP_DONG = "hop_dong"
    MINH_CHUNG_COC = "minh_chung_coc"
    LOAI = (HOP_DONG, MINH_CHUNG_COC)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    contract_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="CASCADE"), index=True
    )
    loai: Mapped[str] = mapped_column(String(20))
    url: Mapped[str] = mapped_column(String(500))
    #: 'chu_nha' | 'khach' | 'sale' | 'admin' — hiển thị "ai tải".
    vai: Mapped[str] = mapped_column(String(20))
    nguoi_tai_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
