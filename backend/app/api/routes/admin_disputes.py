"""Admin dispute management endpoints — Phase 10 (AC-63).

Endpoints:
  POST /api/admin/disputes/{id}/escalate
      — mark a tenant unauthorized-operator report for priority manual review.

  POST /api/admin/disputes/{id}/resolve
      — admin closes dispute with verdict + optional delegation pause.

Background:
  AC-63: tenant can report unauthorized operator activity.
  Admin has 48h SLA to review each report (TenantAuthorityFlag).
  On resolution with outcome='prima_facie_valid' + action='pause_delegation':
    the correlated delegation (if any) is immediately paused for 'disputed_authority'.

Dispute model: tenant_authority_flags table (app.domain.tenant_authority.TenantAuthorityFlag).
No new table — uses status field extensions:
  pending → escalated → valid | invalid

Security: all endpoints require role=admin (app.auth.require_admin).
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from sqlalchemy.orm import Session

from app.auth import require_admin
from app.database import get_db
from app.schemas.admin import (
    DisputeEscalateRequest,
    DisputeEscalateResponse,
    DisputeResolveRequest,
    DisputeResolveResponse,
)
from app.services.admin.admin_dispute_service import AdminDisputeService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["admin_disputes"])


# ---------------------------------------------------------------------------
# GET /api/admin/disputes  (list view helper — not in phase spec as separate route
# but useful for ops; included as read-only companion to write endpoints)
# ---------------------------------------------------------------------------


@router.get(
    "/disputes",
    summary="Admin: list tenant unauthorized-operator reports (AC-63 queue)",
)
def list_disputes(
    status_filter: Optional[str] = Query(None, alias="status"),
    claims: dict = Depends(require_admin),
    db: Session = Depends(get_db),
) -> list[dict]:
    """Return tenant authority flags (AC-63 dispute queue).

    Filter by status: pending | escalated | valid | invalid
    Results ordered by created_at ascending (FIFO — oldest-first for 48h SLA).
    """
    svc = AdminDisputeService(db)
    flags = svc.list_disputes(status=status_filter)

    return [
        {
            "id": str(f.id),
            "tenant_id": int(f.tenant_id),
            "reported_operator_user_id": int(f.reported_operator_user_id),
            "delegation_id": f.delegation_id,
            "report_reason": f.report_reason,
            "status": f.status,
            "reviewed_at": f.reviewed_at,
            "reviewed_by_admin_id": f.reviewed_by_admin_id,
            "created_at": f.created_at,
        }
        for f in flags
    ]


# ---------------------------------------------------------------------------
# POST /api/admin/disputes/{id}/escalate
# ---------------------------------------------------------------------------


@router.post(
    "/disputes/{dispute_id}/escalate",
    response_model=DisputeEscalateResponse,
    status_code=status.HTTP_200_OK,
    summary="Admin: escalate a dispute for priority manual review (AC-63)",
)
def escalate_dispute(
    dispute_id: str = Path(..., description="TenantAuthorityFlag UUID"),
    body: DisputeEscalateRequest = ...,
    claims: dict = Depends(require_admin),
    db: Session = Depends(get_db),
) -> DisputeEscalateResponse:
    """Mark a pending dispute as escalated for priority review.

    Use when a dispute requires immediate attention (e.g., tenant in distress,
    ongoing unauthorized transactions, approaching 48h SLA breach).

    Transitions: pending → escalated.
    Already-escalated disputes: idempotent (stays 'escalated').
    Already-resolved disputes: returns 409.

    Audit: writes ChangeLog row with action='admin_escalate_dispute'.
    """
    admin_id = int(claims["sub"])
    svc = AdminDisputeService(db)

    try:
        flag = svc.escalate_dispute(
            dispute_id=dispute_id,
            admin_user_id=admin_id,
            reason=body.reason,
        )
        db.commit()
    except ValueError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "DISPUTE_STATE_ERROR", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        logger.error("[ADMIN] escalate_dispute failed id=%s: %s", dispute_id, exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"code": "INTERNAL_ERROR", "message": "Escalate dispute failed"},
        ) from exc

    from datetime import datetime

    return DisputeEscalateResponse(
        dispute_id=dispute_id,
        status=str(flag.status),
        escalated_at=datetime.utcnow(),
        reason=body.reason,
    )


# ---------------------------------------------------------------------------
# POST /api/admin/disputes/{id}/resolve
# ---------------------------------------------------------------------------


@router.post(
    "/disputes/{dispute_id}/resolve",
    response_model=DisputeResolveResponse,
    status_code=status.HTTP_200_OK,
    summary="Admin: resolve a dispute with verdict (AC-63 48h SLA)",
)
def resolve_dispute(
    dispute_id: str = Path(..., description="TenantAuthorityFlag UUID"),
    body: DisputeResolveRequest = ...,
    claims: dict = Depends(require_admin),
    db: Session = Depends(get_db),
) -> DisputeResolveResponse:
    """Admin closes a tenant unauthorized-operator dispute with a verdict.

    Outcome choices:
      'prima_facie_valid'  — report appears credible; triggers action.
      'invalid'            — no evidence of unauthorized operator.
      'requires_evidence'  — more information needed from tenant/owner.

    Action choices:
      'pause_delegation'   — immediately pauses the correlated delegation.
      'no_action'          — record outcome only; no delegation state change.
      'request_more_info'  — closes as 'invalid' pending more info.

    Note: action='pause_delegation' only takes effect if the TenantAuthorityFlag
    has a non-NULL delegation_id. If delegation_id is NULL, delegation_paused=False.

    Audit: writes ChangeLog row with action='admin_resolve_dispute'.
    48h SLA compliance: check (resolved_at - created_at) against 48h window.
    """
    admin_id = int(claims["sub"])
    svc = AdminDisputeService(db)

    try:
        result = svc.resolve_dispute(
            dispute_id=dispute_id,
            admin_user_id=admin_id,
            outcome=body.outcome,
            action=body.action,
            reason=body.reason,
        )
        db.commit()
    except ValueError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "DISPUTE_RESOLVE_ERROR", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        logger.error("[ADMIN] resolve_dispute failed id=%s: %s", dispute_id, exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"code": "INTERNAL_ERROR", "message": "Resolve dispute failed"},
        ) from exc

    return DisputeResolveResponse(**result)
