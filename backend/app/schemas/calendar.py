"""Calendar response schemas (Phase 07)."""

from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel

CalendarDayStatus = Literal["available", "blocked", "reserved"]


class CalendarDay(BaseModel):
    date: str  # ISO YYYY-MM-DD
    status: CalendarDayStatus
    price_per_night: float
    reservation_id: Optional[int] = None
    note: Optional[str] = None


class CalendarResponse(BaseModel):
    room_id: int
    room_code: str
    month: str  # YYYY-MM
    days: list[CalendarDay]
    base_price: float


class UnifiedCalendarRow(BaseModel):
    room_id: int
    room_code: str
    building_name: str
    days: list[CalendarDay]


class UnifiedCalendarResponse(BaseModel):
    month: str
    rows: list[UnifiedCalendarRow]
