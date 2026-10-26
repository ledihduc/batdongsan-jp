"""Admin delegation action endpoints — Phase 10.

Endpoints:
  POST /api/admin/delegations/{id}/force-revoke
      — admin override termination (court order, fraud escalation, AC-45).

  POST /api/admin/users/{user_id}/suspend-operator
      — global operator suspension across all active delegations.

  POST /api/admin/users/{user_id}/reinstate-operator
      — reverse suspension, resume delegations paused for 'admin_suspend'.

Security: all endpoints require role=admin (app.auth.require_admin).
Audit: every write action logs a ChangeLog entry via AdminDelegationActions.
"""

from __future__ import annotations

import logging
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Path, status
from sqlalchemy.orm import Session

from app.auth import require_admin
from app.database import get_db
from app.schemas.admin import (
    ForceRevokeRequest,
    ForceRevokeResponse,
    SuspendOperatorRequest,
    SuspendOperatorResponse,
    ReinstateOperatorRequest,
    ReinstateOperatorResponse,
)
from app.services.admin.admin_delegation_actions import AdminDelegationActions

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["admin_delegations"])


# ---------------------------------------------------------------------------
# POST /api/admin/delegations/{id}/force-revoke
# ---------------------------------------------------------------------------


@router.post(
    "/delegations/{delegation_id}/force-revoke",
    response_model=ForceRevokeResponse,
    status_code=status.HTTP_200_OK,
    summary="Admin: force-revoke a delegation (court order / fraud override)",
)
def force_revoke_delegation(
    delegation_id: str = Path(..., description="Delegation UUID to force-revoke"),
    body: ForceRevokeRequest = ...,
    claims: dict = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ForceRevokeResponse:
    """Admin terminates a delegation immediately, bypassing the normal 30d notice period.

    Use cases:
      - Court order requiring immediate delegation termination.
      - Fraud escalation when owner is unreachable.
      - Regulatory action (GPKD revocation + operator already suspended).

    Audit: writes ChangeLog row with action='admin_force_revoke', reason stored.
    The delegation transitions to status='terminated' regardless of current status
    (unless already 'archived').
    """
    admin_id = int(claims["sub"])
    svc = AdminDelegationActions(db)

    try:
        delegation = svc.force_revoke_delegation(
            delegation_id=delegation_id,
            admin_user_id=admin_id,
            reason=body.reason,
            immediate=body.immediate,
        )
        db.commit()
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "DELEGATION_NOT_FOUND", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        logger.error("[ADMIN] force_revoke failed delegation_id=%s: %s", delegation_id, exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"code": "INTERNAL_ERROR", "message": "Force-revoke failed"},
        ) from exc

    return ForceRevokeResponse(
        delegation_id=delegation_id,
        status=str(delegation.status),
        terminated_at=delegation.terminated_at or datetime.utcnow(),
        reason=body.reason,
    )


# ---------------------------------------------------------------------------
# POST /api/admin/users/{user_id}/suspend-operator
# ---------------------------------------------------------------------------


@router.post(
    "/users/{user_id}/suspend-operator",
    response_model=SuspendOperatorResponse,
    status_code=status.HTTP_200_OK,
    summary="Admin: globally suspend an operator (all active delegations)",
)
def suspend_operator(
    user_id: int = Path(..., description="Operator user ID to suspend"),
    body: SuspendOperatorRequest = ...,
    claims: dict = Depends(require_admin),
    db: Session = Depends(get_db),
) -> SuspendOperatorResponse:
    """Admin suspends an operator globally.

    Pauses ALL active delegations where user_id is the operator.
    Sets paused_reason='admin_suspend' to distinguish from system-pause reasons.

    This is distinct from per-delegation pause (which can be done by the owner).
    Admin suspension is used for: fraud investigation, regulatory compliance,
    KYC fraud discovery, or court-ordered suspension.

    Audit: writes ChangeLog row per delegation with action='admin_suspend_operator'.
    """
    admin_id = int(claims["sub"])
    svc = AdminDelegationActions(db)

    try:
        count = svc.suspend_operator(
            operator_user_id=user_id,
            admin_user_id=admin_id,
            reason=body.reason,
        )
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("[ADMIN] suspend_operator failed user_id=%d: %s", user_id, exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"code": "INTERNAL_ERROR", "message": "Suspend operator failed"},
        ) from exc

    return SuspendOperatorResponse(
        user_id=user_id,
        delegations_paused=count,
        reason=body.reason,
        suspended_at=datetime.utcnow(),
    )


# ---------------------------------------------------------------------------
# POST /api/admin/users/{user_id}/reinstate-operator
# ---------------------------------------------------------------------------


@router.post(
    "/users/{user_id}/reinstate-operator",
    response_model=ReinstateOperatorResponse,
    status_code=status.HTTP_200_OK,
    summary="Admin: reinstate a suspended operator",
)
def reinstate_operator(
    user_id: int = Path(..., description="Operator user ID to reinstate"),
    body: ReinstateOperatorRequest = ...,
    claims: dict = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ReinstateOperatorResponse:
    """Admin reinstates an operator after suspension resolution.

    Only resumes delegations paused with reason='admin_suspend'.
    Does NOT auto-resume delegations paused for other system reasons
    (kyc_expired, gpkd_revoked, owner_death, fraud_flag) — those require
    their respective resolution flows.

    Audit: writes ChangeLog row per delegation with action='admin_reinstate_operator'.
    """
    admin_id = int(claims["sub"])
    svc = AdminDelegationActions(db)

    try:
        count = svc.reinstate_operator(
            operator_user_id=user_id,
            admin_user_id=admin_id,
            reason=body.reason,
        )
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("[ADMIN] reinstate_operator failed user_id=%d: %s", user_id, exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"code": "INTERNAL_ERROR", "message": "Reinstate operator failed"},
        ) from exc

    return ReinstateOperatorResponse(
        user_id=user_id,
        delegations_reinstated=count,
        reason=body.reason,
        reinstated_at=datetime.utcnow(),
    )
