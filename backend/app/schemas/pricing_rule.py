"""Pricing rule schemas (Phase 07).

Priority resolution at a given date: highest rule.priority wins. Defaults
applied by service if priority omitted:
    base 100, weekend 200, holiday 500, manual 1000.

weekday_mask: bit per day, Mon=0 .. Sun=6. Default weekend = 0b1100000 (Fri+Sat).
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

RuleType = Literal["base", "weekend", "holiday", "manual"]


class PricingRuleCreate(BaseModel):
    room_id: Optional[int] = None
    house_id: Optional[int] = None
    rule_type: RuleType
    start_date: str
    end_date: str
    price_per_night: float = Field(..., ge=0)
    priority: Optional[int] = None
    weekday_mask: Optional[int] = None
    holiday_name: Optional[str] = None


class PricingRuleUpdate(BaseModel):
    rule_type: Optional[RuleType] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    price_per_night: Optional[float] = Field(None, ge=0)
    priority: Optional[int] = None
    weekday_mask: Optional[int] = None
    holiday_name: Optional[str] = None


class PricingRuleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    host_id: int
    room_id: Optional[int]
    house_id: Optional[int]
    rule_type: RuleType
    start_date: str
    end_date: str
    price_per_night: float
    priority: int
    weekday_mask: Optional[int]
    holiday_name: Optional[str]
    created_at: datetime
    updated_at: datetime
