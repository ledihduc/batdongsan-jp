"""Pydantic schemas for JP viewing (内見) requests.

Validators enforce:
  - requested_slots: 1-3 entries, valid ISO 8601 strings
  - lead_time: each slot must be ≥24h from now (validated at service layer,
    schema only checks format and count)
  - Business hours validation deferred to service layer (needs JST context)
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator

from app.domain.jp.viewing import VIEWING_STATUS_VALUES


class JpViewingCreate(BaseModel):
    """Request body for a tenant to request a viewing."""

    listing_id: str = Field(..., min_length=1, description="Target listing UUID")
    requested_slots: list[str] = Field(
        ...,
        min_length=1,
        max_length=3,
        description="ISO 8601 datetime strings for preferred viewing slots. Max 3.",
    )
    notes: Optional[str] = Field(None, max_length=1000)

    @field_validator("requested_slots")
    @classmethod
    def validate_slots(cls, v: list[str]) -> list[str]:
        """Validate slot count (1-3) and that each is a parseable ISO timestamp."""
        if not 1 <= len(v) <= 3:
            raise ValueError("requested_slots must contain 1-3 entries")
        for slot in v:
            try:
                datetime.fromisoformat(slot.replace("Z", "+00:00"))
            except (ValueError, AttributeError) as exc:
                raise ValueError(
                    f"Invalid slot timestamp '{slot}'. Must be ISO 8601 format."
                ) from exc
        return v


class JpViewingConfirmRequest(BaseModel):
    """Request body for agent to confirm one of the requested slots."""

    confirmed_slot_ts: str = Field(
        ..., description="ISO 8601 datetime of the confirmed slot (must be in requested_slots)"
    )

    @field_validator("confirmed_slot_ts")
    @classmethod
    def validate_slot_ts(cls, v: str) -> str:
        try:
            datetime.fromisoformat(v.replace("Z", "+00:00"))
        except (ValueError, AttributeError) as exc:
            raise ValueError(f"Invalid confirmed_slot_ts: must be ISO 8601") from exc
        return v


class JpViewingCancelRequest(BaseModel):
    """Request body for cancelling a viewing."""

    reason: Optional[str] = Field(None, max_length=500)


class JpViewingResponse(BaseModel):
    """Response schema for a viewing record."""

    id: int
    org_id: Optional[str]
    listing_id: str
    tenant_id: int
    agent_id: Optional[int]
    requested_slots: list[str]
    confirmed_slot_ts: Optional[datetime]
    status: str
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
