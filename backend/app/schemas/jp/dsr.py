"""Pydantic schemas for real DSR export and deletion scheduling endpoints."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel


class DsrExportResponse(BaseModel):
    """GET /api/jp/me/export — real cross-domain JSON export."""

    user_id: int
    data: dict
    generated_at: str
    format_version: str = "2.0"


class ScheduleDeletionResponse(BaseModel):
    """POST /api/jp/me/schedule-deletion"""

    scheduled_purge_at: str
    message: str


class CancelDeletionResponse(BaseModel):
    """DELETE /api/jp/me/cancel-deletion"""

    cancelled: bool
    message: str
