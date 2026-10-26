"""Pydantic v2 schemas for Tenant endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, field_validator


class TenantCreate(BaseModel):
    full_name: str
    phone: str = ""
    email: Optional[str] = None
    birthday: Optional[str] = None
    address_origin: Optional[str] = None
    # Số CCCD/CMND — không lưu nguyên: bcrypt hash + 3 số cuối (migration 0108).
    # Form hợp đồng gửi khoá này từ lâu mà schema không nhận, số bị bỏ rơi.
    cccd_number: Optional[str] = None
    # is_primary is used only in ContractCreate embedded list
    is_primary: bool = False

    @field_validator("full_name")
    @classmethod
    def name_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Họ tên không được để trống")
        return v.strip()

    @field_validator("cccd_number")
    @classmethod
    def cccd_chi_chu_so(cls, v: Optional[str]) -> Optional[str]:
        so = "".join(ch for ch in (v or "") if ch.isdigit())
        if not so:
            return None
        if len(so) not in (9, 12):
            raise ValueError("Số CCCD phải có 12 chữ số (CMND cũ 9 chữ số)")
        return so


class TenantUpdate(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    birthday: Optional[str] = None
    address_origin: Optional[str] = None


class TenantResponse(BaseModel):
    id: int
    host_id: int
    full_name: str
    phone: str
    email: Optional[str] = None
    birthday: Optional[str] = None
    address_origin: Optional[str] = None
    # CCCD paths never exposed — only upload booleans
    cccd_front_uploaded: bool = False
    cccd_back_uploaded: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_safe(cls, tenant: object) -> "TenantResponse":
        return cls(
            id=tenant.id,  # type: ignore[attr-defined]
            host_id=tenant.host_id,  # type: ignore[attr-defined]
            full_name=tenant.full_name,  # type: ignore[attr-defined]
            phone=tenant.phone,  # type: ignore[attr-defined]
            email=tenant.email,  # type: ignore[attr-defined]
            birthday=tenant.birthday,  # type: ignore[attr-defined]
            address_origin=tenant.address_origin,  # type: ignore[attr-defined]
            cccd_front_uploaded=bool(tenant.cccd_front_path),  # type: ignore[attr-defined]
            cccd_back_uploaded=bool(tenant.cccd_back_path),  # type: ignore[attr-defined]
            created_at=tenant.created_at,  # type: ignore[attr-defined]
        )
