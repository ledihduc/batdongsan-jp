"""Approval workflow API endpoints (Phase 04).

Endpoints:
  GET  /api/approvals               — list (scoped by role=owner|operator)
  GET  /api/approvals/{id}          — detail
  POST /api/approvals/{id}/approve  — owner approves (body: reason, biometric_token)
  POST /api/approvals/{id}/reject   — owner rejects (body: reason required)
  POST /api/approvals/{id}/cancel   — operator cancels own pending request
  POST /api/kb04/{khai_bao_id}/submit-fast-track — KB04 fast-track (AC-55)
  POST /api/kb04/pre-file           — KB04 pre-file CT01 (AC-55b)
  POST /api/delegations/{id}/report-fraud — fraud termination (AC-43b)

Security:
  - approve/reject: must be the owner_id of the approval (IDOR guard in service)
  - cancel: must be the requester_user_id of the approval (IDOR guard in service)
  - list: scoped to caller's user_id (no cross-owner access)
  - All state mutations check delegation lockdown via is_lockdown_blocked

AC coverage:
  AC-24..AC-31b: threshold-triggered approval creation (via action handlers)
  AC-29b: biometric_token on approve if requires_biometric
  AC-30: 72h auto-reject (scheduled job)
  AC-31: audit write on every transition
  AC-43b: fraud_termination path with 24h SLA
  AC-55: KB04 fast-track with operator_full auto-approve
  AC-55b: KB04 pre-file with 6h SLA (district flag gate)
  AC-55c: district_pre_file_accepted check in pre-file endpoint
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app import auth
from app.database import get_db
from app.domain.delegation import Delegation, DelegationApproval
from app.schemas.approval import (
    ApprovalCancelRequest,
    ApprovalDecideRequest,
    ApprovalListResponse,
    ApprovalResponse,
    FraudReportRequest,
    FraudReportResponse,
    KB04FastTrackRequest,
    KB04FastTrackResponse,
    KB04PreFileRequest,
    KB04PreFileResponse,
)
from app.services.approval.approval_service import (
    ApprovalAlreadyDecided,
    ApprovalExpired,
    ApprovalNotFound,
    ApprovalService,
    BiometricRequired,
)
from app.services.approval.fraud_termination_service import FraudTerminationService
from app.services.approval.kb04_workflow import (
    DistrictPreFileNotAccepted,
    KB04WorkflowService,
    POAVerificationFailed,
)
from app.api.dependencies.actor import resolve_actor_context
from app.services.actor_context import ActorContext

logger = logging.getLogger(__name__)

router = APIRouter(tags=["approvals"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _load_approval_or_404(approval_id: str, db: Session) -> DelegationApproval:
    """Load approval by ID, 404 if not found."""
    approval = (
        db.query(DelegationApproval)
        .filter(DelegationApproval.id == approval_id)
        .first()
    )
    if approval is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "APPROVAL_NOT_FOUND", "approval_id": approval_id},
        )
    return approval


def _load_delegation_or_404(delegation_id: str, db: Session) -> Delegation:
    """Load delegation by ID, 404 if not found."""
    delegation = (
        db.query(Delegation)
        .filter(Delegation.id == delegation_id)
        .first()
    )
    if delegation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "DELEGATION_NOT_FOUND", "delegation_id": delegation_id},
        )
    return delegation


def _require_delegation_active(delegation: Delegation) -> None:
    """Guard: delegation must be active for new approvals."""
    if delegation.status not in ("active", "terminating"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DELEGATION_NOT_ACTIVE",
                "status": delegation.status,
                "message": "Delegation must be active to create approvals",
            },
        )


def _to_response(approval: DelegationApproval) -> ApprovalResponse:
    """Convert ORM model to Pydantic response."""
    return ApprovalResponse.model_validate(approval)


# ---------------------------------------------------------------------------
# GET /api/approvals — list (scoped to actor)
# ---------------------------------------------------------------------------


@router.get("/api/approvals", response_model=ApprovalListResponse)
def list_approvals(
    role: Optional[str] = Query(default=None, description="'owner' or 'operator'"),
    status_filter: Optional[str] = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> ApprovalListResponse:
    """List approvals scoped to the authenticated user.

    - role=owner: returns approvals where owner_id == caller (owner inbox)
    - role=operator: returns approvals where requester_user_id == caller (operator outbox)
    - Default (no role): returns both combined by caller participation
    """
    user_id = int(claims["sub"])
    svc = ApprovalService(db)

    if role == "owner":
        items = svc.list_for_owner(user_id, status=status_filter, limit=limit, offset=offset)
    elif role == "operator":
        items = svc.list_for_operator(user_id, status=status_filter, limit=limit, offset=offset)
    else:
        # Default: show all where user is a participant
        owner_items = svc.list_for_owner(user_id, status=status_filter, limit=limit // 2 + 1, offset=offset)
        operator_items = svc.list_for_operator(user_id, status=status_filter, limit=limit // 2 + 1, offset=offset)
        # Merge + de-dup (an approval can be in both if user is both owner and operator on diff delegations)
        seen_ids: set[str] = set()
        merged = []
        for item in (owner_items + operator_items):
            if item.id not in seen_ids:
                seen_ids.add(item.id)
                merged.append(item)
        # Sort by created_at desc
        items = sorted(merged, key=lambda x: x.created_at, reverse=True)[:limit]

    return ApprovalListResponse(
        items=[_to_response(a) for a in items],
        total=len(items),  # v1: approximate count (full COUNT query = phase-10)
        offset=offset,
        limit=limit,
    )


# ---------------------------------------------------------------------------
# GET /api/approvals/{id} — detail
# ---------------------------------------------------------------------------


@router.get("/api/approvals/{approval_id}", response_model=ApprovalResponse)
def get_approval_detail(
    approval_id: str,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> ApprovalResponse:
    """Return approval detail. Caller must be owner or requester (IDOR guard)."""
    user_id = int(claims["sub"])
    approval = _load_approval_or_404(approval_id, db)

    # IDOR guard: only participants can read
    if int(approval.owner_id) != user_id and int(approval.requester_user_id) != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "NOT_YOUR_APPROVAL", "approval_id": approval_id},
        )

    return _to_response(approval)


# ---------------------------------------------------------------------------
# POST /api/approvals/{id}/approve — owner approves
# ---------------------------------------------------------------------------


@router.post("/api/approvals/{approval_id}/approve", response_model=ApprovalResponse)
def approve_approval(
    approval_id: str,
    body: ApprovalDecideRequest,
    actor_ctx: ActorContext = Depends(resolve_actor_context),
    db: Session = Depends(get_db),
) -> ApprovalResponse:
    """Owner approves a pending approval.

    AC-29b: biometric_token required if approval.requires_biometric.
    Sets body.decision = 'approved' and delegates to ApprovalService.decide().
    """
    # Force decision to 'approved' regardless of body.decision field
    svc = ApprovalService(db)
    try:
        approval = svc.decide(
            approval_id=approval_id,
            owner_ctx=actor_ctx,
            decision="approved",
            reason=body.reason,
            biometric_token=body.biometric_token,
        )
        db.commit()
        return _to_response(approval)
    except ApprovalNotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "APPROVAL_NOT_FOUND"},
        )
    except PermissionError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "NOT_YOUR_APPROVAL", "message": str(exc)},
        )
    except ApprovalAlreadyDecided as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "APPROVAL_ALREADY_DECIDED", "message": str(exc)},
        )
    except ApprovalExpired as exc:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail={"code": "APPROVAL_EXPIRED", "message": str(exc)},
        )
    except BiometricRequired as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "BIOMETRIC_REQUIRED", "message": str(exc)},
        )


# ---------------------------------------------------------------------------
# POST /api/approvals/{id}/reject — owner rejects
# ---------------------------------------------------------------------------


@router.post("/api/approvals/{approval_id}/reject", response_model=ApprovalResponse)
def reject_approval(
    approval_id: str,
    body: ApprovalDecideRequest,
    actor_ctx: ActorContext = Depends(resolve_actor_context),
    db: Session = Depends(get_db),
) -> ApprovalResponse:
    """Owner rejects a pending approval. Reason is required."""
    svc = ApprovalService(db)
    try:
        approval = svc.decide(
            approval_id=approval_id,
            owner_ctx=actor_ctx,
            decision="rejected",
            reason=body.reason,
            biometric_token=body.biometric_token,
        )
        db.commit()
        return _to_response(approval)
    except ApprovalNotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "APPROVAL_NOT_FOUND"},
        )
    except PermissionError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "NOT_YOUR_APPROVAL", "message": str(exc)},
        )
    except ApprovalAlreadyDecided as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "APPROVAL_ALREADY_DECIDED", "message": str(exc)},
        )
    except ApprovalExpired as exc:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail={"code": "APPROVAL_EXPIRED", "message": str(exc)},
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VALIDATION_ERROR", "message": str(exc)},
        )


# ---------------------------------------------------------------------------
# POST /api/approvals/{id}/cancel — operator cancels own pending request
# ---------------------------------------------------------------------------


@router.post("/api/approvals/{approval_id}/cancel", response_model=ApprovalResponse)
def cancel_approval(
    approval_id: str,
    body: ApprovalCancelRequest,
    actor_ctx: ActorContext = Depends(resolve_actor_context),
    db: Session = Depends(get_db),
) -> ApprovalResponse:
    """Operator cancels their own pending approval request."""
    svc = ApprovalService(db)
    try:
        approval = svc.cancel(
            approval_id=approval_id,
            operator_ctx=actor_ctx,
            reason=body.reason or "operator_cancelled",
        )
        db.commit()
        return _to_response(approval)
    except ApprovalNotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "APPROVAL_NOT_FOUND"},
        )
    except PermissionError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "NOT_YOUR_APPROVAL", "message": str(exc)},
        )
    except ApprovalAlreadyDecided as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "APPROVAL_ALREADY_DECIDED", "message": str(exc)},
        )


# ---------------------------------------------------------------------------
# POST /api/kb04/{khai_bao_id}/submit-fast-track — KB04 fast-track (AC-55)
# ---------------------------------------------------------------------------


@router.post(
    "/api/kb04/{khai_bao_id}/submit-fast-track",
    response_model=KB04FastTrackResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def kb04_submit_fast_track(
    khai_bao_id: int,
    body: KB04FastTrackRequest,
    actor_ctx: ActorContext = Depends(resolve_actor_context),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> KB04FastTrackResponse:
    """Operator submits KB04 fast-track for tenant registration.

    Requires delegation context (X-Acting-As-Delegation-Id header).
    For operator_full preset: auto-approved immediately (AC-55 §13 D1).
    For other presets: pending 6h approval from owner.
    """
    if not actor_ctx.is_acting_on_behalf or not actor_ctx.delegation_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "DELEGATION_REQUIRED",
                "message": "KB04 fast-track requires an active delegation context",
            },
        )

    # Check permission
    if not actor_ctx.has_permission("khaibao.submit"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "PERMISSION_DENIED", "action": "khaibao.submit"},
        )

    delegation = _load_delegation_or_404(actor_ctx.delegation_id, db)
    _require_delegation_active(delegation)

    svc = KB04WorkflowService(db)
    approval = svc.submit_fast_track(
        actor_ctx=actor_ctx,
        delegation=delegation,
        khai_bao_id=khai_bao_id,
        form_data=body.form_data,
    )
    db.commit()

    auto_approved = approval.status == "approved"
    message = (
        "KB04 auto-approved (operator_full preset)" if auto_approved
        else "KB04 submitted — pending owner approval (6h SLA)"
    )

    return KB04FastTrackResponse(
        approval=_to_response(approval),
        auto_approved=auto_approved,
        message=message,
    )


# ---------------------------------------------------------------------------
# POST /api/kb04/pre-file — KB04 pre-file (AC-55b)
# ---------------------------------------------------------------------------


@router.post(
    "/api/kb04/pre-file",
    response_model=KB04PreFileResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def kb04_pre_file(
    body: KB04PreFileRequest,
    actor_ctx: ActorContext = Depends(resolve_actor_context),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> KB04PreFileResponse:
    """Operator submits CT01 form BEFORE tenant move-in (pre-file).

    AC-55b: Creates approval with gate='pending_pre_file_review'.
    AC-55c: Validates district_pre_file_accepted; rejects if False.
    Even for operator_full preset, this always requires owner review.
    """
    if not actor_ctx.is_acting_on_behalf or not actor_ctx.delegation_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "DELEGATION_REQUIRED",
                "message": "KB04 pre-file requires an active delegation context",
            },
        )

    if not actor_ctx.has_permission("khaibao.submit"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "PERMISSION_DENIED", "action": "khaibao.submit"},
        )

    delegation = _load_delegation_or_404(actor_ctx.delegation_id, db)
    _require_delegation_active(delegation)

    # Build form_data from request
    form_data = {
        "tenant_full_name": body.tenant_full_name,
        "tenant_cccd": body.tenant_cccd,
        "expected_move_in_date": body.expected_move_in_date.isoformat(),
        "room_id": body.room_id,
        **(body.additional_form_data or {}),
    }

    svc = KB04WorkflowService(db)
    try:
        approval = svc.pre_file(
            actor_ctx=actor_ctx,
            delegation=delegation,
            contract_id=body.contract_id,
            form_data=form_data,
        )
    except DistrictPreFileNotAccepted as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": "DISTRICT_PRE_FILE_NOT_ACCEPTED",
                "message": str(exc),
                "hint": "Use the approve-then-file workflow for this district",
            },
        )

    db.commit()

    # Check if district warning was flagged
    district_warning = None
    if approval.action_payload_json and approval.action_payload_json.get("audit_warning"):
        district_warning = (
            "District pre-file acceptance status unknown — submission allowed but flagged"
        )

    return KB04PreFileResponse(
        approval=_to_response(approval),
        contract_id=body.contract_id,
        pre_filed_at=datetime.utcnow(),
        message="CT01 pre-file submitted — pending owner review (6h SLA)",
        district_warning=district_warning,
    )


# ---------------------------------------------------------------------------
# POST /api/delegations/{delegation_id}/report-fraud — AC-43b
# ---------------------------------------------------------------------------


@router.post(
    "/api/delegations/{delegation_id}/report-fraud",
    response_model=FraudReportResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def report_fraud(
    delegation_id: str,
    body: FraudReportRequest,
    actor_ctx: ActorContext = Depends(resolve_actor_context),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> FraudReportResponse:
    """Operator reports fraud on a delegation — triggers 24h SLA approval (AC-43b).

    Creates a fraud_termination approval with sla_class='fraud_termination_24h'.
    Allowed during delegation lockdown (terminating status) per AC-43 whitelist.
    """
    if not actor_ctx.is_acting_on_behalf:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "DELEGATION_REQUIRED",
                "message": "Fraud report requires an active delegation context",
            },
        )

    delegation = _load_delegation_or_404(delegation_id, db)

    # Verify the actor is the operator of this delegation
    if int(delegation.operator_id) != int(actor_ctx.actor_user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "NOT_YOUR_DELEGATION"},
        )

    # Fraud report is whitelisted during lockdown (AC-43 exemption for fraud actions)
    if delegation.status not in ("active", "paused", "terminating"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DELEGATION_NOT_ACTIVE",
                "status": delegation.status,
            },
        )

    svc = FraudTerminationService(db)
    approval = svc.report_fraud(
        actor_ctx=actor_ctx,
        delegation=delegation,
        fraud_reason=body.fraud_reason,
        evidence_urls=body.evidence_urls,
    )
    db.commit()

    return FraudReportResponse(
        approval=_to_response(approval),
        message=(
            "Fraud report submitted — owner notified with 24h SLA. "
            "If no action within 24h, operator account will be suspended (AC-43b)."
        ),
    )
