"""Khai báo tạm trú schemas — request/response shapes for host + public endpoints.

Status values stay in sync with model + check constraint:
    pending | declared | overdue | skipped
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

# Computed status — what the API returns. Persisted column may lag until next read.
KhaiBaoStatus = Literal["pending", "declared", "overdue", "skipped"]


class KhaiBaoCreate(BaseModel):
    """Manual create — rare; auto-created from Contract trigger usually."""

    tenant_id: int
    contract_id: Optional[int] = None
    check_in_at: datetime


class KhaiBaoMarkDeclared(BaseModel):
    """Mark a record as declared. declared_at defaults to now if not provided."""

    declared_at: Optional[datetime] = None


class KhaiBaoMarkSkipped(BaseModel):
    """Mark a record as skipped — host opted out (e.g., guest moved out early)."""

    reason: str = Field(..., min_length=1, max_length=500)


class KhaiBaoResponse(BaseModel):
    """Full record + denormalised tenant/contract bits for list/detail UI."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    host_id: int
    tenant_id: int
    contract_id: Optional[int]
    reservation_id: Optional[int]
    check_in_at: datetime
    declared_at: Optional[datetime]
    status: KhaiBaoStatus
    skip_reason: Optional[str]
    public_token: str
    public_token_expires_at: datetime
    created_at: datetime
    updated_at: datetime

    # Denormalised fields populated by router (not from ORM directly)
    tenant_name: Optional[str] = None
    tenant_phone: Optional[str] = None
    room_code: Optional[str] = None
    building_name: Optional[str] = None
    # Seconds remaining until 12h deadline — negative if overdue
    deadline_seconds_remaining: Optional[int] = None


class KhaiBaoDashboardSummary(BaseModel):
    """Counts shown in host_home banner + counter."""

    pending: int
    overdue: int
    declared: int
    skipped: int
