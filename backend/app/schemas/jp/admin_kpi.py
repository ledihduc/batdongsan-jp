"""Pydantic schemas for JP admin KPI endpoints."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class KpiResponse(BaseModel):
    """Response for GET /api/jp/admin/kpis"""

    kpis: dict
    prefecture: Optional[str]
    start: str
    end: str
    org_id: str

    class Config:
        json_schema_extra = {
            "example": {
                "kpis": {
                    "application_count": 42,
                    "success_rate": 0.714,
                    "avg_review_days": 3.2,
                    "guarantor_approval_rate": 0.9,
                    "vacancy_rate": 0.12,
                    "computed_at": "2026-10-17T10:00:00+00:00",
                },
                "prefecture": "東京都",
                "start": "2026-01-01T00:00:00+00:00",
                "end": "2026-10-17T00:00:00+00:00",
                "org_id": "org-abc-123",
            }
        }
