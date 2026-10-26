"""Pydantic v2 schemas for Building endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, field_validator


class BuildingCreate(BaseModel):
    name: str
    address: str = ""
    city: str = ""
    district: str = ""
    ward: str = ""
    note: Optional[str] = None

    @field_validator("name")
    @classmethod
    def name_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Tên tòa nhà không được để trống")
        return v.strip()


class BuildingUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    district: Optional[str] = None
    ward: Optional[str] = None
    note: Optional[str] = None

    # Giá tiện ích MẶC ĐỊNH cho mọi phòng chưa khai riêng (migration 0104).
    # `None` ở đây = "không đổi" (schema update), không phải "xoá giá" — muốn
    # bỏ giá toà thì chưa có đường, và cố ý: hạ giá về 0 mới là điều người ta
    # thực sự muốn nói.
    gia_dien: Optional[float] = None
    gia_nuoc: Optional[float] = None
    phi_dich_vu: Optional[float] = None

    @field_validator("gia_dien", "gia_nuoc", "phi_dich_vu")
    @classmethod
    def _gia_khong_am(cls, v: Optional[float]) -> Optional[float]:
        if v is not None and v < 0:
            raise ValueError("Giá không được âm")
        return v

    @field_validator("name")
    @classmethod
    def name_not_empty(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and not v.strip():
            raise ValueError("Tên tòa nhà không được để trống")
        return v.strip() if v else v


class BuildingResponse(BaseModel):
    id: int
    host_id: int
    sale_id: Optional[int] = None
    name: str
    address: str
    city: str
    district: str
    ward: str
    note: Optional[str] = None
    # Mã bàn giao cho chủ nhà. Chỉ trả cho người đang đứng tên toà — endpoint
    # công khai dùng schema khác, không có trường này.
    gia_dien: Optional[float] = None
    gia_nuoc: Optional[float] = None
    phi_dich_vu: Optional[float] = None

    claim_code: Optional[str] = None
    claimed_at: Optional[datetime] = None

    # Số liệu tóm tắt để thẻ dự án nói được điều gì đó. Danh sách chỉ có tên và
    # địa chỉ thì mười dự án nhìn như nhau, không lướt được.
    # Mặc định 0 vì endpoint tạo/sửa trả về một toà vừa ghi, chưa đếm.
    so_phong: int = 0
    so_phong_trong: int = 0

    # Ảnh phòng đầu tiên, dùng làm bìa thẻ dự án. Không có bìa thì mọi thẻ nhìn
    # y hệt nhau và danh sách không lướt được.
    anh_bia: Optional[str] = None

    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
