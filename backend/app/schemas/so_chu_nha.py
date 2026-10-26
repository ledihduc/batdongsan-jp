"""Thân request của Sổ chủ nhà (`/api/host/so-chu-nha`)."""

import base64
import binascii
from typing import Literal, Optional

from pydantic import BaseModel, Field

LoaiThue = Literal["dai_han", "ngan_han"]


class PhongVao(BaseModel):
    """Màn 12 — thêm / sửa phòng."""

    ten: str = Field(min_length=1, max_length=60)
    tang: Optional[str] = Field(default=None, max_length=20)
    dien_tich: Optional[float] = None
    gia: float = Field(ge=0)
    loai_thue: LoaiThue = "dai_han"
    anh: list[str] = Field(default_factory=list, max_length=12)


class GiaHanVao(BaseModel):
    so_thang: int = Field(ge=1, le=60)


class ChiSoVao(BaseModel):
    dien_moi: float = Field(ge=0)
    #: Bỏ trống được khi nước tính theo người.
    nuoc_moi: float = Field(default=0, ge=0)
    #: Ảnh công tơ chủ nhà chụp — tuỳ chọn; có thì khách thấy ảnh này.
    anh_dien: Optional[str] = Field(default=None, max_length=500)
    anh_nuoc: Optional[str] = Field(default=None, max_length=500)


class KyVao(BaseModel):
    thang: str = Field(pattern=r"^\d{4}-\d{2}$")


class ThuTienVao(KyVao):
    hinh_thuc: Literal["tien_mat", "chuyen_khoan", "vi"] = "tien_mat"


CachTinh = Literal["don_gia", "theo_nguoi"]


class DichVuSua(BaseModel):
    gia: Optional[float] = Field(default=None, ge=0)
    ap_dung: Optional[bool] = None
    cach_tinh: Optional[CachTinh] = None


class DichVuMoi(BaseModel):
    ten: str = Field(min_length=1, max_length=200)
    gia: float = Field(ge=0)
    #: Theo đơn giá (một khoản) hoặc theo người (× số người ở). Không còn "theo lượt".
    cach_tinh: CachTinh = "don_gia"


class SoNguoiVao(BaseModel):
    #: None = bỏ khai, đếm theo người trên hợp đồng.
    so_nguoi: Optional[int] = Field(default=None, ge=1, le=50)


class NhapPhongVao(BaseModel):
    """Màn 13 — tệp Excel gửi dạng base64 (cùng cách với `/api/upload`)."""

    ten_tep: str = Field(default="phong.xlsx", max_length=200)
    du_lieu: str = Field(min_length=1, max_length=3_000_000)

    def noi_dung(self) -> bytes:
        from fastapi import HTTPException

        try:
            return base64.b64decode(self.du_lieu, validate=True)
        except (binascii.Error, ValueError):
            raise HTTPException(422, "Tệp tải lên bị hỏng")


class TangPhongVao(BaseModel):
    id: int
    tang: Optional[str] = Field(default=None, max_length=20)


class DatTangVao(BaseModel):
    """Setup tầng — gán tầng cho nhiều phòng của toà."""

    phong: list[TangPhongVao] = Field(min_length=1, max_length=500)


class TaiKhoanVao(BaseModel):
    """Tài khoản nhận tiền của toà / phòng. Bỏ trống số TK = xoá (phòng quay
    về dùng tài khoản của toà)."""

    ngan_hang_bin: str = Field(default="", max_length=10)
    so_tai_khoan: str = Field(default="", max_length=40)
    chu_tai_khoan: str = Field(default="", max_length=120)
