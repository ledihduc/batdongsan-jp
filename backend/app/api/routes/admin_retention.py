"""Admin retention management API routes — Phase 06.

Endpoints:
  GET  /api/admin/retention/status                     — tier distribution stats
  POST /api/admin/retention/run-now                    — manual trigger daily transitions
  POST /api/admin/retention/archive-delegations        — manual archive batch trigger

Security: all endpoints require admin role.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app import auth
from app.database import get_db
from app.schemas.retention import ArchiveBatchResponse, RetentionRunResponse, RetentionStatsResponse
from app.services.retention import ArchiveService, PdplTierService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/retention", tags=["admin_retention"])


@router.get(
    "/status",
    response_model=RetentionStatsResponse,
    summary="Admin: view retention tier distribution (§10.5)",
)
def retention_status(
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
) -> RetentionStatsResponse:
    """Return retention tier distribution across change_logs.

    Falls back to empty dict if change_logs is unavailable.
    """
    svc = PdplTierService(db)
    stats = svc.get_retention_stats()
    return RetentionStatsResponse(tier_distribution=stats)


@router.post(
    "/run-now",
    response_model=RetentionRunResponse,
    summary="Admin: manually trigger PDPL retention transitions (§10.5 cron override)",
    status_code=status.HTTP_200_OK,
)
def run_retention_now(
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
) -> RetentionRunResponse:
    """Manually trigger the daily PDPL retention transitions.

    Use this when the cron job has not run (R4 risk mitigation) or for testing.
    Operations are idempotent — running multiple times on the same day is safe.
    """
    svc = PdplTierService(db)
    results = svc.run_daily_transitions()
    return RetentionRunResponse(**results)


@router.post(
    "/archive-delegations",
    response_model=ArchiveBatchResponse,
    summary="Admin: manually archive terminated delegations batch (AC-44)",
    status_code=status.HTTP_200_OK,
)
def run_archive_batch(
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
) -> ArchiveBatchResponse:
    """Manually trigger the 30-day delegation archive batch.

    Archives terminated delegations where terminated_at < now - 30d.
    Idempotent — already-archived delegations are skipped.
    """
    svc = ArchiveService(db)
    results = svc.run_archive_batch()
    return ArchiveBatchResponse(**results)
