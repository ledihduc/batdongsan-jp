"""JP admin KPI endpoint.

Route:
  GET /api/jp/admin/kpis?prefecture=...&start=...&end=...

Returns 5 metrics:
  - application_count
  - success_rate
  - avg_review_days
  - guarantor_approval_rate
  - vacancy_rate

Requires: admin role (enforced via require_role_scope).
All routes guarded by require_region('jp').
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.schemas.jp.admin_kpi import KpiResponse
from app.services.admin_kpi.queries import compute_all_kpis

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/admin",
    tags=["jp-admin"],
    dependencies=[Depends(require_region("jp"))],
)

# Default period: last 30 days
_DEFAULT_PERIOD_DAYS = 30


@router.get("/kpis", response_model=KpiResponse)
async def get_kpis(
    request: Request,
    prefecture: Optional[str] = Query(None, description="JP prefecture filter (e.g. '東京都')"),
    start: Optional[str] = Query(None, description="Period start ISO datetime (UTC)"),
    end: Optional[str] = Query(None, description="Period end ISO datetime (UTC)"),
    db: Session = Depends(get_db),
) -> KpiResponse:
    """Return 5 JP market KPIs filtered by prefecture and date range.

    Admin role required. Org-scoped — admin cannot cross org boundaries.
    """
    # Role enforcement — admin only
    actual_role: Optional[str] = getattr(request.state, "role", None)
    if actual_role != "admin":
        raise HTTPException(status_code=403, detail="admin role required")

    org_id: Optional[str] = getattr(request.state, "org_id", None)
    if not org_id:
        raise HTTPException(status_code=401, detail="org_id not found in token")

    # Parse date range
    now = datetime.now(timezone.utc)
    try:
        start_dt = datetime.fromisoformat(start) if start else now - timedelta(days=_DEFAULT_PERIOD_DAYS)
        end_dt = datetime.fromisoformat(end) if end else now
    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid date format: {exc}. Use ISO 8601 (e.g. 2026-01-01T00:00:00Z)",
        ) from exc

    if start_dt >= end_dt:
        raise HTTPException(status_code=422, detail="start must be before end")

    try:
        kpis = compute_all_kpis(
            db,
            org_id=org_id,
            prefecture=prefecture,
            start=start_dt,
            end=end_dt,
        )
    except Exception as exc:
        logger.error("KPI computation failed: org=%s err=%s", org_id, exc)
        raise HTTPException(status_code=500, detail="KPI computation failed") from exc

    return KpiResponse(
        kpis=kpis,
        prefecture=prefecture,
        start=start_dt.isoformat(),
        end=end_dt.isoformat(),
        org_id=org_id,
    )
