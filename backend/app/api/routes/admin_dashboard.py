"""Admin dashboard endpoints — Phase 10 (read-only).

Endpoints:
  GET /api/admin/dashboard/summary
      — pending KYC count, pending death certs, pending POA reviews,
        fraud reports 24h, stuck approvals (US-A5), active/paused delegation counts.

  GET /api/admin/audit-trail/{delegation_id}
      — full dual-identity ChangeLog for a delegation (AC-40 court-export companion).

  GET /api/admin/users/{user_id}/delegations
      — all delegations where user is owner or operator.

Security: all endpoints require role=admin (app.auth.require_admin).
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Path, status
from sqlalchemy.orm import Session

from app.auth import require_admin
from app.database import get_db
from app.schemas.admin import (
    AdminDashboardSummary,
    AdminAuditTrailResponse,
    AuditTrailEntry,
    AdminUserDelegationsResponse,
    DelegationSummary,
)
from app.services.admin.admin_dashboard_service import AdminDashboardService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["admin_dashboard"])


# ---------------------------------------------------------------------------
# GET /api/admin/dashboard/summary
# ---------------------------------------------------------------------------


@router.get(
    "/dashboard/summary",
    response_model=AdminDashboardSummary,
    summary="Admin: ops dashboard aggregate counts",
)
def get_dashboard_summary(
    claims: dict = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminDashboardSummary:
    """Return pending-queue counts for the admin ops dashboard.

    Counts returned:
    - pending_kyc_count            business operator KYC submissions awaiting review
    - pending_death_certs_count    death certificates pending verification (US-A6/A7)
    - pending_poa_reviews_count    delegation approvals in 'pending' status
    - fraud_reports_last_24h_count fraud_termination approvals created in last 24h
    - stuck_approvals_count        approvals pending > 60h (US-A5)
    - active_delegations_count     all active delegations on the platform
    - paused_delegations_count     all paused delegations
    """
    svc = AdminDashboardService(db)
    summary = svc.dashboard_summary()
    return AdminDashboardSummary(**summary)


# ---------------------------------------------------------------------------
# GET /api/admin/audit-trail/{delegation_id}
# ---------------------------------------------------------------------------


@router.get(
    "/audit-trail/{delegation_id}",
    response_model=AdminAuditTrailResponse,
    summary="Admin: full audit trail for a delegation (dual-identity ChangeLog)",
)
def get_audit_trail(
    delegation_id: str = Path(..., description="Delegation UUID"),
    claims: dict = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminAuditTrailResponse:
    """Return all ChangeLog entries linked to a delegation.

    Used by support and legal team for audit investigations.
    For court-evidence export (AC-40), use the dedicated export endpoint
    in admin_delegations.py which generates PDF/XLSX with full chain.
    """
    # Verify delegation exists before querying audit trail
    try:
        from app.domain.delegation import Delegation

        delegation = db.query(Delegation).filter(Delegation.id == delegation_id).first()
    except Exception as exc:
        logger.error("[ADMIN] audit_trail lookup failed delegation_id=%s: %s", delegation_id, exc)
        delegation = None

    if delegation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": "DELEGATION_NOT_FOUND",
                "message": f"Delegation {delegation_id!r} not found",
            },
        )

    svc = AdminDashboardService(db)
    entries_raw = svc.audit_trail_for_delegation(delegation_id)

    entries = [AuditTrailEntry(**e) for e in entries_raw]
    return AdminAuditTrailResponse(
        delegation_id=delegation_id,
        entries=entries,
        total=len(entries),
    )


# ---------------------------------------------------------------------------
# GET /api/admin/users/{user_id}/delegations
# ---------------------------------------------------------------------------


@router.get(
    "/users/{user_id}/delegations",
    response_model=AdminUserDelegationsResponse,
    summary="Admin: all delegations for a user (as owner or operator)",
)
def get_user_delegations(
    user_id: int = Path(..., description="User ID"),
    claims: dict = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminUserDelegationsResponse:
    """Return all delegations where the user is owner or operator.

    Used by admin for user-level investigation (e.g., fraud review,
    KYC clearance check, or legal discovery).
    """
    svc = AdminDashboardService(db)
    result = svc.delegations_for_user(user_id)

    def _to_summary(d: object) -> DelegationSummary:
        return DelegationSummary(
            id=str(d.id),  # type: ignore[attr-defined]
            owner_id=int(d.owner_id),  # type: ignore[attr-defined]
            operator_id=int(d.operator_id),  # type: ignore[attr-defined]
            status=str(d.status),  # type: ignore[attr-defined]
            role_preset=str(d.role_preset),  # type: ignore[attr-defined]
            paused_reason=d.paused_reason,  # type: ignore[attr-defined]
            retention_tier=str(d.retention_tier),  # type: ignore[attr-defined]
            created_at=d.created_at,  # type: ignore[attr-defined]
            activated_at=d.activated_at,  # type: ignore[attr-defined]
            terminate_requested_at=d.terminate_requested_at,  # type: ignore[attr-defined]
            terminated_at=d.terminated_at,  # type: ignore[attr-defined]
        )

    return AdminUserDelegationsResponse(
        user_id=user_id,
        as_owner=[_to_summary(d) for d in result["as_owner"]],
        as_operator=[_to_summary(d) for d in result["as_operator"]],
    )
