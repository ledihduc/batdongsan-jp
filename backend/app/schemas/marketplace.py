"""Phase 08 — marketplace ↔ ops integration schemas."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class PublishRoomRequest(BaseModel):
    """Optional override fields when publishing a Room to marketplace."""

    title: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    product_type: Optional[str] = None  # 'boarding_house' | 'homestay'


class PublishRoomResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    house_id: int
    room_id: int
    product_type: str
    status: str  # House.status ('pending' | 'approved' | 'hidden')
    last_synced_at: Optional[datetime] = None
    created: bool  # True if House was created on this call, False if updated


class SyncStatusItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    room_id: int
    room_code: str
    building_id: int
    building_name: str
    is_listed: bool
    house_id: Optional[int]
    house_status: Optional[str]
    last_synced_at: Optional[datetime]
    out_of_sync: bool  # True if Room.base_price differs from House.price


class CreateContractFromApptResponse(BaseModel):
    contract_id: int
    tenant_id: int
    placeholder_tenant: bool
    room_id: int


class ApproveReservationFromBookingResponse(BaseModel):
    reservation_id: int
    status: str
    source: str
