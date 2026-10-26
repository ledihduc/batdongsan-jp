"""Pydantic v2 schemas for ServiceFee + ContractServiceFee endpoints."""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, field_validator

BillingCycle = Literal["monthly", "one_time"]


class ServiceFeeCreate(BaseModel):
    building_id: int
    name: str
    unit_price: float = 0
    billing_cycle: BillingCycle = "monthly"

    @field_validator("name")
    @classmethod
    def name_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Tên dịch vụ không được để trống")
        return v.strip()

    @field_validator("unit_price")
    @classmethod
    def price_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Đơn giá không được âm")
        return v


class ServiceFeeUpdate(BaseModel):
    name: Optional[str] = None
    unit_price: Optional[float] = None
    billing_cycle: Optional[BillingCycle] = None
    is_active: Optional[bool] = None


class ServiceFeeResponse(BaseModel):
    id: int
    host_id: int
    building_id: int
    name: str
    unit_price: float
    billing_cycle: str
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class AttachServiceFeeRequest(BaseModel):
    """Attach a ServiceFee to a Contract with snapshotted monthly_amount."""
    service_fee_id: int
    monthly_amount: float

    @field_validator("monthly_amount")
    @classmethod
    def amount_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Số tiền không được âm")
        return v


class ContractServiceFeeResponse(BaseModel):
    contract_id: int
    service_fee_id: int
    monthly_amount: float
    service_fee_name: Optional[str] = None

    model_config = {"from_attributes": True}
