"""Pydantic v2 response schemas cho analytics endpoints.

Mirrors dict shapes từ app/schemas/_analytics_shapes.md (Phase 02 schema freeze).
"""

from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


# ── Sub-models ──────────────────────────────────────────────────────────────


class PeriodInfo(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    type: str
    date: str
    start_utc: str
    end_utc: str


class KpiBlock(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    gross_revenue: float
    net_revenue: float
    refund_total: float
    commission_total: float
    occupancy_pct: float
    adr: float
    booking_pace: int


class DeltaBlock(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    gross_revenue_pct: Optional[float] = None
    net_revenue_pct: Optional[float] = None
    occupancy_pct_diff: Optional[float] = None


# ── Top-level response models ────────────────────────────────────────────────


class SummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    period: PeriodInfo
    kpis: KpiBlock
    deltas: DeltaBlock


class TrendResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    periods: list[str]
    current: list[float]
    current_net: list[float]
    prior: list[float]
    prior_net: list[float]


class HeatmapCell(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    day: int
    status: Literal["vacant", "booked", "paid", "overdue"]


class HeatmapRoomRow(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    room_id: int
    room_name: str
    building_name: str
    cells: list[HeatmapCell]


class HeatmapResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    month: str
    days: int
    rooms: list[HeatmapRoomRow]


class SourceBreakdownItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    source_id: Optional[int] = None
    source_name: str
    color_hex: str
    amount: float
    pct: float


class SourceBreakdownResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    period: str
    total: float
    items: list[SourceBreakdownItem]


class DrillItem(BaseModel):
    """Flexible drill-down item — meta dict varies per level."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    label: str
    secondary: Optional[str] = None
    meta: dict = Field(default_factory=dict)


class DrillResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    items: list[dict]  # Raw dicts from service (shape varies per level)
    total_count: int
    page: int
    page_size: int
