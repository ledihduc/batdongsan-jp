"""Pydantic v2 schemas for Room endpoints."""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, field_validator

RoomStatus = Literal["vacant", "occupied", "maintenance"]


class _TienIchVao(BaseModel):
    """Giá tiện ích + hai danh sách tick. Dùng chung cho create và update.

    Cả ba giá đều `None` được, và `None` KHÁC `0`: `0` là miễn phí (nhà trọ bao
    nước), `None` là "chưa khai, lấy theo toà". Xem `services/gia_tien_ich.py`.
    """

    gia_dien: Optional[float] = None
    gia_nuoc: Optional[float] = None
    phi_dich_vu: Optional[float] = None
    dich_vu_gom: Optional[list[str]] = None
    do_trong_phong: Optional[list[str]] = None

    @field_validator("gia_dien", "gia_nuoc", "phi_dich_vu")
    @classmethod
    def _khong_am(cls, v: Optional[float]) -> Optional[float]:
        if v is not None and v < 0:
            raise ValueError("Giá không được âm")
        return v


#: Cùng bộ slug với `houses.direction` — phòng lên chợ thành tin.
HUONG = (
    "north", "northeast", "east", "southeast",
    "south", "southwest", "west", "northwest",
)


class _ViTriVao(BaseModel):
    """Tầng + hướng (migration 0107). SỬA mà gửi `null` = xoá giá trị đang có."""

    tang: Optional[str] = None
    huong: Optional[str] = None

    @field_validator("tang")
    @classmethod
    def _tang(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        v = v.strip()
        if len(v) > 20:
            raise ValueError("Tầng tối đa 20 ký tự")
        return v or None

    @field_validator("huong")
    @classmethod
    def _huong(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return None
        if v not in HUONG:
            raise ValueError("Hướng không hợp lệ")
        return v


class RoomCreate(_TienIchVao, _ViTriVao):
    code: str
    area_m2: Optional[float] = None
    capacity: int = 1
    base_price: float = 0
    note: Optional[str] = None
    images: list[str] = []

    # ── Kênh khai thác đầu tiên của phòng (migration 0104) ───────────────────
    #
    # Bắt buộc ở FORM, không bắt buộc ở SCHEMA. Ép 422 tại đây nghĩa là ai còn
    # giữ bản app cũ trong cache (site có service worker) sẽ không tạo nổi phòng
    # nào; thiếu thì mặc định `dai_han` — đúng thứ đường gán-tin đang làm.
    #
    # Vì sao kênh sinh cùng lúc với phòng chứ không để app gọi lượt thứ hai:
    # lượt hai hỏng (mất mạng, 409) là để lại đúng cái đang hỏng hôm nay —
    # phòng tạo xong không thuộc kênh nào nên không ra chợ được.
    kenh: Optional[str] = None
    toi_thieu: Optional[int] = None
    dat_coc: Optional[float] = None
    #: Chỉ có nghĩa với `mat_bang`; kênh khác gửi lên sẽ bị bỏ qua.
    mien_phi_thang: Optional[int] = None

    @field_validator("kenh")
    @classmethod
    def _kenh_hop_le(cls, v: Optional[str]) -> Optional[str]:
        # Import muộn: schemas không được kéo theo models lúc nạp module.
        from app.models.rental import RoomKenh

        if v is None or v == "":
            return None
        if v not in RoomKenh.KENH:
            raise ValueError("Kênh khai thác không hợp lệ")
        return v

    @field_validator("code")
    @classmethod
    def code_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Mã phòng không được để trống")
        return v.strip()

    @field_validator("base_price")
    @classmethod
    def price_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Giá phòng không được âm")
        return v

    @field_validator("capacity")
    @classmethod
    def capacity_positive(cls, v: int) -> int:
        if v < 1:
            raise ValueError("Sức chứa tối thiểu là 1")
        return v


class RoomUpdate(_TienIchVao, _ViTriVao):
    code: Optional[str] = None
    area_m2: Optional[float] = None
    capacity: Optional[int] = None
    base_price: Optional[float] = None
    note: Optional[str] = None
    images: Optional[list[str]] = None


class MaintenanceSetRequest(BaseModel):
    """Body for POST /rooms/{id}/maintenance."""
    maintenance_start: str  # ISO date YYYY-MM-DD
    maintenance_end: Optional[str] = None

    @field_validator("maintenance_start")
    @classmethod
    def start_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Ngày bắt đầu bảo trì không được để trống")
        return v.strip()


class RoomResponse(BaseModel):
    id: int
    building_id: int
    code: str
    area_m2: Optional[float] = None
    capacity: int
    base_price: float
    status: str
    maintenance_start: Optional[str] = None
    maintenance_end: Optional[str] = None
    images: list[str] = []
    note: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    owner_id: Optional[int] = None
    managed_by_sale_id: Optional[int] = None

    gia_dien: Optional[float] = None
    gia_nuoc: Optional[float] = None
    phi_dich_vu: Optional[float] = None
    dich_vu_gom: list[str] = []
    do_trong_phong: list[str] = []

    # Giá ĐÃ GIẢI QUYẾT (phòng → toà → hằng số). App hiển thị số này; ba cột
    # thô ở trên chỉ để biết phòng có đang ghi đè hay không (ô nhập để trống
    # hay điền sẵn). Trả sẵn để app khỏi tự suy — suy ở hai nơi là lệch ở hai
    # nơi.
    gia_dien_hieu_luc: Optional[float] = None
    gia_nuoc_hieu_luc: Optional[float] = None
    phi_dich_vu_hieu_luc: Optional[float] = None

    # Sổ phòng (màn "Quản lí phòng") — chỉ `GET /buildings/{id}/rooms` điền,
    # tính ở `services/so_phong.py` cùng luật với Trang chủ chủ nhà.
    tinh_trang: Optional[str] = None  # dang_o | sap_tra | sap_vao | trong | bao_tri
    loai: list[str] = []  # ngan_han | dai_han | kinh_doanh | khach_san
    gia_kenh: Optional[float] = None
    don_vi: Optional[str] = None  # thang | dem | m2_thang
    # Chỉ chủ phòng / admin nhận — sale phụ trách nhận None.
    khach_thue: Optional[str] = None
    hop_dong_tu: Optional[str] = None
    hop_dong_den: Optional[str] = None
    tra_phong_luc: Optional[datetime] = None
    # Dòng tiền tháng ("Đóng tiền 05/10 · còn 17 ngày" / "Nợ … · quá hạn …") +
    # mức màu xam | cam | do. Cùng luật lộ tiền với khach_thue.
    dong_tien: Optional[str] = None
    dong_tien_muc: Optional[str] = None
    # NGÀY phải thu tiếp theo (YYYY-MM-DD) — để màn quản lý toà xếp được dòng
    # thời gian "Sắp tới"; `dong_tien` chỉ là chữ đọc cho người.
    dong_tien_ngay: Optional[str] = None

    # Hồ sơ phòng (migration 0107).
    tang: Optional[str] = None
    huong: Optional[str] = None
    # "Studio 1PN" — nhãn của kênh phòng đang chạy; điền ở `so_phong`.
    loai_phong: Optional[str] = None
    # Có = phòng đã lên chợ, có link tin để chia sẻ.
    marketplace_house_id: Optional[int] = None

    model_config = {"from_attributes": True}
