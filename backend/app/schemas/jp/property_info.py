"""Pydantic schemas for JP property physical attributes (間取り/面積/築年数/構造/向き)."""

from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field, field_validator

from app.domain.jp.property_info import LAYOUT_VALUES, ORIENTATION_VALUES, STRUCTURE_VALUES


class JpPropertyInfoCreate(BaseModel):
    """Request body for creating JP property info."""

    layout: Optional[str] = Field(
        None,
        description=f"間取り. One of: {', '.join(LAYOUT_VALUES)}",
    )
    floor_area_sqm: Optional[Decimal] = Field(
        None, gt=0, description="専有面積 in m². Must be positive."
    )
    building_year: Optional[int] = Field(
        None, ge=1900, le=2100,
        description="築年 (construction year). 1900-2100 range.",
    )
    structure: Optional[str] = Field(
        None,
        description=f"構造. One of: {', '.join(STRUCTURE_VALUES)}",
    )
    floor_number: Optional[int] = Field(
        None, ge=-5, le=100,
        description="Unit floor number. Negative for basement (地下). -5 to 100.",
    )
    orientation: Optional[str] = Field(
        None,
        description=f"向き (orientation). One of: {', '.join(ORIENTATION_VALUES)}",
    )
    available_from: Optional[date] = Field(
        None, description="入居可能日. Null = currently occupied."
    )

    @field_validator("layout")
    @classmethod
    def validate_layout(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in LAYOUT_VALUES:
            raise ValueError(f"layout must be one of: {', '.join(LAYOUT_VALUES)}")
        return v

    @field_validator("structure")
    @classmethod
    def validate_structure(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in STRUCTURE_VALUES:
            raise ValueError(f"structure must be one of: {', '.join(STRUCTURE_VALUES)}")
        return v

    @field_validator("orientation")
    @classmethod
    def validate_orientation(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in ORIENTATION_VALUES:
            raise ValueError(f"orientation must be one of: {', '.join(ORIENTATION_VALUES)}")
        return v


class JpPropertyInfoUpdate(JpPropertyInfoCreate):
    """Partial update — all fields optional (same validators apply)."""


class JpPropertyInfoResponse(BaseModel):
    """Response schema for JP property info."""

    id: int
    org_id: Optional[str]
    layout: Optional[str]
    floor_area_sqm: Optional[Decimal]
    building_year: Optional[int]
    structure: Optional[str]
    floor_number: Optional[int]
    orientation: Optional[str]
    available_from: Optional[date]

    model_config = {"from_attributes": True}
