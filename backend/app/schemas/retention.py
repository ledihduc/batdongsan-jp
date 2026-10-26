"""Pydantic schemas for admin retention endpoints — Phase 06.

AC coverage:
  AC-59: PDPL Right-of-Deletion request + processing
  §10.5: 4-tier retention status + manual tier override
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Retention status (GET /api/admin/retention/status)
# ---------------------------------------------------------------------------


class RetentionStatsResponse(BaseModel):
    """Admin view of retention tier distribution in change_logs."""

    tier_distribution: dict[str, int] = Field(
        description="Map of retention_tier → row count",
        default_factory=dict,
    )
    last_run_at: Optional[str] = Field(
        default=None,
        description="ISO timestamp of last daily retention job run",
    )


# ---------------------------------------------------------------------------
# Manual transition trigger (POST /api/admin/retention/run-now)
# ---------------------------------------------------------------------------


class RetentionRunResponse(BaseModel):
    """Response from manual retention job trigger."""

    run_at: str
    tier_d_purged: int = 0
    tier_c_redacted: int = 0
    tier_b_cold_archived: int = 0
    tier_b_cold_purged: int = 0
    tier_a_cold_marked: int = 0
    errors: list[str] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Archive batch trigger (POST /api/admin/retention/archive-delegations)
# ---------------------------------------------------------------------------


class ArchiveBatchResponse(BaseModel):
    """Response from manual delegation archive batch."""

    checked: int = 0
    archived: int = 0
    skipped: int = 0
