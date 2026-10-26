"""Pydantic schemas for JP transit access (station data + listing associations)."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field, field_validator


class TransitAccessCreate(BaseModel):
    """Request body for associating a listing with a station."""

    station_id: int = Field(..., description="jp_stations.id reference")
    walk_min: int = Field(
        ..., ge=1, le=60,
        description="徒歩分数 (walk minutes) from listing to station. 1-60.",
    )


class TransitAccessResponse(BaseModel):
    """Response schema for a single transit access record."""

    id: int
    listing_id: str
    station_id: int
    walk_min: int
    station_name_ja: Optional[str] = None  # Populated by service layer join
    line_name_ja: Optional[str] = None     # Populated by service layer join

    model_config = {"from_attributes": True}


class StationResponse(BaseModel):
    """Response schema for station search results."""

    id: int
    name_ja: str
    name_en: Optional[str]
    prefecture: Optional[str]
    line_id: Optional[int]
    line_name_ja: Optional[str] = None  # Populated by join

    model_config = {"from_attributes": True}


class TrainLineResponse(BaseModel):
    """Response schema for train line reference data."""

    id: int
    name_ja: str
    name_en: Optional[str]
    operator: Optional[str]

    model_config = {"from_attributes": True}
