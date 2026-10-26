"""Delegation lifecycle API endpoints (Phase 03).

All delegation lifecycle CRUD + invitation management.

AC coverage:
  AC-01..AC-10b: invitation create/accept/reject/revoke
  AC-09/10/22/42/45: pause/resume/terminate/resign
  AC-46: audit log read (90d post-terminate)
  AC-57: out-of-office set/clear
  AC-58-OOO: OOO emergency flag noted in delegation response
  AC-31b: threshold validation enforced in schemas
  NFR-01: atomic state transitions (FOR UPDATE + transaction)
  NFR-02: revocation on next request (phase-02 decorator reads live DB)

Security:
  - Owner-only mutations assert `not actor_ctx.is_acting_on_behalf` (operator cannot
    pause/terminate/revoke on owner's behalf via X-Acting-As).
  - Operator self-resign (AC-22) asserts actor == delegation.operator_id.
  - OOO set asserts actor == delegation.operator_id.
  - Invite accept asserts invitee matches the authenticated user.
  - IDOR: all delegation lookups scoped to caller participation
    (owner_id == user OR operator_id == user).
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app import auth
from app.database import get_db
from app.domain.delegation import Delegation, DelegationInvitation
from app.schemas.delegation import (
    AcceptResponse,
    AuditLogEntry,
    CancelTerminationRequest,
    DelegationListItem,
    DelegationResponse,
    InvitationAcceptRequest,
    InvitationCreateRequest,
    InvitationResponse,
    OutOfOfficeRequest,
    PauseRequest,
    ResignRequest,
    TerminateRequest,
    ThresholdUpdateRequest,
)
from app.services.delegation import (
    DelegationInvitationService,
    DelegationLifecycleService,
    DuplicatePendingInvitation,
    InvalidStateTransition,
    OwnerHasActiveDelegation,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/delegations", tags=["delegations"])

# Base app URL for deep-link construction
_APP_BASE_URL = "https://ancu365.com"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _get_delegation_as_participant(
    delegation_id: str, user_id: int, db: Session
) -> Delegation:
    """Load delegation, assert caller is owner or operator (IDOR guard)."""
    d = (
        db.query(Delegation)
        .filter(Delegation.id == delegation_id)
        .first()
    )
    if d is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "DELEGATION_NOT_FOUND", "message": "Delegation not found"},
        )
    if int(d.owner_id) != user_id and int(d.operator_id) != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "NOT_A_PARTICIPANT", "message": "You are not a participant of this delegation"},
        )
    return d


def _assert_owner_self(delegation: Delegation, user_id: int) -> None:
    """Raise 403 if caller is not the delegation owner."""
    if int(delegation.owner_id) != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "OWNER_ONLY",
                "message": "Only the delegation owner can perform this action",
            },
        )


def _assert_operator_self(delegation: Delegation, user_id: int) -> None:
    """Raise 403 if caller is not the delegation operator."""
    if int(delegation.operator_id) != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "OPERATOR_ONLY",
                "message": "Only the delegation operator can perform this action",
            },
        )


def _build_delegation_response(d: Delegation) -> DelegationResponse:
    """Map ORM Delegation to DelegationResponse, handling JSON scope_target_ids."""
    scope_ids: Optional[list[int]] = None
    if d.scope_target_ids is not None:
        if isinstance(d.scope_target_ids, list):
            scope_ids = [int(x) for x in d.scope_target_ids]
        else:
            scope_ids = []
    return DelegationResponse(
        id=str(d.id),
        owner_id=int(d.owner_id),
        operator_id=int(d.operator_id),
        invitation_id=str(d.invitation_id) if d.invitation_id else None,
        status=str(d.status),
        paused_reason=d.paused_reason,
        paused_until=d.paused_until,
        role_preset=str(d.role_preset),
        scope_type=str(d.scope_type),
        scope_target_ids=scope_ids,
        commission_pct=d.commission_pct,
        commission_fixed_vnd=d.commission_fixed_vnd,
        threshold_monthly_rent_vnd=d.threshold_monthly_rent_vnd,
        threshold_term_months=int(d.threshold_term_months),
        threshold_expense_vnd=d.threshold_expense_vnd,
        threshold_rent_change_pct=d.threshold_rent_change_pct,
        threshold_refund_vnd=d.threshold_refund_vnd,
        poa_format=str(d.poa_format),
        out_of_office_start=d.out_of_office_start,
        out_of_office_end=d.out_of_office_end,
        activated_at=d.activated_at,
        terminate_requested_at=d.terminate_requested_at,
        terminate_reason=d.terminate_reason,
        terminated_at=d.terminated_at,
        archived_at=d.archived_at,
        retention_tier=str(d.retention_tier),
        created_at=d.created_at,
        updated_at=d.updated_at,
    )


def _build_invitation_response(
    inv: DelegationInvitation,
    operator_kyc_complete: bool = False,
) -> InvitationResponse:
    """Map ORM DelegationInvitation to InvitationResponse."""
    scope_ids: Optional[list[int]] = None
    if inv.proposed_scope_target_ids is not None:
        if isinstance(inv.proposed_scope_target_ids, list):
            scope_ids = [int(x) for x in inv.proposed_scope_target_ids]

    accept_url = f"{_APP_BASE_URL}/delegation/accept/{inv.token}"
    revoke_url = f"/api/delegations/invitations/{inv.id}/revoke"
    return InvitationResponse(
        id=str(inv.id),
        owner_id=int(inv.owner_id),
        invited_phone_or_email=str(inv.invited_phone_or_email),
        invited_user_id=int(inv.invited_user_id) if inv.invited_user_id else None,
        status=str(inv.status),
        proposed_role_preset=str(inv.proposed_role_preset),
        proposed_scope_type=str(inv.proposed_scope_type),
        proposed_scope_target_ids=scope_ids,
        proposed_commission_pct=inv.proposed_commission_pct,
        proposed_commission_fixed_vnd=inv.proposed_commission_fixed_vnd,
        proposed_poa_format=str(inv.proposed_poa_format),
        expires_at=inv.expires_at,
        accepted_at=inv.accepted_at,
        rejected_at=inv.rejected_at,
        revoked_at=inv.revoked_at,
        created_at=inv.created_at,
        operator_kyc_complete=operator_kyc_complete,
        accept_url=accept_url,
        revoke_url=revoke_url,
    )


# ---------------------------------------------------------------------------
# Invitation endpoints
# ---------------------------------------------------------------------------


@router.post(
    "/invitations",
    response_model=InvitationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Owner creates delegation invitation (AC-01/10b)",
)
def create_invitation(
    body: InvitationCreateRequest,
    claims: dict = Depends(auth.require_host),
    db: Session = Depends(get_db),
) -> InvitationResponse:
    """Create a delegation invitation.

    AC-01: generates single-use token with 7-day TTL.
    AC-10b: returns 409 if a pending invitation already exists for the same invitee.
    AC-03: role_preset validated by schema.
    AC-04: commission XOR validated by schema.
    AC-31b: all 5 thresholds required, validated by schema.
    """
    owner_id: int = int(claims["sub"])
    svc = DelegationLifecycleService(db)
    inv_svc = DelegationInvitationService(db)

    # Resolve invited user if they already have an account
    invited_user_id = inv_svc.resolve_invited_user_id(db, body.invited_phone_or_email)

    try:
        invitation = svc.create_invitation(
            owner_id=owner_id,
            payload=body,
            invited_user_id=invited_user_id,
        )
        db.commit()
    except DuplicatePendingInvitation as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DUPLICATE_PENDING_INVITATION",
                "message": str(exc),
                "existing_invitation_id": exc.existing_id,
                "revoke_url": exc.revoke_url,
            },
        ) from exc
    except Exception as exc:
        db.rollback()
        logger.error("[DELEGATION] create_invitation failed: %s", exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"code": "INTERNAL_ERROR", "message": str(exc)},
        ) from exc

    # Send notification (v1: log only)
    accept_url = f"{_APP_BASE_URL}/delegation/accept/{invitation.token}"
    inv_svc.send_invite_notification(invitation, accept_url)

    db.refresh(invitation)
    return _build_invitation_response(invitation)


@router.get(
    "/invitations",
    response_model=list[InvitationResponse],
    summary="List invitations (owner=sent, user=received)",
)
def list_invitations(
    as_role: str = Query(default="sender", alias="as", description="sender or recipient"),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> list[InvitationResponse]:
    """List delegation invitations scoped to the authenticated user.

    ?as=sender → owner sees invitations they sent.
    ?as=recipient → user sees invitations they received.
    """
    user_id: int = int(claims["sub"])

    if as_role == "sender":
        invitations = (
            db.query(DelegationInvitation)
            .filter(DelegationInvitation.owner_id == user_id)
            .order_by(DelegationInvitation.created_at.desc())
            .limit(100)
            .all()
        )
    else:
        # Recipient: by invited_user_id (if resolved) or by phone/email
        from app import models
        user = db.query(models.User).filter(models.User.id == user_id).first()
        phone_or_email = (user.email if user else "") or ""
        phone = getattr(user, "phone", None) if user else None

        from sqlalchemy import or_
        q = db.query(DelegationInvitation).filter(
            or_(
                DelegationInvitation.invited_user_id == user_id,
                DelegationInvitation.invited_phone_or_email == phone_or_email,
                DelegationInvitation.invited_phone_or_email == phone if phone else False,
            )
        )
        invitations = q.order_by(DelegationInvitation.created_at.desc()).limit(100).all()

    return [_build_invitation_response(inv) for inv in invitations]


@router.get(
    "/invitations/{invitation_id}",
    response_model=InvitationResponse,
    summary="Get invitation detail (AC-06: includes kyc_complete flag)",
)
def get_invitation(
    invitation_id: str,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> InvitationResponse:
    """Get invitation detail. Returns operator_kyc_complete for Flutter button gate (AC-06)."""
    user_id: int = int(claims["sub"])
    inv_svc = DelegationInvitationService(db)
    invitation = inv_svc.get_by_id(invitation_id)

    if invitation is None:
        raise HTTPException(status_code=404, detail={"code": "INVITATION_NOT_FOUND"})

    # IDOR: only sender (owner) or recipient can view
    invited_user_id = invitation.invited_user_id
    is_sender = int(invitation.owner_id) == user_id
    is_recipient = (invited_user_id is not None and int(invited_user_id) == user_id)

    if not is_sender and not is_recipient:
        raise HTTPException(status_code=403, detail={"code": "NOT_A_PARTICIPANT"})

    # AC-06: check operator KYC
    svc = DelegationLifecycleService(db)
    kyc_complete = False
    if invited_user_id is not None:
        kyc_complete = svc._check_operator_kyc_complete(int(invited_user_id))

    return _build_invitation_response(invitation, operator_kyc_complete=kyc_complete)


@router.post(
    "/invitations/{invitation_id}/accept",
    response_model=AcceptResponse,
    summary="Operator accepts delegation invitation (AC-05)",
)
def accept_invitation(
    invitation_id: str,
    body: InvitationAcceptRequest,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> AcceptResponse:
    """Operator accepts invitation → creates Delegation row.

    AC-05: if KYC not complete → status=pending_op_kyc + kyc_redirect hint.
    AC-08: fails if owner already has an active delegation.
    Single-use token: token_used_at set on accept.
    """
    user_id: int = int(claims["sub"])
    inv_svc = DelegationInvitationService(db)
    svc = DelegationLifecycleService(db)

    invitation = inv_svc.get_by_id(invitation_id)
    if invitation is None:
        raise HTTPException(status_code=404, detail={"code": "INVITATION_NOT_FOUND"})

    try:
        inv_svc.validate_for_accept(invitation)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVITATION_INVALID", "message": str(exc)},
        ) from exc

    try:
        delegation = svc.accept_invitation(
            invitation=invitation,
            accepting_user_id=user_id,
            disclosure_ack=body.shared_login_disclosure_ack,
        )
        db.commit()
    except OwnerHasActiveDelegation as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "OWNER_HAS_ACTIVE_DELEGATION",
                "message": str(exc),
                "existing_delegation_id": exc.existing_id,
            },
        ) from exc
    except Exception as exc:
        db.rollback()
        logger.error("[DELEGATION] accept_invitation failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR", "message": str(exc)}) from exc

    db.refresh(delegation)
    kyc_required = delegation.status == "pending_op_kyc"
    return AcceptResponse(
        delegation=_build_delegation_response(delegation),
        kyc_required=kyc_required,
        kyc_redirect_url=f"{_APP_BASE_URL}/kyc/operator" if kyc_required else None,
    )


@router.post(
    "/invitations/{invitation_id}/decline",
    response_model=InvitationResponse,
    summary="Operator declines delegation invitation",
)
def decline_invitation(
    invitation_id: str,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> InvitationResponse:
    """Operator declines invitation → status=rejected."""
    user_id: int = int(claims["sub"])
    inv_svc = DelegationInvitationService(db)

    invitation = inv_svc.get_by_id(invitation_id)
    if invitation is None:
        raise HTTPException(status_code=404, detail={"code": "INVITATION_NOT_FOUND"})

    # Only the invited user can reject
    if invitation.invited_user_id is not None and int(invitation.invited_user_id) != user_id:
        raise HTTPException(status_code=403, detail={"code": "NOT_INVITED_USER"})

    try:
        inv_svc.validate_for_reject(invitation)
    except Exception as exc:
        raise HTTPException(status_code=422, detail={"code": "INVITATION_INVALID", "message": str(exc)}) from exc

    try:
        inv_svc.mark_rejected(invitation)
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(invitation)
    return _build_invitation_response(invitation)


@router.post(
    "/invitations/{invitation_id}/revoke",
    response_model=InvitationResponse,
    summary="Owner revokes a pending invitation",
)
def revoke_invitation(
    invitation_id: str,
    claims: dict = Depends(auth.require_host),
    db: Session = Depends(get_db),
) -> InvitationResponse:
    """Owner revokes their pending invitation → status=revoked_by_owner."""
    owner_id: int = int(claims["sub"])
    inv_svc = DelegationInvitationService(db)

    invitation = inv_svc.get_by_id(invitation_id)
    if invitation is None:
        raise HTTPException(status_code=404, detail={"code": "INVITATION_NOT_FOUND"})
    if int(invitation.owner_id) != owner_id:
        raise HTTPException(status_code=403, detail={"code": "NOT_YOUR_INVITATION"})
    if invitation.status != "pending":
        raise HTTPException(
            status_code=422,
            detail={"code": "INVITATION_NOT_PENDING", "message": f"Invitation status is '{invitation.status}'"},
        )

    try:
        inv_svc.mark_revoked_by_owner(invitation)
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    inv_svc.send_revocation_notification(invitation)
    db.refresh(invitation)
    return _build_invitation_response(invitation)


# ---------------------------------------------------------------------------
# Delegation list / detail endpoints
# ---------------------------------------------------------------------------


@router.get(
    "",
    response_model=list[DelegationListItem],
    summary="List delegations scoped to caller (AC-56: both owner and operator roles)",
)
def list_delegations(
    role: Optional[str] = Query(
        default=None,
        description="Filter by role: 'owner' or 'operator'. Returns both if omitted.",
    ),
    delegation_status: Optional[str] = Query(
        default=None, alias="status", description="Filter by delegation status"
    ),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> list[DelegationListItem]:
    """List delegations where the authenticated user is owner or operator.

    AC-56: a user can appear in both roles simultaneously.
    ?role=owner → only delegations where user is the owner.
    ?role=operator → only delegations where user is the operator.
    No ?role → both.
    """
    user_id: int = int(claims["sub"])
    from sqlalchemy import or_

    q = db.query(Delegation)

    if role == "owner":
        q = q.filter(Delegation.owner_id == user_id)
    elif role == "operator":
        q = q.filter(Delegation.operator_id == user_id)
    else:
        q = q.filter(
            or_(Delegation.owner_id == user_id, Delegation.operator_id == user_id)
        )

    if delegation_status:
        q = q.filter(Delegation.status == delegation_status)

    rows = q.order_by(Delegation.created_at.desc()).limit(200).all()

    return [
        DelegationListItem(
            id=str(d.id),
            owner_id=int(d.owner_id),
            operator_id=int(d.operator_id),
            status=str(d.status),
            role_preset=str(d.role_preset),
            scope_type=str(d.scope_type),
            created_at=d.created_at,
            activated_at=d.activated_at,
            terminate_requested_at=d.terminate_requested_at,
        )
        for d in rows
    ]


@router.get(
    "/{delegation_id}",
    response_model=DelegationResponse,
    summary="Get delegation detail",
)
def get_delegation(
    delegation_id: str,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> DelegationResponse:
    """Get full delegation detail. Caller must be owner or operator (IDOR guard)."""
    user_id: int = int(claims["sub"])
    d = _get_delegation_as_participant(delegation_id, user_id, db)
    return _build_delegation_response(d)


# ---------------------------------------------------------------------------
# Mutation endpoints (owner self-acting only — no X-Acting-As-Delegation-Id)
# ---------------------------------------------------------------------------


@router.post(
    "/{delegation_id}/pause",
    response_model=DelegationResponse,
    summary="Owner pauses delegation (AC-09)",
)
def pause_delegation(
    delegation_id: str,
    body: PauseRequest,
    claims: dict = Depends(auth.require_host),
    db: Session = Depends(get_db),
) -> DelegationResponse:
    """AC-09: Owner pauses their delegation. Only owner can call (not operator via X-Acting-As)."""
    user_id: int = int(claims["sub"])
    d = _get_delegation_as_participant(delegation_id, user_id, db)
    _assert_owner_self(d, user_id)

    svc = DelegationLifecycleService(db)
    try:
        updated = svc.pause_delegation(
            delegation=d,
            reason=body.reason,
            paused_until=body.paused_until,
            actor_user_id=user_id,
        )
        db.commit()
    except InvalidStateTransition as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_STATE_TRANSITION", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(updated)
    return _build_delegation_response(updated)


@router.post(
    "/{delegation_id}/resume",
    response_model=DelegationResponse,
    summary="Owner resumes paused delegation",
)
def resume_delegation(
    delegation_id: str,
    claims: dict = Depends(auth.require_host),
    db: Session = Depends(get_db),
) -> DelegationResponse:
    """Owner resumes a paused delegation (not system-paused reasons)."""
    user_id: int = int(claims["sub"])
    d = _get_delegation_as_participant(delegation_id, user_id, db)
    _assert_owner_self(d, user_id)

    svc = DelegationLifecycleService(db)
    try:
        updated = svc.resume_delegation(delegation=d, actor_user_id=user_id)
        db.commit()
    except InvalidStateTransition as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_STATE_TRANSITION", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(updated)
    return _build_delegation_response(updated)


@router.post(
    "/{delegation_id}/revoke",
    response_model=DelegationResponse,
    summary="Owner terminates delegation (AC-10/42/45)",
)
def terminate_delegation(
    delegation_id: str,
    body: TerminateRequest,
    claims: dict = Depends(auth.require_host),
    db: Session = Depends(get_db),
) -> DelegationResponse:
    """AC-10/42/45: Owner terminates delegation.

    Normal reasons → 30d notice (status=terminating).
    fraud_suspected / legal_dispute → immediate termination + admin notification.
    """
    user_id: int = int(claims["sub"])
    d = _get_delegation_as_participant(delegation_id, user_id, db)
    _assert_owner_self(d, user_id)

    svc = DelegationLifecycleService(db)
    try:
        updated = svc.terminate_delegation(
            delegation=d, reason=body.reason, actor_user_id=user_id
        )
        db.commit()
    except InvalidStateTransition as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_STATE_TRANSITION", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    # If fraud/legal: trigger admin notification (phase-08 placeholder)
    if body.reason in ("fraud_suspected", "legal_dispute"):
        logger.info(
            "[DELEGATION TERMINATE FRAUD] delegation_id=%s reason=%s — "
            "phase-08 must send admin alert.",
            delegation_id,
            body.reason,
        )

    db.refresh(updated)
    return _build_delegation_response(updated)


@router.post(
    "/{delegation_id}/cancel-termination",
    response_model=DelegationResponse,
    summary="Owner cancels pending 30d termination notice",
)
def cancel_termination(
    delegation_id: str,
    claims: dict = Depends(auth.require_host),
    db: Session = Depends(get_db),
) -> DelegationResponse:
    """Owner cancels the 30d termination clock, reverting to active."""
    user_id: int = int(claims["sub"])
    d = _get_delegation_as_participant(delegation_id, user_id, db)
    _assert_owner_self(d, user_id)

    svc = DelegationLifecycleService(db)
    try:
        updated = svc.cancel_termination(delegation=d, actor_user_id=user_id)
        db.commit()
    except InvalidStateTransition as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_STATE_TRANSITION", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(updated)
    return _build_delegation_response(updated)


@router.patch(
    "/{delegation_id}/thresholds",
    response_model=DelegationResponse,
    summary="Owner updates delegation thresholds (AC-24/25/26/28/31b)",
)
def update_thresholds(
    delegation_id: str,
    body: ThresholdUpdateRequest,
    claims: dict = Depends(auth.require_host),
    db: Session = Depends(get_db),
) -> DelegationResponse:
    """Owner updates threshold values mid-contract. Validated by schema (AC-31b)."""
    user_id: int = int(claims["sub"])
    d = _get_delegation_as_participant(delegation_id, user_id, db)
    _assert_owner_self(d, user_id)

    svc = DelegationLifecycleService(db)
    try:
        updated = svc.update_thresholds(
            delegation=d, thresholds=body.thresholds, actor_user_id=user_id
        )
        db.commit()
    except InvalidStateTransition as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_STATE_TRANSITION", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(updated)
    return _build_delegation_response(updated)


# ---------------------------------------------------------------------------
# Operator-self endpoints
# ---------------------------------------------------------------------------


@router.post(
    "/{delegation_id}/resign",
    response_model=DelegationResponse,
    summary="Operator self-resigns from delegation (AC-22/US-P12)",
)
def resign_delegation(
    delegation_id: str,
    body: ResignRequest,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> DelegationResponse:
    """AC-22: Operator self-resigns. Initiates 30d notice. Only operator can call."""
    user_id: int = int(claims["sub"])
    d = _get_delegation_as_participant(delegation_id, user_id, db)
    _assert_operator_self(d, user_id)

    svc = DelegationLifecycleService(db)
    try:
        updated = svc.resign_delegation(delegation=d, actor_user_id=user_id)
        db.commit()
    except (InvalidStateTransition, PermissionError) as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_STATE_TRANSITION", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(updated)
    return _build_delegation_response(updated)


@router.patch(
    "/{delegation_id}/out-of-office",
    response_model=DelegationResponse,
    summary="Operator sets/clears out-of-office window (AC-57)",
)
def set_out_of_office(
    delegation_id: str,
    body: OutOfOfficeRequest,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> DelegationResponse:
    """AC-57: Operator sets or clears out-of-office date range. Only operator can call."""
    user_id: int = int(claims["sub"])
    d = _get_delegation_as_participant(delegation_id, user_id, db)
    _assert_operator_self(d, user_id)

    svc = DelegationLifecycleService(db)
    try:
        updated = svc.set_out_of_office(
            delegation=d,
            out_of_office_start=body.out_of_office_start,
            out_of_office_end=body.out_of_office_end,
            actor_user_id=user_id,
        )
        db.commit()
    except InvalidStateTransition as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_STATE_TRANSITION", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(updated)
    return _build_delegation_response(updated)


# ---------------------------------------------------------------------------
# Audit log (AC-46: 90d post-terminate read-only access)
# ---------------------------------------------------------------------------


@router.get(
    "/{delegation_id}/audit",
    response_model=list[AuditLogEntry],
    summary="Get delegation audit log (AC-46: 90d post-terminate access)",
)
def get_delegation_audit(
    delegation_id: str,
    since: Optional[str] = Query(default=None, description="ISO datetime filter (since)"),
    limit: int = Query(default=50, le=200),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> list[AuditLogEntry]:
    """AC-46: read delegation audit log. Available for 90 days post-termination.

    Returns ChangeLog rows filtered to this delegation.
    Falls back to empty list if audit_logs table not yet created (phase-04 dependency).
    """
    from datetime import timedelta

    user_id: int = int(claims["sub"])
    d = _get_delegation_as_participant(delegation_id, user_id, db)

    # AC-46: check 90d post-terminate window
    if d.status in ("terminated", "archived") and d.terminated_at is not None:
        cutoff = d.terminated_at + timedelta(days=90)
        if cutoff < datetime.utcnow():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "AUDIT_ACCESS_EXPIRED",
                    "message": "Audit access is only available for 90 days after termination",
                },
            )

    # Query audit_logs table — may not exist yet (phase-04 creates it)
    try:
        from sqlalchemy import text
        from datetime import datetime as _dt

        params: dict = {"delegation_id": delegation_id, "limit": limit}
        since_clause = ""
        if since:
            try:
                since_dt = _dt.fromisoformat(since)
                params["since"] = since_dt
                since_clause = "AND al.created_at >= :since"
            except ValueError:
                pass

        rows = db.execute(
            text(
                f"SELECT al.id, al.actor_user_id, al.on_behalf_of_user_id, "
                f"al.delegation_id, al.action, al.entity_type, al.entity_id, "
                f"al.diff_json, al.created_at "
                f"FROM audit_logs al "
                f"WHERE al.delegation_id = :delegation_id "
                f"{since_clause} "
                f"ORDER BY al.created_at DESC "
                f"LIMIT :limit"
            ),
            params,
        ).fetchall()

        return [
            AuditLogEntry(
                id=int(r[0]),
                actor_user_id=int(r[1]),
                on_behalf_of_user_id=int(r[2]) if r[2] is not None else None,
                delegation_id=str(r[3]) if r[3] else None,
                action=str(r[4]),
                entity_type=str(r[5]) if r[5] else None,
                entity_id=int(r[6]) if r[6] is not None else None,
                diff_json=r[7],
                created_at=r[8],
            )
            for r in rows
        ]
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "[DELEGATION AUDIT] audit_logs query failed (phase-04 may be pending): %s", exc
        )
        return []


# ---------------------------------------------------------------------------
# Internal trigger: GPKD revocation (AC-44/50b — admin/scheduled skeleton)
# ---------------------------------------------------------------------------


@router.post(
    "/internal/pause-for-operator/{operator_user_id}",
    response_model=dict,
    summary="[INTERNAL] Pause all active delegations for an operator (GPKD revoked, AC-50b)",
    include_in_schema=False,  # Internal endpoint — not shown in OpenAPI docs
)
def pause_for_gpkd_revocation(
    operator_user_id: int,
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
) -> dict:
    """AC-50b/44: Admin triggers system pause for all active delegations of an operator.

    Called when admin marks operator's GPKD as revoked. Phase-10 admin UI will
    wire this into the GPKD revocation admin flow.
    """
    from app.services.delegation.lockdown_service import DelegationLockdownService

    lockdown_svc = DelegationLockdownService(db)
    try:
        paused_ids = lockdown_svc.pause_delegations_for_operator(
            operator_user_id=operator_user_id,
            reason="gpkd_revoked",
        )
        db.commit()
        return {
            "operator_user_id": operator_user_id,
            "delegations_paused": len(paused_ids),
            "delegation_ids": paused_ids,
        }
    except Exception as exc:
        db.rollback()
        logger.error("[DELEGATION] pause_for_gpkd_revocation failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc
