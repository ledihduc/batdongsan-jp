"""Schema cho tin NHU CẦU (`/api/demands`).

Nguyên tắc đặt ràng buộc: **rộng ở đầu vào, chặt ở chỗ nói dối được**. Người
đang tìm nhà chưa biết chắc điều gì cả, nên gần như mọi trường đều tuỳ chọn —
ép họ điền đủ 8 ô mới cho đăng thì họ bỏ đi. Nhưng những gì kiểm được thì kiểm
thẳng tay: loại tin, khoảng ngân sách xuôi chiều, và độ dài chuỗi.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator, model_validator

# 'rent' = cần thuê · 'buy' = cần mua.
VALID_KINDS = frozenset(["rent", "buy"])
VALID_PAYMENT = frozenset(["cash", "loan"])
VALID_PURPOSE = frozenset(["live", "invest"])
VALID_STATUS = frozenset(["open", "closed"])

# Trần ngân sách: 500 tỷ. Không phải để chặn nhà đắt — mà để chặn ô nhập bị gõ
# nhầm thành 15 chữ số, thứ làm vỡ mọi biểu đồ và bộ lọc phía sau.
_MAX_BUDGET = 500_000_000_000.0


class DemandCreate(BaseModel):
    kind: str
    province_code: Optional[str] = Field(default=None, max_length=32)
    province_name: Optional[str] = Field(default=None, max_length=100)
    ward_slugs: list[str] = Field(default_factory=list)
    area_label: Optional[str] = Field(default=None, max_length=300)
    category_ids: list[int] = Field(default_factory=list)

    budget_min: Optional[float] = Field(default=None, ge=0, le=_MAX_BUDGET)
    budget_max: Optional[float] = Field(default=None, ge=0, le=_MAX_BUDGET)
    area_min: Optional[float] = Field(default=None, ge=0, le=100_000)
    bedrooms_min: Optional[int] = Field(default=None, ge=0, le=20)

    move_in_date: Optional[date] = None
    duration_months: Optional[int] = Field(default=None, ge=1, le=120)
    occupants: Optional[int] = Field(default=None, ge=1, le=50)

    payment_method: Optional[str] = None
    purpose: Optional[str] = None
    legal_ok: list[str] = Field(default_factory=list)

    needs: list[str] = Field(default_factory=list)
    note: Optional[str] = Field(default=None, max_length=2000)

    @field_validator("kind")
    @classmethod
    def _kind(cls, v: str) -> str:
        if v not in VALID_KINDS:
            raise ValueError("kind phải là 'rent' hoặc 'buy'")
        return v

    @field_validator("payment_method")
    @classmethod
    def _payment(cls, v: Optional[str]) -> Optional[str]:
        if v and v not in VALID_PAYMENT:
            raise ValueError("payment_method phải là 'cash' hoặc 'loan'")
        return v

    @field_validator("purpose")
    @classmethod
    def _purpose(cls, v: Optional[str]) -> Optional[str]:
        if v and v not in VALID_PURPOSE:
            raise ValueError("purpose phải là 'live' hoặc 'invest'")
        return v

    @field_validator("ward_slugs", "legal_ok", "needs")
    @classmethod
    def _chuoi_ngan(cls, v: list[str]) -> list[str]:
        # Cắt bớt thay vì báo lỗi: đây là chip do CHÍNH app gửi lên, người dùng
        # không gõ tay, nên lỗi ở đây gần như chắc chắn là client sai — không
        # có lý do gì để chặn cả tin đăng vì nó.
        return [s.strip()[:60] for s in v if s and s.strip()][:20]

    @field_validator("category_ids")
    @classmethod
    def _cat(cls, v: list[int]) -> list[int]:
        return [int(x) for x in v][:12]

    @model_validator(mode="after")
    def _ngan_sach_xuoi_chieu(self):
        lo, hi = self.budget_min, self.budget_max
        if lo is not None and hi is not None and lo > hi:
            raise ValueError("Ngân sách tối thiểu không được lớn hơn tối đa")
        return self


class DemandUpdate(BaseModel):
    """Chỉ hai việc người đăng thật sự làm sau khi đăng: ĐÓNG tin (đã tìm được)
    và GIA HẠN. Sửa nội dung thì đăng lại — nhu cầu là thứ ngắn hạn, giữ API
    nhỏ đáng giá hơn."""

    status: Optional[str] = None
    extend: bool = False

    @field_validator("status")
    @classmethod
    def _status(cls, v: Optional[str]) -> Optional[str]:
        if v and v not in VALID_STATUS:
            raise ValueError("status phải là 'open' hoặc 'closed'")
        return v


class DemandAuthor(BaseModel):
    """Người đăng — CHỈ trường công khai. Không SĐT, không email: liên hệ đi qua
    chat trong app."""

    id: int
    name: str
    avatar_path: Optional[str] = None


class DemandResponse(BaseModel):
    id: int
    kind: str
    province_code: Optional[str] = None
    province_name: Optional[str] = None
    ward_slugs: list[str] = Field(default_factory=list)
    area_label: Optional[str] = None
    category_ids: list[int] = Field(default_factory=list)
    category_names: list[str] = Field(default_factory=list)
    budget_min: Optional[float] = None
    budget_max: Optional[float] = None
    area_min: Optional[float] = None
    bedrooms_min: Optional[int] = None
    move_in_date: Optional[date] = None
    duration_months: Optional[int] = None
    occupants: Optional[int] = None
    payment_method: Optional[str] = None
    purpose: Optional[str] = None
    legal_ok: list[str] = Field(default_factory=list)
    needs: list[str] = Field(default_factory=list)
    note: Optional[str] = None
    status: str
    expires_at: datetime
    created_at: datetime
    author: Optional[DemandAuthor] = None
