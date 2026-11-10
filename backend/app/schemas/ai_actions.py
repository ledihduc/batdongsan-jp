"""Schema xem trước / xác nhận action ghi AI (plan 20261027-1102 Phase 09, F-4, F-5, F-6)."""

from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel


class AiPendingListing(BaseModel):
    listing_id: int
    title: str
    price: Optional[int] = None
    currency: Optional[str] = None
    layout: Optional[str] = None


class AiPendingPreview(BaseModel):
    action: str
    title: str
    description: str
    params: dict
    listing: Optional[AiPendingListing] = None
    status: str
    expires_at: datetime
    owner_bound: bool


class AiConfirmResult(BaseModel):
    status: Literal["executed"]
    action: str
    result: dict


class AiPendingActionOut(BaseModel):
    """Thẻ xác nhận trả kèm câu chat; token chỉ đi tới app, không qua model."""

    token: str
    action: str
    title: str
    params: dict
    expires_at: datetime
