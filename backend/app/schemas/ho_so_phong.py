"""Hồ sơ phòng — `GET /api/host/rooms/{id}/ho-so`, sổ sửa chữa, tài sản bàn giao.

Khoá JSON là hợp đồng với app (`lib/data/services/ho_so_phong_api.dart`) — đổi tên
ở đây là màn hình trống im lặng.
"""

import re
from datetime import date
from typing import Literal, Optional

from pydantic import BaseModel, field_validator

from app.schemas.contract import HinhThucThanhToan, kiem_coc_da_thu, kiem_ngay_thu
from app.schemas.room import RoomResponse

TrangThaiSuaChua = Literal["dang_xu_ly", "da_xong"]
TinhTrangTaiSan = Literal["tot", "hao_mon", "hong"]


class ToaRa(BaseModel):
    id: int
    ten: str
    dia_chi: str


class KhachRa(BaseModel):
    tenant_id: int
    ten: str
    sdt: str
    email: Optional[str] = None
    #: Đã lưu đủ ảnh HAI mặt CCCD.
    co_cccd: bool
    #: 3 số CUỐI của CCCD. Số đầy đủ không bao giờ được lưu.
    cccd_duoi: Optional[str] = None


class HopDongRa(BaseModel):
    id: int
    bat_dau: str
    ket_thuc: str
    tien_thue: float
    tien_coc: float
    tong_thang: Optional[int] = None
    da_o_thang: int
    #: Âm = đã quá hạn mà hợp đồng vẫn chưa được đóng.
    con_lai_ngay: Optional[int] = None
    #: % thời gian hợp đồng đã trôi qua, 0..100.
    ty_le: float
    kenh: str  # dai_han | mat_bang
    so_nguoi: int
    khach: Optional[KhachRa] = None
    #: Ngày thu tiền hàng tháng 1..31; `None` = chưa khai.
    ngay_thanh_toan: Optional[int] = None
    hinh_thuc_thanh_toan: Optional[str] = None  # chuyen_khoan | tien_mat | ca_hai
    #: Tiền cọc đã thu; `None` = chưa ghi nhận (khác 0 = chưa thu đồng nào).
    coc_da_thu: Optional[float] = None
    #: True = chủ nhà tự tìm khách rồi đánh dấu (mig 0110). Người thuê KHÔNG có
    #: tài khoản trong app: đừng chờ họ gửi ảnh công tơ, và màn phải nói rõ đây
    #: là ghi nhận chứ không phải hợp đồng có giấy tờ trong app.
    ngoai_luong: bool = False
    ghi_chu: Optional[str] = None


class HoaDonRa(BaseModel):
    id: int
    so: str
    ky: str  # YYYY-MM
    tong: float
    da_tra: float
    trang_thai: str
    han_dong: str


class DienNuocRa(BaseModel):
    thang: str  # YYYY-MM
    ngay_chot: Optional[str] = None
    reading_id: Optional[int] = None
    dien_cu: Optional[float] = None
    dien_moi: Optional[float] = None
    dien_dung: Optional[float] = None
    nuoc_cu: Optional[float] = None
    nuoc_moi: Optional[float] = None
    nuoc_dung: Optional[float] = None
    gia_dien: float
    gia_nuoc: float
    anh_dien: Optional[str] = None
    anh_nuoc: Optional[str] = None
    trang_thai: str
    #: Ai đưa ra số kỳ này: 'khach' | 'chu_nha' | None (chưa có).
    nguoi_ghi: Optional[str] = None
    ly_do_tra_ve: Optional[str] = None
    #: Nước tính theo người (mig 0136) — khách không cần chụp công tơ nước.
    nuoc_theo_nguoi: bool = False
    so_nguoi: Optional[int] = None


class SuaChuaRa(BaseModel):
    id: int
    tieu_de: str
    mo_ta: Optional[str] = None
    ngay: str
    nguoi_thuc_hien: Optional[str] = None
    #: `None` với người không xem được tài chính của phòng.
    chi_phi: Optional[float] = None
    trang_thai: str


class TaiSanRa(BaseModel):
    id: int
    loai: Optional[str] = None
    ten: str
    thong_so: Optional[str] = None
    tinh_trang: str
    ghi_chu: Optional[str] = None


class HoSoPhongRa(BaseModel):
    room: RoomResponse
    toa: ToaRa
    xem_tai_chinh: bool
    sua_duoc: bool
    hop_dong: Optional[HopDongRa] = None
    hoa_don_gan_nhat: Optional[HoaDonRa] = None
    #: Sáu kỳ gần nhất CỦA PHÒNG (gồm cả hợp đồng cũ), mới nhất lên đầu.
    #: `hoa_don_gan_nhat` = phần tử đầu, giữ lại cho bản app cũ trong cache.
    hoa_don: list[HoaDonRa] = []
    dien_nuoc: Optional[DienNuocRa] = None
    tai_san: list[TaiSanRa] = []
    sua_chua: list[SuaChuaRa] = []
    sua_chua_ton: int = 0
    so_hop_dong_cu: int = 0


def _chu_gon(v: Optional[str]) -> Optional[str]:
    if v is None:
        return None
    return v.strip() or None


def _toi_da(v: Optional[str], n: int, ten: str) -> Optional[str]:
    v = _chu_gon(v)
    if v is not None and len(v) > n:
        raise ValueError(f"{ten} tối đa {n} ký tự")
    return v


def _ngay_iso(v: str) -> str:
    v = (v or "").strip()
    try:
        date.fromisoformat(v)
    except ValueError:
        raise ValueError("Ngày phải có dạng YYYY-MM-DD")
    return v


class SuaChuaVao(BaseModel):
    tieu_de: str
    mo_ta: Optional[str] = None
    ngay: str
    nguoi_thuc_hien: Optional[str] = None
    chi_phi: Optional[float] = None
    trang_thai: TrangThaiSuaChua = "da_xong"

    @field_validator("tieu_de")
    @classmethod
    def _tieu_de(cls, v: str) -> str:
        v = (v or "").strip()
        if not v:
            raise ValueError("Ghi rõ hỏng gì / sửa gì")
        if len(v) > 200:
            raise ValueError("Tiêu đề tối đa 200 ký tự")
        return v

    @field_validator("ngay")
    @classmethod
    def _ngay(cls, v: str) -> str:
        return _ngay_iso(v)

    @field_validator("mo_ta", "nguoi_thuc_hien")
    @classmethod
    def _gon(cls, v: Optional[str]) -> Optional[str]:
        return _chu_gon(v)

    @field_validator("chi_phi")
    @classmethod
    def _khong_am(cls, v: Optional[float]) -> Optional[float]:
        if v is not None and v < 0:
            raise ValueError("Chi phí không được âm")
        return v


class SuaChuaSua(BaseModel):
    tieu_de: Optional[str] = None
    mo_ta: Optional[str] = None
    ngay: Optional[str] = None
    nguoi_thuc_hien: Optional[str] = None
    chi_phi: Optional[float] = None
    trang_thai: Optional[TrangThaiSuaChua] = None

    @field_validator("tieu_de")
    @classmethod
    def _tieu_de(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        return SuaChuaVao._tieu_de(v)

    @field_validator("ngay")
    @classmethod
    def _ngay(cls, v: Optional[str]) -> Optional[str]:
        return None if v is None else _ngay_iso(v)

    @field_validator("mo_ta", "nguoi_thuc_hien")
    @classmethod
    def _gon(cls, v: Optional[str]) -> Optional[str]:
        return _chu_gon(v)

    @field_validator("chi_phi")
    @classmethod
    def _khong_am(cls, v: Optional[float]) -> Optional[float]:
        if v is not None and v < 0:
            raise ValueError("Chi phí không được âm")
        return v


_SLUG = re.compile(r"^[a-z_]{1,30}$")


def _loai(v: Optional[str]) -> Optional[str]:
    # Key lạ → món "khác", không 422: danh mục đồ trong phòng còn dài ra, app cũ
    # không được gãy vì gửi key server chưa biết.
    v = (v or "").strip().lower()
    return v if _SLUG.match(v) else None


class TaiSanVao(BaseModel):
    loai: Optional[str] = None
    ten: str
    thong_so: Optional[str] = None
    tinh_trang: TinhTrangTaiSan = "tot"
    ghi_chu: Optional[str] = None

    @field_validator("loai")
    @classmethod
    def _loai(cls, v: Optional[str]) -> Optional[str]:
        return _loai(v)

    @field_validator("ten")
    @classmethod
    def _ten(cls, v: str) -> str:
        v = _toi_da(v, 120, "Tên tài sản")
        if v is None:
            raise ValueError("Ghi tên tài sản (VD: Điều hòa Daikin)")
        return v

    @field_validator("thong_so")
    @classmethod
    def _thong_so(cls, v: Optional[str]) -> Optional[str]:
        return _toi_da(v, 200, "Thông số")

    @field_validator("ghi_chu")
    @classmethod
    def _ghi_chu(cls, v: Optional[str]) -> Optional[str]:
        return _chu_gon(v)


class TaiSanSua(BaseModel):
    loai: Optional[str] = None
    ten: Optional[str] = None
    thong_so: Optional[str] = None
    tinh_trang: Optional[TinhTrangTaiSan] = None
    ghi_chu: Optional[str] = None

    @field_validator("loai")
    @classmethod
    def _loai(cls, v: Optional[str]) -> Optional[str]:
        return _loai(v)

    @field_validator("ten")
    @classmethod
    def _ten(cls, v: Optional[str]) -> Optional[str]:
        return None if v is None else TaiSanVao._ten(v)

    @field_validator("thong_so")
    @classmethod
    def _thong_so(cls, v: Optional[str]) -> Optional[str]:
        return _toi_da(v, 200, "Thông số")

    @field_validator("ghi_chu")
    @classmethod
    def _ghi_chu(cls, v: Optional[str]) -> Optional[str]:
        return _chu_gon(v)


class ThanhToanVao(BaseModel):
    """PATCH: khoá không gửi giữ nguyên; gửi `null` tường minh = về "chưa khai"."""

    ngay_thanh_toan: Optional[int] = None
    hinh_thuc_thanh_toan: Optional[HinhThucThanhToan] = None
    coc_da_thu: Optional[float] = None

    @field_validator("ngay_thanh_toan")
    @classmethod
    def _ngay(cls, v: Optional[int]) -> Optional[int]:
        return kiem_ngay_thu(v)

    @field_validator("coc_da_thu")
    @classmethod
    def _coc(cls, v: Optional[float]) -> Optional[float]:
        return kiem_coc_da_thu(v)


class ThanhToanRa(BaseModel):
    ngay_thanh_toan: Optional[int] = None
    hinh_thuc_thanh_toan: Optional[str] = None
    coc_da_thu: Optional[float] = None


class HoaDonThangNayRa(BaseModel):
    invoice_id: int
    #: `True` = tháng này đã có hoá đơn từ trước, trả lại đúng hoá đơn đó.
    da_co: bool
