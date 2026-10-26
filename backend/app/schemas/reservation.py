"""Reservation schemas (Phase 07)."""

from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

ReservationStatus = Literal[
    "pending", "approved", "rejected", "checked_in",
    "checked_out", "cancelled", "no_show",
]

ReservationSource = Literal["marketplace", "direct", "manual"]


class ReservationCreate(BaseModel):
    """Host or guest creates a reservation. Total computed server-side."""

    model_config = ConfigDict(str_strip_whitespace=True)

    room_id: int
    guest_user_id: Optional[int] = None
    guest_name: str = Field(..., min_length=1, max_length=300)
    guest_phone: str = Field(default="", max_length=50)
    guest_email: Optional[str] = None
    check_in_date: Optional[str] = None   # ISO YYYY-MM-DD inclusive
    check_out_date: Optional[str] = None  # exclusive
    booking_mode: Optional[str] = None
    check_in_at: Optional[datetime] = None
    check_out_at: Optional[datetime] = None
    quote_token: Optional[str] = None
    source: ReservationSource = "manual"
    note: Optional[str] = None
    #: Tin đăng khách bấm vào để đặt. Không bắt buộc: đặt từ trang toà của sale
    #: cũng hợp lệ. SALE thì server tự xác định — không nhận từ app, để không ai
    #: tự ghi công cho mình.
    house_id: Optional[int] = None
    #: Số người ở — không vượt sức chứa phòng (server kiểm).
    so_khach: Optional[int] = None


class ReservationStatusChange(BaseModel):
    """Approve / reject — rejection_reason required when rejecting."""

    action: Literal["approve", "reject"]
    rejection_reason: Optional[str] = None


class ReservationCancel(BaseModel):
    """Cancel — refund computed by server per cancel_policy_snapshot."""

    reason: Optional[str] = None


class ReservationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    host_id: Optional[int] = None
    room_id: int
    guest_user_id: Optional[int]
    guest_name: str
    guest_phone: str
    guest_email: Optional[str]
    check_in_date: str
    check_out_date: str
    nights: int
    total_amount: float
    deposit_paid: float
    # Policy requirement snapshot for this booking.  It is deliberately
    # distinct from ``deposit_paid`` (actual money received).
    activity_deposit_policy_version: Optional[int] = None
    activity_primary_deposit_bps: Optional[int] = None
    activity_primary_deposit_amount: Optional[float] = None
    status: ReservationStatus
    cancel_policy_snapshot: str
    cancelled_at: Optional[datetime]
    refund_amount: Optional[float]
    rejection_reason: Optional[str]
    # `str`, KHÔNG phải `ReservationSource`: đó là luật cho dữ liệu ĐI VÀO (vẫn giữ
    # ở ReservationCreate). Áp nó lên dữ liệu ĐI RA thì một dòng có nguồn lạ trong
    # DB (18/09/2026: một đơn `source='agoda'` nhập tay) làm 500 CẢ danh sách
    # đơn của chủ nhà, thay vì chỉ hiện nhãn lạ ở đúng dòng đó.
    source: str
    note: Optional[str]
    created_at: datetime
    updated_at: datetime

    booking_mode: Optional[str] = None
    booking_code: Optional[str] = None
    check_in_at: Optional[str] = None
    check_out_at: Optional[str] = None
    price_breakdown: Optional[dict] = None
    can_cancel: bool = False
    status_label: Optional[str] = None

    @field_validator("check_in_date", "check_out_date", mode="before")
    @classmethod
    def stringify_date(cls, value):
        return str(value)

    # Denormalised fields for list/detail UI (populated in service)
    room_code: Optional[str] = None
    building_name: Optional[str] = None
