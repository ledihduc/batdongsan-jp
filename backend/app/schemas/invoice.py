"""Pydantic v2 schemas for Invoice + InvoiceLineItem endpoints."""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, field_validator

InvoiceStatus = Literal["draft", "sent", "paid", "overdue", "cancelled"]
LineCategory = Literal[
    "rent", "electricity", "water", "service",
    "deposit_refund", "damage_deduction", "adjustment",
]


class InvoiceLineItemCreate(BaseModel):
    category: LineCategory
    description: str = ""
    quantity: float = 1
    unit_price: float = 0
    amount: float
    sort_order: int = 0


class InvoiceLineItemResponse(BaseModel):
    id: int
    invoice_id: int
    category: str
    description: str
    quantity: float
    unit_price: float
    amount: float
    sort_order: int

    model_config = {"from_attributes": True}


class GenerateBatchRequest(BaseModel):
    """Generate draft invoices for all active contracts in a building for a month."""
    building_id: int
    month: str  # 'YYYY-MM'
    # ĐƠN GIÁ GHI ĐÈ cho cả lô. `None` = mỗi phòng dùng giá của chính nó
    # (phòng khai riêng → toà khai chung → hằng số), xem `services/gia_tien_ich.py`.
    #
    # Trước migration 0104 hai trường này là nơi DUY NHẤT đơn giá tồn tại, với
    # hằng số cứng 3500/15000 — nên cả lô luôn dùng chung một giá và chủ nhà
    # phải gõ lại mỗi tháng. Giữ lại chúng để client cũ không gãy, nhưng mặc
    # định nay là "hỏi từng phòng" chứ không phải "áp một số cho tất cả".
    electricity_unit_price: Optional[float] = None  # VND/kWh
    water_unit_price: Optional[float] = None  # VND/m3

    @field_validator("month")
    @classmethod
    def month_format(cls, v: str) -> str:
        if len(v) != 7 or v[4] != "-":
            raise ValueError("Tháng phải đúng định dạng YYYY-MM")
        try:
            year = int(v[:4])
            month = int(v[5:])
        except ValueError as exc:
            raise ValueError("Tháng phải đúng định dạng YYYY-MM") from exc
        if not (1 <= month <= 12) or year < 2020:
            raise ValueError("Tháng không hợp lệ")
        return v


class RecordPaymentRequest(BaseModel):
    amount: float
    method: Literal["cash", "bank_transfer", "other"] = "cash"
    paid_at: Optional[datetime] = None
    note: Optional[str] = None

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Số tiền phải lớn hơn 0")
        return v


class CreditNoteCreate(BaseModel):
    amount: float
    reason: str = ""
    issued_date: str  # YYYY-MM-DD

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Số tiền phải lớn hơn 0")
        return v

    @field_validator("issued_date")
    @classmethod
    def date_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Ngày phát hành không được để trống")
        return v.strip()


class InvoiceResponse(BaseModel):
    id: int
    host_id: int
    contract_id: int
    invoice_number: str
    period_start: str
    period_end: str
    issued_date: str
    due_date: str
    status: str
    total_amount: float
    paid_amount: float
    paid_at: Optional[datetime] = None
    public_token: Optional[str] = None
    public_token_expires_at: Optional[datetime] = None
    note: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    line_items: list[InvoiceLineItemResponse] = []

    model_config = {"from_attributes": True}


class DebtAgingBucket(BaseModel):
    bucket: str  # '0-30' | '30-60' | '>60'
    count: int
    total_amount: float
    invoice_ids: list[int]


class DebtAgingResponse(BaseModel):
    buckets: list[DebtAgingBucket]
    total_unpaid: float


class NeedsReminderItem(BaseModel):
    invoice_id: int
    contract_id: int
    room_code: str
    tenant_name: str
    tenant_phone: str
    days_overdue: int
    amount_due: float


class ZaloLinkResponse(BaseModel):
    url: str
