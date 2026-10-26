"""Schema cho cụm DỊCH VỤ (`/api/services`)."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator

# Vòng đời của một yêu cầu. `spam` để admin dọn rác mà vẫn giữ bản ghi.
VALID_STATUS = frozenset(
    ["new", "contacted", "scheduled", "done", "cancelled", "spam"]
)


class ServiceItem(BaseModel):
    slug: str
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None


class ServiceRequestCreate(BaseModel):
    service_slug: str = Field(..., max_length=40)
    name: str = Field(..., min_length=1, max_length=200)
    phone: str = Field(..., max_length=50)
    area: Optional[str] = Field(default=None, max_length=200)
    budget: Optional[str] = Field(default=None, max_length=100)
    description: Optional[str] = Field(default=None, max_length=4000)
    images: list[str] = Field(default_factory=list)
    province_code: Optional[str] = Field(default=None, max_length=32)
    location_text: Optional[str] = Field(default=None, max_length=200)
    lat: Optional[float] = None
    lng: Optional[float] = None


class ServiceRequestUpdate(BaseModel):
    """Chỉ những gì admin thật sự làm: đổi trạng thái, xếp lịch, ghi chú."""

    status: Optional[str] = None
    scheduled_at: Optional[datetime] = None
    admin_note: Optional[str] = Field(default=None, max_length=4000)

    @field_validator("status")
    @classmethod
    def _status(cls, v: Optional[str]) -> Optional[str]:
        if v and v not in VALID_STATUS:
            raise ValueError("Trạng thái không hợp lệ")
        return v


class ServiceRequestPublic(BaseModel):
    """Phản hồi cho KHÁCH sau khi gửi — cố ý KHÔNG có tên/SĐT.

    Khách vãng lai gửi được nên phản hồi này không có gì bảo vệ; trả lại thông
    tin cá nhân ở đây là tự mở một đường đọc dữ liệu người khác chỉ bằng cách
    đoán id.
    """

    id: int
    service_slug: str
    status: str
    created_at: datetime


class ServiceRequestAdmin(ServiceRequestPublic):
    """Bản ĐẦY ĐỦ cho admin — có SĐT để gọi lại."""

    service_name: Optional[str] = None
    name: str
    phone: str
    area: Optional[str] = None
    budget: Optional[str] = None
    description: Optional[str] = None
    province_code: Optional[str] = None
    location_text: Optional[str] = None
    scheduled_at: Optional[datetime] = None
    contacted_at: Optional[datetime] = None
    admin_note: Optional[str] = None
    source: str = "app"
