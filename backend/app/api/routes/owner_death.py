"""Owner death workflow API routes — Phase 06.

Endpoints:
  POST   /api/owner-death/report              — heir/admin/operator reports owner death
  POST   /api/admin/owner-death/{id}/verify   — admin verifies death cert → triggers 7d pause
  POST   /api/admin/owner-death/{id}/reject   — admin rejects (insufficient evidence)
  GET    /api/owner-death/{owner_id}          — status view (heir/operator/admin)
  POST   /api/owner-death/{id}/designate-heir — admin sets heir + creates inherit_view
  GET    /api/admin/owner-death/pending       — admin list of pending certs (US-A6)

Executor exception endpoints (AC-58d — gated by OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED):
  GET    /api/owner-death/{id}/eligible-approvals   — list in-flight approvals for executor
  POST   /api/owner-death/{id}/executor-decision    — executor approves/rejects in-flight approval

Security:
  - Admin-only routes: require_admin dependency.
  - Heir/participant routes: require_user, IDOR guard (cert.owner_user_id in owner's certs).
  - All mutations write audit log via logger (phase-02 full audit writer not available in v1).
  - Death cert file paths validated against path traversal at schema level.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app import auth
from app.database import get_db
from app.domain.owner_death import OwnerDeathCertificate
from app.schemas.owner_death import (
    DeathCertificateResponse,
    DeathRejectRequest,
    DeathReportRequest,
    DeathStatusResponse,
    DeathVerifyRequest,
    DeathVerifyResponse,
    ExecutorDecisionRequest,
    ExecutorDecisionResponse,
    HeirDesignateRequest,
    HeirDesignateResponse,
)
from app.services.owner_death import (
    DeathCertificateService,
    DeathPauseService,
    ExecutorExceptionService,
    HeirDesignationService,
)
from app.services.owner_death.death_certificate_service import (
    CertificateNotFoundError,
    DuplicateCertificateError,
    InvalidVerificationStateError,
)
from app.services.owner_death.executor_exception_service import (
    ExecutorExceptionDisabledError,
    ExecutorNotAuthorizedError,
)
from app.services.owner_death.heir_designation_service import HeirDesignationError

logger = logging.getLogger(__name__)

router = APIRouter(tags=["owner_death"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _to_response(cert: OwnerDeathCertificate) -> DeathCertificateResponse:
    return DeathCertificateResponse(
        id=str(cert.id),
        owner_user_id=int(cert.owner_user_id),
        submitted_by_user_id=int(cert.submitted_by_user_id) if cert.submitted_by_user_id else None,
        death_certificate_path=str(cert.death_certificate_path),
        notarized_poa_path=cert.notarized_poa_path,
        verification_status=str(cert.verification_status),
        verified_at=cert.verified_at,
        verified_by_admin_id=int(cert.verified_by_admin_id) if cert.verified_by_admin_id else None,
        executor_user_id=int(cert.executor_user_id) if cert.executor_user_id else None,
        executor_onboarded_at=cert.executor_onboarded_at,
        created_at=cert.created_at,
    )


def _load_cert_or_404(cert_id: str, db: Session) -> OwnerDeathCertificate:
    svc = DeathCertificateService(db)
    cert = svc.get_by_id(cert_id)
    if cert is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "DEATH_CERT_NOT_FOUND", "message": f"Certificate {cert_id} not found"},
        )
    return cert


# ---------------------------------------------------------------------------
# Public (authenticated) — report owner death
# ---------------------------------------------------------------------------


@router.post(
    "/api/owner-death/report",
    response_model=DeathCertificateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Report owner death (AC-58) — heir/operator/admin",
)
def report_owner_death(
    body: DeathReportRequest,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> DeathCertificateResponse:
    """AC-58: Report a property owner's death.

    Creates a pending death certificate record. Admin must verify within 24h (US-A7).
    One record per owner — subsequent reports return 409.
    """
    submitter_id: int = int(claims["sub"])
    svc = DeathCertificateService(db)

    try:
        cert = svc.report_death(
            owner_user_id=body.owner_user_id,
            death_certificate_path=body.death_certificate_path,
            submitted_by_user_id=submitter_id,
            notarized_poa_path=body.notarized_poa_path,
            executor_user_id=body.executor_user_id,
        )
        db.commit()
    except DuplicateCertificateError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DUPLICATE_DEATH_CERTIFICATE",
                "message": str(exc),
                "existing_id": exc.existing_id,
            },
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VALIDATION_ERROR", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        logger.error("[OWNER_DEATH] report_death failed: %s", exc, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"code": "INTERNAL_ERROR", "message": str(exc)},
        ) from exc

    db.refresh(cert)
    return _to_response(cert)


# ---------------------------------------------------------------------------
# Admin — verify death certificate
# ---------------------------------------------------------------------------


@router.post(
    "/api/admin/owner-death/{cert_id}/verify",
    response_model=DeathVerifyResponse,
    summary="Admin verifies death certificate → triggers 7-day delegation pause (AC-58)",
)
def verify_death_certificate(
    cert_id: str,
    body: DeathVerifyRequest,
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
) -> DeathVerifyResponse:
    """Admin verifies the death certificate.

    On success:
      - Sets certificate status → 'verified'
      - Pauses ALL active delegations for the owner for 7 days
      - Returns count of delegations paused
      - Emits SLA warning if verification exceeded 24h
    """
    admin_id: int = int(claims["sub"])
    cert = _load_cert_or_404(cert_id, db)

    cert_svc = DeathCertificateService(db)
    pause_svc = DeathPauseService(db)

    try:
        cert = cert_svc.verify_death(
            cert_id=cert_id,
            admin_user_id=admin_id,
            notes=body.notes,
            in_flight_handling_policy=body.in_flight_handling_policy,
        )
        # Trigger 7-day pause on all owner delegations
        paused_ids = pause_svc.pause_all_owner_delegations(cert=cert, admin_user_id=admin_id)
        db.commit()
    except InvalidVerificationStateError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_CERT_STATE", "message": str(exc)},
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VALIDATION_ERROR", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        logger.error("[OWNER_DEATH] verify failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(cert)
    from app.services.owner_death.death_certificate_service import _hours_since
    from datetime import datetime
    sla_hours = _hours_since(cert.created_at, datetime.utcnow())

    return DeathVerifyResponse(
        certificate=_to_response(cert),
        delegations_paused=len(paused_ids),
        delegation_ids_paused=paused_ids,
        sla_warning=sla_hours > 24,
    )


# ---------------------------------------------------------------------------
# Admin — reject death certificate
# ---------------------------------------------------------------------------


@router.post(
    "/api/admin/owner-death/{cert_id}/reject",
    response_model=DeathCertificateResponse,
    summary="Admin rejects death certificate (insufficient evidence)",
)
def reject_death_certificate(
    cert_id: str,
    body: DeathRejectRequest,
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
) -> DeathCertificateResponse:
    """Admin rejects the death certificate due to insufficient evidence."""
    admin_id: int = int(claims["sub"])
    cert = _load_cert_or_404(cert_id, db)

    cert_svc = DeathCertificateService(db)

    try:
        cert = cert_svc.reject_death(
            cert_id=cert_id,
            admin_user_id=admin_id,
            rejection_reason=body.rejection_reason,
        )
        db.commit()
    except InvalidVerificationStateError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_CERT_STATE", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        logger.error("[OWNER_DEATH] reject failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(cert)
    return _to_response(cert)


# ---------------------------------------------------------------------------
# View status (heir/operator/admin)
# ---------------------------------------------------------------------------


@router.get(
    "/api/owner-death/{owner_user_id}",
    response_model=DeathStatusResponse,
    summary="View death workflow status for an owner",
)
def get_death_status(
    owner_user_id: int,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> DeathStatusResponse:
    """View the death certificate status for an owner.

    Access: admin always, or the owner themselves, or the designated heir/executor.
    IDOR: non-admin users can only query their own owner_user_id or where they are executor.
    """
    caller_id: int = int(claims["sub"])
    is_admin = claims.get("role") == "admin"

    cert_svc = DeathCertificateService(db)
    cert = cert_svc.get_by_owner(owner_user_id)

    # IDOR guard for non-admin
    if not is_admin:
        is_owner = (caller_id == owner_user_id)
        is_heir = (cert is not None and cert.executor_user_id is not None and
                   int(cert.executor_user_id) == caller_id)
        if not is_owner and not is_heir:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "ACCESS_DENIED",
                    "message": "You can only view your own death certificate status",
                },
            )

    if cert is None:
        return DeathStatusResponse(
            owner_user_id=owner_user_id,
            certificate=None,
            delegations_paused_count=0,
            has_heir_window=False,
            message="No death certificate record found for this owner",
        )

    pause_svc = DeathPauseService(db)
    has_heir_window = pause_svc.has_active_heir_window(owner_user_id)

    # Count paused delegations
    from app.domain.delegation import Delegation
    paused_count = (
        db.query(Delegation)
        .filter(
            Delegation.owner_id == owner_user_id,
            Delegation.status == "paused",
            Delegation.paused_reason == "owner_death",
        )
        .count()
    )

    return DeathStatusResponse(
        owner_user_id=owner_user_id,
        certificate=_to_response(cert),
        delegations_paused_count=paused_count,
        has_heir_window=has_heir_window,
        message=f"Death certificate status: {cert.verification_status}",
    )


# ---------------------------------------------------------------------------
# Admin — list pending certificates (US-A6 admin panel)
# ---------------------------------------------------------------------------


@router.get(
    "/api/admin/owner-death/pending",
    response_model=list[DeathCertificateResponse],
    summary="Admin list pending death certificates for review (US-A6)",
)
def list_pending_certificates(
    limit: int = Query(default=50, le=200),
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
) -> list[DeathCertificateResponse]:
    """List death certificates pending admin verification, oldest-first (FIFO SLA)."""
    cert_svc = DeathCertificateService(db)
    certs = cert_svc.list_pending(limit=limit)
    return [_to_response(c) for c in certs]


# ---------------------------------------------------------------------------
# Admin — designate heir + create inherit_view delegation
# ---------------------------------------------------------------------------


@router.post(
    "/api/owner-death/{cert_id}/designate-heir",
    response_model=HeirDesignateResponse,
    summary="Admin designates heir user after legal docs verified (AC-58b)",
)
def designate_heir(
    cert_id: str,
    body: HeirDesignateRequest,
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
) -> HeirDesignateResponse:
    """AC-58b: Admin designates heir after legal docs are uploaded and verified.

    If create_inherit_view=True (default), also creates an inherit_view delegation
    giving the heir temporary read-only access for 30 days.
    """
    admin_id: int = int(claims["sub"])
    cert = _load_cert_or_404(cert_id, db)

    heir_svc = HeirDesignationService(db)
    inherit_delegation_id: Optional[str] = None

    try:
        cert = heir_svc.designate_heir(
            cert=cert,
            heir_user_id=body.heir_user_id,
            admin_user_id=admin_id,
        )
        if body.create_inherit_view:
            delegation = heir_svc.create_inherit_view_delegation(
                cert=cert,
                heir_user_id=body.heir_user_id,
                admin_user_id=admin_id,
            )
            inherit_delegation_id = str(delegation.id)
        db.commit()
    except HeirDesignationError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "HEIR_DESIGNATION_ERROR", "message": str(exc)},
        ) from exc
    except Exception as exc:
        db.rollback()
        logger.error("[OWNER_DEATH] designate_heir failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    db.refresh(cert)
    return HeirDesignateResponse(
        certificate=_to_response(cert),
        inherit_view_delegation_id=inherit_delegation_id,
    )


# ---------------------------------------------------------------------------
# Executor exception endpoints (AC-58d — gated by feature flag)
# ---------------------------------------------------------------------------


@router.get(
    "/api/owner-death/{cert_id}/eligible-approvals",
    response_model=list[dict],
    summary="[AC-58d] List in-flight approvals eligible for executor decision (gate O3 required)",
)
def list_eligible_approvals(
    cert_id: str,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    """List delegation approvals that were in-flight at time of owner's death.

    Requires OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED=true (gate O3).
    Only the designated executor can call this endpoint.
    """
    executor_svc = ExecutorExceptionService(db)

    try:
        executor_svc.check_enabled()
    except ExecutorExceptionDisabledError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "EXECUTOR_EXCEPTION_DISABLED", "message": str(exc)},
        ) from exc

    cert = _load_cert_or_404(cert_id, db)

    caller_id: int = int(claims["sub"])
    try:
        executor_svc.validate_executor(
            executor_user_id=caller_id,
            cert_executor_user_id=int(cert.executor_user_id) if cert.executor_user_id else None,
        )
    except ExecutorNotAuthorizedError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "NOT_EXECUTOR", "message": str(exc)},
        ) from exc

    verified_at = cert.verified_at
    if verified_at is None:
        return []

    return executor_svc.list_eligible_approvals(
        owner_user_id=int(cert.owner_user_id),
        cert_verified_at=verified_at,
    )


@router.post(
    "/api/owner-death/{cert_id}/executor-decision",
    response_model=ExecutorDecisionResponse,
    summary="[AC-58d] Executor approves/rejects an in-flight approval (gate O3 required)",
)
def executor_decision(
    cert_id: str,
    body: ExecutorDecisionRequest,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> ExecutorDecisionResponse:
    """AC-58d: Executor makes a decision on an in-flight approval.

    Requires OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED=true (gate O3 legal sign-off).
    Marks decision with executor_override=True in audit log.
    """
    executor_svc = ExecutorExceptionService(db)

    try:
        executor_svc.check_enabled()
    except ExecutorExceptionDisabledError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "EXECUTOR_EXCEPTION_DISABLED", "message": str(exc)},
        ) from exc

    cert = _load_cert_or_404(cert_id, db)

    caller_id: int = int(claims["sub"])
    try:
        executor_svc.validate_executor(
            executor_user_id=caller_id,
            cert_executor_user_id=int(cert.executor_user_id) if cert.executor_user_id else None,
        )
    except ExecutorNotAuthorizedError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "NOT_EXECUTOR", "message": str(exc)},
        ) from exc

    try:
        audit_entry = executor_svc.record_executor_decision(
            approval_id=body.approval_id,
            executor_user_id=caller_id,
            decision=body.decision,
            cert_id=cert_id,
            notes=body.notes,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VALIDATION_ERROR", "message": str(exc)},
        ) from exc
    except Exception as exc:
        logger.error("[OWNER_DEATH] executor_decision failed: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail={"code": "INTERNAL_ERROR"}) from exc

    return ExecutorDecisionResponse(
        approval_id=audit_entry["approval_id"],
        decision=audit_entry["decision"],
        executor_override=True,
        decision_by_executor=True,
        decided_at=audit_entry["decided_at"],
        notes=audit_entry.get("notes"),
    )
