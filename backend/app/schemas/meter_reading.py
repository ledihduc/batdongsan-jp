"""Pydantic v2 schemas for MeterReading endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, field_validator


class MeterReadingCreate(BaseModel):
    room_id: int
    reading_date: str  # YYYY-MM-DD
    electricity_kwh: float = 0
    water_m3: float = 0
    note: Optional[str] = None

    @field_validator("reading_date")
    @classmethod
    def date_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Ngày đọc số không được để trống")
        return v.strip()

    @field_validator("electricity_kwh", "water_m3")
    @classmethod
    def non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Chỉ số không được âm")
        return v


class MeterReadingBatchCreate(BaseModel):
    """Batch input: multiple rooms in one request."""
    reading_date: str
    readings: list[MeterReadingCreate]

    @field_validator("readings")
    @classmethod
    def readings_not_empty(cls, v: list) -> list:
        if not v:
            raise ValueError("Phải có ít nhất 1 chỉ số")
        return v


class MeterReadingResponse(BaseModel):
    id: int
    host_id: int
    room_id: int
    reading_date: str
    electricity_kwh: float
    water_m3: float
    note: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
