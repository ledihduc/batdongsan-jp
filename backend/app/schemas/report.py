"""Pydantic v2 schemas for Phase 06 reports."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class RevenueByBuilding(BaseModel):
    building_id: int
    building_name: str
    total: float


class RevenueReport(BaseModel):
    period: str  # "month" | "year"
    date: str  # e.g. "2026-07" or "2026"
    total: float
    breakdown: dict[str, float] = Field(default_factory=dict)
    by_building: list[RevenueByBuilding] = Field(default_factory=list)


class OccupancyRow(BaseModel):
    room_id: int
    room_code: str
    building_id: int
    building_name: str
    status: str
    occupied_days: int
    total_days: int
    occupied_pct: float


class OccupancyReport(BaseModel):
    month: str  # "YYYY-MM"
    by_room: list[OccupancyRow] = Field(default_factory=list)
    building_avg_pct: float = 0
    room_count: int = 0


class AdrReport(BaseModel):
    adr: Optional[float] = None
    revpar: Optional[float] = None
    occupied_nights: int = 0
    total_nights: int = 0
    note: Optional[str] = None
