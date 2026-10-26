"""JP user self-service endpoints — data export and deletion (DSR).

Routes:
  GET    /api/jp/me/export               — real cross-domain data export (JSON)
  GET    /api/jp/me/data-export          — legacy ZIP export (kept for backward compat)
  POST   /api/jp/me/data-delete          — legacy deletion request (kept for compat)
  POST   /api/jp/me/schedule-deletion    — schedule account deletion (30-day grace)
  DELETE /api/jp/me/cancel-deletion      — cancel a pending deletion schedule

All routes guarded by require_region('jp').

APPI compliance notes:
  - Data export must be delivered within a reasonable time (MVP: synchronous).
  - Deletion request is soft-flagged; actual purge happens after 30 days.
  - Invoice rows are exempt from purge (7-year JP tax retention).
"""

from __future__ import annotations

import base64
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.schemas.jp.consent import DataDeleteResponse, DataExportResponse
from app.schemas.jp.dsr import (
    CancelDeletionResponse,
    DsrExportResponse,
    ScheduleDeletionResponse,
)
from app.services.consent.dsr import export_user_data, request_user_deletion
from app.services.privacy.dsr_exporter import collect as collect_dsr_data

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/me",
    tags=["jp-me"],
    dependencies=[Depends(require_region("jp"))],
)

# APPI: 30-day grace period before actual purge
_DELETION_GRACE_DAYS = 30


def _get_user_id(request: Request) -> int:
    user_id: Optional[int] = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=401, detail="user_id not found in token")
    return user_id


def _get_org_id(request: Request) -> str:
    org_id: Optional[str] = getattr(request.state, "org_id", None) or ""
    return org_id


# ── Real DSR cross-domain export ─────────────────────────────────────────────

@router.get("/export", response_model=DsrExportResponse)
async def get_real_export(
    request: Request,
    db: Session = Depends(get_db),
) -> DsrExportResponse:
    """Real cross-domain data export — profile + consents + viewings + applications + payments + listings.

    Returns structured JSON (not ZIP). Streaming is synchronous for MVP;
    move to ARQ background job for large orgs in P4.
    """
    user_id = _get_user_id(request)
    org_id = _get_org_id(request)

    try:
        data = collect_dsr_data(user_id=user_id, org_id=org_id, db=db)
    except Exception as exc:
        logger.error("DSR real export failed: user=%d err=%s", user_id, exc)
        raise HTTPException(status_code=500, detail="Export failed") from exc

    return DsrExportResponse(
        user_id=user_id,
        data=data,
        generated_at=datetime.now(timezone.utc).isoformat(),
        format_version="2.0",
    )


# ── Deletion scheduling ───────────────────────────────────────────────────────

@router.post("/schedule-deletion", response_model=ScheduleDeletionResponse)
async def schedule_deletion(
    request: Request,
    db: Session = Depends(get_db),
) -> ScheduleDeletionResponse:
    """Schedule account deletion with 30-day grace period.

    Sets users.deletion_scheduled_at = now() + 30d.
    Actual purge runs daily at 03:00 JST via deletion cron.
    Invoice rows are exempt (7-year JP tax retention).
    """
    user_id = _get_user_id(request)
    scheduled_at = datetime.now(timezone.utc) + timedelta(days=_DELETION_GRACE_DAYS)

    try:
        # Check if column exists (migration 0158 may not have run in all envs)
        result = db.execute(
            text(
                "UPDATE users SET deletion_scheduled_at = :scheduled_at "
                "WHERE id = :user_id"
            ),
            {"scheduled_at": scheduled_at, "user_id": user_id},
        )
        db.commit()

        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="User not found")

        # Mark consent rows as legal_hold to survive purge
        consent_result = db.execute(
            text(
                "UPDATE jp_user_consents SET legal_hold = TRUE WHERE user_id = :user_id"
            ),
            {"user_id": user_id},
        )
        db.commit()
        logger.info(
            "Deletion scheduled: user=%d scheduled_at=%s consent_rows_held=%d",
            user_id, scheduled_at.isoformat(), consent_result.rowcount,
        )

    except HTTPException:
        raise
    except Exception as exc:
        db.rollback()
        logger.error("Failed to schedule deletion: user=%d err=%s", user_id, exc)
        raise HTTPException(status_code=500, detail="Failed to schedule deletion") from exc

    return ScheduleDeletionResponse(
        scheduled_purge_at=scheduled_at.isoformat(),
        message=(
            f"Your account will be deleted on {scheduled_at.date().isoformat()}. "
            "Financial records (invoices) are retained for 7 years per Japanese tax law. "
            "Cancel within 30 days to stop deletion."
        ),
    )


@router.delete("/cancel-deletion", response_model=CancelDeletionResponse)
async def cancel_deletion(
    request: Request,
    db: Session = Depends(get_db),
) -> CancelDeletionResponse:
    """Cancel a pending account deletion schedule.

    Sets users.deletion_scheduled_at = NULL.
    No-op if no deletion is scheduled (returns cancelled=False).
    """
    user_id = _get_user_id(request)

    try:
        result = db.execute(
            text(
                "UPDATE users SET deletion_scheduled_at = NULL "
                "WHERE id = :user_id AND deletion_scheduled_at IS NOT NULL"
            ),
            {"user_id": user_id},
        )
        db.commit()
        cancelled = result.rowcount > 0
        logger.info("Deletion cancel: user=%d cancelled=%s", user_id, cancelled)
    except Exception as exc:
        db.rollback()
        logger.error("Failed to cancel deletion: user=%d err=%s", user_id, exc)
        raise HTTPException(status_code=500, detail="Failed to cancel deletion") from exc

    return CancelDeletionResponse(
        cancelled=cancelled,
        message=(
            "Deletion schedule cancelled successfully."
            if cancelled
            else "No pending deletion schedule found."
        ),
    )


# ── Legacy endpoints (kept for backward compatibility) ────────────────────────

@router.get("/data-export", response_model=DataExportResponse)
async def get_data_export(
    request: Request,
    db: Session = Depends(get_db),
) -> DataExportResponse:
    """Legacy ZIP export. Prefer GET /api/jp/me/export for cross-domain JSON."""
    user_id = _get_user_id(request)

    try:
        result = export_user_data(user_id=user_id, db=db)
    except Exception as exc:
        logger.error("data-export failed: user=%d err=%s", user_id, exc)
        raise HTTPException(status_code=500, detail="Export failed") from exc

    b64 = base64.b64encode(result.zip_bytes).decode("ascii")
    download_url = f"data:application/zip;base64,{b64}"

    return DataExportResponse(
        job_id=result.job_id,
        status="ready",
        expires_at=result.expires_at,
        download_url=download_url,
    )


@router.post("/data-delete", response_model=DataDeleteResponse)
async def request_data_delete(
    request: Request,
    db: Session = Depends(get_db),
) -> DataDeleteResponse:
    """Legacy deletion endpoint. Prefer POST /api/jp/me/schedule-deletion."""
    user_id = _get_user_id(request)

    try:
        result = request_user_deletion(user_id=user_id, db=db)
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("data-delete failed: user=%d err=%s", user_id, exc)
        raise HTTPException(status_code=500, detail="Deletion request failed") from exc

    return DataDeleteResponse(
        scheduled_purge_at=result.scheduled_purge_at,
        message=result.message,
    )
