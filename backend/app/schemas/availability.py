"""Per-day availability schemas (Phase 07)."""

from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict

AvailabilityStatus = Literal["available", "blocked", "reserved"]


class AvailabilityBlockRequest(BaseModel):
    """Block/unblock a date range for a room."""

    room_id: int
    start_date: str  # ISO YYYY-MM-DD inclusive
    end_date: str    # inclusive
    action: Literal["block", "unblock"]
    note: Optional[str] = None


class AvailabilityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    host_id: int
    room_id: int
    date: str
    status: AvailabilityStatus
    reservation_id: Optional[int] = None
    note: Optional[str] = None
    created_at: datetime
    updated_at: datetime
