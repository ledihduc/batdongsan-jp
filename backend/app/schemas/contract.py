"""Pydantic v2 schemas for Contract endpoints."""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, field_validator

from app.schemas.tenant import TenantCreate, TenantResponse

ContractStatus = Literal["draft", "active", "expired", "terminated"]
HinhThucThanhToan = Literal["chuyen_khoan", "tien_mat", "ca_hai"]


def kiem_ngay_thu(v: Optional[int]) -> Optional[int]:
    """Ngày thu tiền hàng tháng. 29-31 hợp lệ: tháng thiếu ngày thì thu ngày cuối."""
    if v is not None and not 1 <= v <= 31:
        raise ValueError("Ngày thu tiền phải từ 1 đến 31")
    return v


def kiem_coc_da_thu(v: Optional[float]) -> Optional[float]:
    if v is not None and v < 0:
        raise ValueError("Tiền cọc đã thu không được âm")
    return v


class ContractCreate(BaseModel):
    room_id: int
    start_date: str  # YYYY-MM-DD
    end_date: str
    monthly_rent: float
    deposit: float = 0
    handover_photos: list[str] = []
    # Embedded tenant array — at least 1 required, exactly 1 is_primary
    tenants: list[TenantCreate]
    # Kỳ thanh toán + cọc đã thu (migration 0108). Không bắt buộc — app cũ
    # trong cache không gửi. NULL = chưa khai, KHÔNG phải "chưa thu".
    ngay_thanh_toan: Optional[int] = None
    hinh_thuc_thanh_toan: Optional[HinhThucThanhToan] = None
    coc_da_thu: Optional[float] = None

    @field_validator("monthly_rent")
    @classmethod
    def rent_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Tiền thuê phải lớn hơn 0")
        return v

    @field_validator("deposit")
    @classmethod
    def deposit_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Tiền đặt cọc không được âm")
        return v

    @field_validator("tenants")
    @classmethod
    def tenants_valid(cls, v: list[TenantCreate]) -> list[TenantCreate]:
        if not v:
            raise ValueError("Hợp đồng phải có ít nhất 1 người thuê")
        primary_count = sum(1 for t in v if t.is_primary)
        if primary_count != 1:
            raise ValueError("Hợp đồng phải có đúng 1 người thuê chính (is_primary=true)")
        return v

    @field_validator("start_date", "end_date")
    @classmethod
    def date_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Ngày không được để trống")
        return v.strip()

    @field_validator("ngay_thanh_toan")
    @classmethod
    def ngay_thu_hop_le(cls, v: Optional[int]) -> Optional[int]:
        return kiem_ngay_thu(v)

    @field_validator("coc_da_thu")
    @classmethod
    def coc_da_thu_khong_am(cls, v: Optional[float]) -> Optional[float]:
        return kiem_coc_da_thu(v)


class ContractUpdate(BaseModel):
    """Partial update for draft contracts — no status change allowed here."""
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    monthly_rent: Optional[float] = None
    deposit: Optional[float] = None
    handover_photos: Optional[list[str]] = None


class TerminateContractRequest(BaseModel):
    actual_end_date: str  # YYYY-MM-DD
    deposit_refund_amount: float = 0
    damage_note: Optional[str] = None
    damage_photos: list[str] = []

    @field_validator("actual_end_date")
    @classmethod
    def date_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Ngày trả phòng thực tế không được để trống")
        return v.strip()

    @field_validator("deposit_refund_amount")
    @classmethod
    def refund_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Số tiền hoàn cọc không được âm")
        return v


class TransferRoomRequest(BaseModel):
    new_room_id: int


class BatchRenewRequest(BaseModel):
    contract_ids: list[int]
    new_end_date: str

    @field_validator("contract_ids")
    @classmethod
    def ids_not_empty(cls, v: list[int]) -> list[int]:
        if not v:
            raise ValueError("Phải chọn ít nhất 1 hợp đồng")
        return v

    @field_validator("new_end_date")
    @classmethod
    def date_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Ngày gia hạn không được để trống")
        return v.strip()


class ContractTenantResponse(BaseModel):
    tenant: TenantResponse
    is_primary: bool
    joined_at: Optional[str] = None
    left_at: Optional[str] = None

    model_config = {"from_attributes": True}


class ContractResponse(BaseModel):
    id: int
    host_id: int
    room_id: int
    start_date: str
    end_date: str
    monthly_rent: float
    deposit: float
    status: str
    terminated_at: Optional[str] = None
    actual_end_date: Optional[str] = None
    deposit_refund_amount: Optional[float] = None
    damage_note: Optional[str] = None
    damage_photos: list[str] = []
    handover_photos: list[str] = []
    ngay_thanh_toan: Optional[int] = None
    hinh_thuc_thanh_toan: Optional[str] = None
    coc_da_thu: Optional[float] = None
    created_at: datetime
    updated_at: datetime
    # Enriched — populated by router/service
    tenants: list[ContractTenantResponse] = []

    model_config = {"from_attributes": True}


class BatchRenewResponse(BaseModel):
    renewed_count: int
    contract_ids: list[int]
