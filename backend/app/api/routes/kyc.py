"""KYC and onboarding API routes (Phase 05).

Endpoints:
  Operator individual KYC:
    GET  /api/kyc/operator/individual/status

  Operator business KYC:
    POST /api/kyc/operator/business/info         — step 1
    POST /api/kyc/operator/business/gpkd         — step 2 (multipart)
    POST /api/kyc/operator/business/legal-rep    — step 3 (multipart + JSON)
    GET  /api/kyc/operator/business/me
    POST /api/kyc/operator/business/legal-rep-change  — AC-50b/AC-65

  Digital signature:
    POST /api/kyc/digital-signature/initiate
    POST /api/kyc/digital-signature/callback     — vendor webhook (no auth)

  Owner attestations:
    GET   /api/kyc/owner/sole-ownership-attestation   — AC-64 status
    PATCH /api/kyc/owner/sole-ownership-attestation   — AC-64 record
    POST  /api/kyc/owner/pmc-legal-rep-update         — AC-65 request
    POST  /api/kyc/owner/shared-login-disclosure      — AC-66

  Operator delegation ack:
    PATCH /api/kyc/delegation/{delegation_id}/shared-login-disclosure-ack  — AC-66

  Onboarding status:
    GET /api/kyc/onboarding/status

  Admin:
    GET   /admin/kyc/queue
    POST  /admin/kyc/operator-business/{id}/approve
    POST  /admin/kyc/operator-business/{id}/reject
    PATCH /admin/kyc/operator-business/{id}/revoke-gpkd
    POST  /admin/kyc/operator-business/{id}/approve-legal-rep-change

Auth: require_host for user-facing; require_admin for admin endpoints.
File upload: UploadFile (multipart); stored via sensitive_file_service.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, status
from sqlalchemy.orm import Session

from app.auth import require_host, require_user
from app.database import get_db
from app.schemas.kyc import (
    AdminBusinessApproveRequest,
    AdminBusinessRejectRequest,
    AdminGpkdRevokeRequest,
    AdminKycQueueResponse,
    AdminKycQueueItem,
    BusinessGpkdUploadResponse,
    BusinessInfoRequest,
    BusinessInfoResponse,
    BusinessProfileResponse,
    DigitalSignatureCallbackRequest,
    DigitalSignatureInitiateRequest,
    DigitalSignatureInitiateResponse,
    IndividualKycStatusResponse,
    LegalRepChangeRequest,
    LegalRepInfoRequest,
    LegalRepInfoResponse,
    OnboardingStatusResponse,
    PmcLegalRepUpdateRequest,
    SharedLoginDisclosureAckResponse,
    SharedLoginDisclosureRequest,
    SoleOwnershipAttestationRequest,
    SoleOwnershipAttestationResponse,
)
from app.services.kyc import operator_individual_service, operator_business_service
from app.services.kyc.owner_attestation_service import (
    attest_sole_ownership,
    ack_shared_login_disclosure,
    check_sole_ownership_attested,
    get_sole_ownership_status,
)
from app.services.onboarding.operator_onboarding import get_onboarding_status

logger = logging.getLogger(__name__)

router = APIRouter(tags=["kyc"])

_MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB limit per file


def _require_admin(claims: dict = Depends(require_user)) -> dict:
    """Inline admin-role guard (avoids circular import with shared require_host)."""
    if claims.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "ADMIN_REQUIRED", "message": "Admin role required."},
        )
    return claims


def _get_user_id(claims: dict = Depends(require_host)) -> int:
    return int(claims["sub"])


async def _read_upload(upload: UploadFile) -> tuple[bytes, str]:
    """Read upload file, enforce size limit, return (bytes, extension)."""
    raw = await upload.read()
    if len(raw) > _MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail={
                "code": "FILE_TOO_LARGE",
                "message": f"File exceeds {_MAX_UPLOAD_BYTES // (1024*1024)} MB limit.",
            },
        )
    filename = upload.filename or ""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
    return raw, ext


# ---------------------------------------------------------------------------
# Operator individual KYC
# ---------------------------------------------------------------------------


@router.get(
    "/api/kyc/operator/individual/status",
    response_model=IndividualKycStatusResponse,
    summary="Get operator individual KYC status",
)
def get_individual_kyc_status(
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> IndividualKycStatusResponse:
    """Return KYC completion status for individual operator path (AC-06 gate)."""
    result = operator_individual_service.get_kyc_status_for_user(user_id, db)
    return IndividualKycStatusResponse(**result)


# ---------------------------------------------------------------------------
# Operator business KYC wizard
# ---------------------------------------------------------------------------


@router.post(
    "/api/kyc/operator/business/info",
    response_model=BusinessInfoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Business KYC step 1: submit business info",
)
def submit_business_info(
    payload: BusinessInfoRequest,
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> BusinessInfoResponse:
    """Create or update OperatorBusinessProfile with basic business information."""
    try:
        profile = operator_business_service.submit_business_info(
            user_id=user_id,
            business_name=payload.business_name,
            business_registration_number=payload.business_registration_number,
            gpkd_industry_codes=payload.gpkd_industry_codes,
            db=db,
        )
        db.commit()
        db.refresh(profile)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "BUSINESS_PROFILE_CONFLICT", "message": str(exc)},
        ) from exc

    return BusinessInfoResponse(
        profile_id=profile.id,
        business_name=profile.business_name,
        business_registration_number=profile.business_registration_number,
        verification_status=profile.verification_status,
        created_at=profile.created_at,
    )


@router.post(
    "/api/kyc/operator/business/gpkd",
    response_model=BusinessGpkdUploadResponse,
    summary="Business KYC step 2: upload GPKD document",
)
async def upload_business_gpkd(
    request: Request,
    gpkd_issued_at: str = Form(..., description="GPKD issued date (ISO format)"),
    gpkd_expires_at: Optional[str] = Form(None, description="GPKD expiry date (ISO format)"),
    gpkd_file: UploadFile = File(..., description="GPKD PDF or image"),
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> BusinessGpkdUploadResponse:
    """Upload GPKD (business registration) document — stored encrypted, path never returned."""
    raw, ext = await _read_upload(gpkd_file)

    try:
        issued_at = datetime.fromisoformat(gpkd_issued_at)
        expires_at = datetime.fromisoformat(gpkd_expires_at) if gpkd_expires_at else None
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_DATE_FORMAT", "message": str(exc)},
        ) from exc

    try:
        profile = operator_business_service.submit_business_gpkd(
            user_id=user_id,
            gpkd_bytes=raw,
            gpkd_extension=ext,
            gpkd_issued_at=issued_at,
            gpkd_expires_at=expires_at,
            db=db,
            accessor_ip=request.client.host if request.client else None,
        )
        db.commit()
        db.refresh(profile)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "PROFILE_NOT_FOUND", "message": str(exc)},
        ) from exc

    return BusinessGpkdUploadResponse(
        profile_id=profile.id,
        gpkd_stored=True,
        gpkd_issued_at=profile.gpkd_issued_at,
        gpkd_expires_at=profile.gpkd_expires_at,
    )


@router.post(
    "/api/kyc/operator/business/legal-rep",
    response_model=LegalRepInfoResponse,
    summary="Business KYC step 3: submit legal representative CCCD",
)
async def submit_legal_rep(
    request: Request,
    legal_representative_name: str = Form(...),
    legal_representative_cccd_number: str = Form(...),
    legal_representative_phone: str = Form(...),
    cccd_front: UploadFile = File(..., description="CCCD front image"),
    cccd_back: UploadFile = File(..., description="CCCD back image"),
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> LegalRepInfoResponse:
    """Upload legal representative CCCD images + hash (step 3 of business KYC wizard)."""
    # Validate text fields via Pydantic schema
    try:
        form_data = LegalRepInfoRequest(
            legal_representative_name=legal_representative_name,
            legal_representative_cccd_number=legal_representative_cccd_number,
            legal_representative_phone=legal_representative_phone,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VALIDATION_ERROR", "message": str(exc)},
        ) from exc

    front_bytes, front_ext = await _read_upload(cccd_front)
    back_bytes, back_ext = await _read_upload(cccd_back)
    # Use front extension for both (usually same format)
    cccd_ext = front_ext or back_ext or "jpg"

    try:
        profile = operator_business_service.submit_legal_rep_info(
            user_id=user_id,
            legal_rep_name=form_data.legal_representative_name,
            legal_rep_cccd_number=form_data.legal_representative_cccd_number,
            legal_rep_phone=form_data.legal_representative_phone,
            cccd_front_bytes=front_bytes,
            cccd_back_bytes=back_bytes,
            cccd_extension=cccd_ext,
            db=db,
            accessor_ip=request.client.host if request.client else None,
        )
        db.commit()
        db.refresh(profile)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "PROFILE_NOT_FOUND", "message": str(exc)},
        ) from exc

    return LegalRepInfoResponse(
        profile_id=profile.id,
        legal_representative_name=profile.legal_representative_name,
        verification_status=profile.verification_status,
    )


@router.get(
    "/api/kyc/operator/business/me",
    response_model=BusinessProfileResponse,
    summary="Get my business operator profile",
)
def get_business_profile_me(
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> BusinessProfileResponse:
    """Return operator business profile (no file paths in response)."""
    profile = operator_business_service.get_business_profile_for_user(user_id, db)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": "BUSINESS_PROFILE_NOT_FOUND",
                "message": "No business operator profile found. Submit business info first.",
            },
        )

    return BusinessProfileResponse(
        profile_id=profile.id,
        user_id=profile.user_id,
        business_name=profile.business_name,
        business_registration_number=profile.business_registration_number,
        gpkd_industry_codes=profile.gpkd_industry_codes_json or [],
        gpkd_issued_at=profile.gpkd_issued_at,
        gpkd_expires_at=profile.gpkd_expires_at,
        legal_representative_name=profile.legal_representative_name,
        legal_representative_phone=profile.legal_representative_phone,
        verification_status=profile.verification_status,
        verified_at=profile.verified_at,
        legal_rep_changed_at=profile.legal_rep_changed_at,
        created_at=profile.created_at,
    )


@router.post(
    "/api/kyc/operator/business/legal-rep-change",
    response_model=LegalRepInfoResponse,
    summary="Initiate legal representative change (AC-50b / AC-65)",
)
async def initiate_legal_rep_change(
    request: Request,
    new_legal_representative_name: str = Form(...),
    new_legal_representative_cccd_number: str = Form(...),
    new_legal_representative_phone: str = Form(...),
    reason: str = Form(...),
    cccd_front: UploadFile = File(...),
    cccd_back: UploadFile = File(...),
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> LegalRepInfoResponse:
    """Submit new legal representative for admin review (AC-65).

    Transitions business profile to 'pending_legal_rep_change'.
    Active delegations should be paused by caller or phase-03 cron.
    """
    try:
        form_data = LegalRepChangeRequest(
            new_legal_representative_name=new_legal_representative_name,
            new_legal_representative_cccd_number=new_legal_representative_cccd_number,
            new_legal_representative_phone=new_legal_representative_phone,
            reason=reason,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VALIDATION_ERROR", "message": str(exc)},
        ) from exc

    front_bytes, front_ext = await _read_upload(cccd_front)
    back_bytes, _ = await _read_upload(cccd_back)

    # Get profile for this user
    existing_profile = operator_business_service.get_business_profile_for_user(user_id, db)
    if existing_profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "BUSINESS_PROFILE_NOT_FOUND", "message": "No business profile found."},
        )

    try:
        profile = operator_business_service.initiate_legal_rep_change(
            profile_id=existing_profile.id,
            new_legal_rep_name=form_data.new_legal_representative_name,
            new_cccd_number=form_data.new_legal_representative_cccd_number,
            new_phone=form_data.new_legal_representative_phone,
            new_cccd_front_bytes=front_bytes,
            new_cccd_back_bytes=back_bytes,
            cccd_extension=front_ext or "jpg",
            reason=form_data.reason,
            db=db,
            accessor_ip=request.client.host if request.client else None,
        )
        db.commit()
        db.refresh(profile)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "LEGAL_REP_CHANGE_CONFLICT", "message": str(exc)},
        ) from exc

    return LegalRepInfoResponse(
        profile_id=profile.id,
        legal_representative_name=profile.legal_representative_name,
        verification_status=profile.verification_status,
    )


# ---------------------------------------------------------------------------
# Digital signature
# ---------------------------------------------------------------------------


@router.post(
    "/api/kyc/digital-signature/initiate",
    response_model=DigitalSignatureInitiateResponse,
    summary="Initiate digital signature session (AS-14 / AC-55d)",
)
def initiate_digital_signature(
    payload: DigitalSignatureInitiateRequest,
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> DigitalSignatureInitiateResponse:
    """Initiate a signing session via configured provider (stub / FastCA / VinaCA).

    Returns status='signed_stub' when DIGITAL_SIGNATURE_PROVIDER=stub (v0 default).
    Pre-launch gate AS-14 must be satisfied before enabling real vendor.
    """
    from app.services.kyc.digital_signature import get_provider
    from app.models import User

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    provider = get_provider()

    # Stub: use a minimal placeholder document for v0
    doc_bytes = b"POA_STUB_DOCUMENT"
    doc_name = payload.document_name

    try:
        result = provider.initiate_signing(
            user_phone=user.phone or "",
            document_bytes=doc_bytes,
            document_name=doc_name,
            metadata={"delegation_id": payload.delegation_id, "user_id": user_id},
        )
    except Exception as exc:
        logger.error(
            "kyc_routes: digital_signature initiate failed user=%s error=%s",
            user_id,
            exc,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "DIGITAL_SIGNATURE_UNAVAILABLE",
                "message": str(exc),
            },
        ) from exc

    provider_name = type(provider).__name__.replace("Provider", "").lower()
    return DigitalSignatureInitiateResponse(
        status=result.status.value,
        signature_ref=result.signature_ref,
        session_url=result.session_url,
        provider=provider_name,
    )


@router.post(
    "/api/kyc/digital-signature/callback",
    summary="Digital signature vendor webhook callback (no auth — vendor-signed)",
)
def digital_signature_callback(
    payload: DigitalSignatureCallbackRequest,
    request: Request,
) -> dict:
    """Handle vendor webhook callback for signature completion.

    No JWT auth (vendor calls this). HMAC verification is done by provider.
    Per AS-14 contract: vendor sends HMAC-SHA256 in X-Vendor-Signature header.
    """
    from app.services.kyc.digital_signature import get_provider

    vendor_sig = request.headers.get("X-Vendor-Signature")
    provider = get_provider()

    try:
        result = provider.verify_callback(
            payload=payload.model_dump(exclude_none=True),
            vendor_signature=vendor_sig,
        )
    except Exception as exc:
        logger.error("kyc_routes: digital_signature callback error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "CALLBACK_INVALID", "message": str(exc)},
        ) from exc

    logger.info(
        "kyc_routes: digital_signature callback processed ref=%s status=%s",
        result.signature_ref,
        result.status.value,
    )
    return {"received": True, "status": result.status.value, "ref": result.signature_ref}


# ---------------------------------------------------------------------------
# Owner attestations
# ---------------------------------------------------------------------------


@router.get(
    "/api/kyc/owner/sole-ownership-attestation",
    response_model=SoleOwnershipAttestationResponse,
    summary="Get AC-64 sole-ownership attestation status",
)
def get_sole_ownership_attestation(
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> SoleOwnershipAttestationResponse:
    """Return whether the user has completed sole-ownership attestation (AC-64)."""
    result = get_sole_ownership_status(user_id, db)
    attested = result["attested_at"] is not None
    return SoleOwnershipAttestationResponse(
        attested_at=result["attested_at"],  # type: ignore[arg-type]
        attested=attested,
    )


@router.patch(
    "/api/kyc/owner/sole-ownership-attestation",
    response_model=SoleOwnershipAttestationResponse,
    summary="Record AC-64 sole-ownership attestation",
)
def record_sole_ownership_attestation(
    payload: SoleOwnershipAttestationRequest,
    request: Request,
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> SoleOwnershipAttestationResponse:
    """Record that owner attests sole ownership (AC-64). Idempotent.

    One-way: cannot be revoked by user in v1 (admin-assist per AS-15).
    """
    try:
        user = attest_sole_ownership(
            user_id=user_id,
            db=db,
            ip_address=request.client.host if request.client else None,
            user_agent=request.headers.get("User-Agent"),
        )
        db.commit()
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "USER_NOT_FOUND", "message": str(exc)},
        ) from exc

    attested_at = user.sole_ownership_attested_at
    return SoleOwnershipAttestationResponse(
        attested_at=attested_at,
        attested=attested_at is not None,
    )


@router.post(
    "/api/kyc/owner/pmc-legal-rep-update",
    response_model=LegalRepInfoResponse,
    summary="Owner-initiated PMC legal-rep update (AC-65)",
)
async def pmc_legal_rep_update(
    request: Request,
    profile_id: int = Form(...),
    new_legal_representative_name: str = Form(...),
    new_legal_representative_cccd_number: str = Form(...),
    new_legal_representative_phone: str = Form(...),
    reason: str = Form(...),
    cccd_front: UploadFile = File(...),
    cccd_back: UploadFile = File(...),
    claims: dict = Depends(require_user),
    db: Session = Depends(get_db),
) -> LegalRepInfoResponse:
    """Admin-reviewed legal-rep change workflow (AC-65).

    Owner or admin can trigger. Admin reviews new CCCD before approving.
    """
    front_bytes, front_ext = await _read_upload(cccd_front)
    back_bytes, _ = await _read_upload(cccd_back)

    try:
        profile = operator_business_service.initiate_legal_rep_change(
            profile_id=profile_id,
            new_legal_rep_name=new_legal_representative_name,
            new_cccd_number=new_legal_representative_cccd_number,
            new_phone=new_legal_representative_phone,
            new_cccd_front_bytes=front_bytes,
            new_cccd_back_bytes=back_bytes,
            cccd_extension=front_ext or "jpg",
            reason=reason,
            db=db,
            accessor_ip=request.client.host if request.client else None,
        )
        db.commit()
        db.refresh(profile)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "LEGAL_REP_CHANGE_ERROR", "message": str(exc)},
        ) from exc

    return LegalRepInfoResponse(
        profile_id=profile.id,
        legal_representative_name=profile.legal_representative_name,
        verification_status=profile.verification_status,
    )


@router.post(
    "/api/kyc/owner/shared-login-disclosure",
    response_model=SharedLoginDisclosureAckResponse,
    summary="AC-66: owner acknowledges shared-login disclosure",
)
def owner_shared_login_disclosure(
    payload: SharedLoginDisclosureRequest,
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> SharedLoginDisclosureAckResponse:
    """Record AC-66 shared-login disclosure on behalf of an operator delegation."""
    try:
        delegation = ack_shared_login_disclosure(
            delegation_id=payload.delegation_id,
            operator_user_id=user_id,
            db=db,
        )
        db.commit()
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "DELEGATION_NOT_FOUND", "message": str(exc)},
        ) from exc

    ack_at = getattr(delegation, "shared_login_disclosure_ack_at", None)
    return SharedLoginDisclosureAckResponse(
        delegation_id=payload.delegation_id,
        shared_login_disclosure_ack_at=ack_at,
        ack_recorded=ack_at is not None,
    )


# ---------------------------------------------------------------------------
# Operator delegation ack (AC-66)
# ---------------------------------------------------------------------------


@router.patch(
    "/api/kyc/delegation/{delegation_id}/shared-login-disclosure-ack",
    response_model=SharedLoginDisclosureAckResponse,
    summary="AC-66: operator acks shared-login disclosure on delegation",
)
def ack_delegation_shared_login_disclosure(
    delegation_id: str,
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> SharedLoginDisclosureAckResponse:
    """Operator acknowledges shared-login disclosure for a delegation (AC-66).

    Idempotent. Delegation transitions to active if all KYC gates are also met
    (handled by phase-03 state machine on next sync).
    """
    try:
        delegation = ack_shared_login_disclosure(
            delegation_id=delegation_id,
            operator_user_id=user_id,
            db=db,
        )
        db.commit()
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND_OR_FORBIDDEN", "message": str(exc)},
        ) from exc

    ack_at = getattr(delegation, "shared_login_disclosure_ack_at", None)
    return SharedLoginDisclosureAckResponse(
        delegation_id=delegation_id,
        shared_login_disclosure_ack_at=ack_at,
        ack_recorded=ack_at is not None,
    )


# ---------------------------------------------------------------------------
# Onboarding status
# ---------------------------------------------------------------------------


@router.get(
    "/api/kyc/onboarding/status",
    response_model=OnboardingStatusResponse,
    summary="Full operator onboarding status (individual + business)",
)
def onboarding_status(
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
) -> OnboardingStatusResponse:
    """Return full onboarding status for Flutter UI progress indicators."""
    result = get_onboarding_status(user_id, db)
    if "error" in result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "USER_NOT_FOUND", "message": result["error"]},
        )
    return OnboardingStatusResponse(**result)


# ---------------------------------------------------------------------------
# Admin endpoints
# ---------------------------------------------------------------------------


@router.get(
    "/admin/kyc/queue",
    response_model=AdminKycQueueResponse,
    summary="Admin KYC review queue",
)
def admin_kyc_queue(
    kyc_type: Optional[str] = None,
    kyc_status: Optional[str] = None,
    admin_claims: dict = Depends(_require_admin),
    db: Session = Depends(get_db),
) -> AdminKycQueueResponse:
    """Return list of pending KYC submissions for admin review.

    Query params: type=individual|business, status=pending|rejected|...
    Phase-10 admin UI consumes this endpoint.
    """
    from app.domain.operator_business import OperatorBusinessProfile

    query = db.query(OperatorBusinessProfile)
    if kyc_status:
        query = query.filter(OperatorBusinessProfile.verification_status == kyc_status)

    profiles = query.order_by(OperatorBusinessProfile.created_at.asc()).all()

    now = __import__("datetime").datetime.utcnow()
    items: list[AdminKycQueueItem] = []
    for p in profiles:
        # Overdue = pending for > 48h (BA SLA)
        age_hours = (now - p.created_at).total_seconds() / 3600
        overdue = p.verification_status == "pending" and age_hours > 48
        items.append(
            AdminKycQueueItem(
                profile_id=p.id,
                user_id=p.user_id,
                kyc_type="business",
                verification_status=p.verification_status,
                business_name=p.business_name,
                legal_representative_name=p.legal_representative_name,
                submitted_at=p.created_at,
                overdue=overdue,
            )
        )

    return AdminKycQueueResponse(items=items, total=len(items))


@router.post(
    "/admin/kyc/operator-business/{profile_id}/approve",
    response_model=LegalRepInfoResponse,
    summary="Admin approve business KYC",
)
def admin_approve_business_kyc(
    profile_id: int,
    payload: AdminBusinessApproveRequest,
    admin_claims: dict = Depends(_require_admin),
    db: Session = Depends(get_db),
) -> LegalRepInfoResponse:
    """Admin approves operator business KYC → status='verified'."""
    admin_id = int(admin_claims["sub"])
    try:
        profile = operator_business_service.admin_approve_business(
            profile_id=profile_id,
            admin_user_id=admin_id,
            db=db,
        )
        db.commit()
        db.refresh(profile)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "APPROVE_CONFLICT", "message": str(exc)},
        ) from exc

    return LegalRepInfoResponse(
        profile_id=profile.id,
        legal_representative_name=profile.legal_representative_name,
        verification_status=profile.verification_status,
    )


@router.post(
    "/admin/kyc/operator-business/{profile_id}/reject",
    response_model=LegalRepInfoResponse,
    summary="Admin reject business KYC",
)
def admin_reject_business_kyc(
    profile_id: int,
    payload: AdminBusinessRejectRequest,
    admin_claims: dict = Depends(_require_admin),
    db: Session = Depends(get_db),
) -> LegalRepInfoResponse:
    """Admin rejects operator business KYC with a reason."""
    admin_id = int(admin_claims["sub"])
    try:
        profile = operator_business_service.admin_reject_business(
            profile_id=profile_id,
            admin_user_id=admin_id,
            reason=payload.reason,
            db=db,
        )
        db.commit()
        db.refresh(profile)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "REJECT_CONFLICT", "message": str(exc)},
        ) from exc

    return LegalRepInfoResponse(
        profile_id=profile.id,
        legal_representative_name=profile.legal_representative_name,
        verification_status=profile.verification_status,
    )


@router.patch(
    "/admin/kyc/operator-business/{profile_id}/revoke-gpkd",
    response_model=LegalRepInfoResponse,
    summary="Admin revoke GPKD (AC-61)",
)
def admin_revoke_gpkd(
    profile_id: int,
    payload: AdminGpkdRevokeRequest,
    admin_claims: dict = Depends(_require_admin),
    db: Session = Depends(get_db),
) -> LegalRepInfoResponse:
    """Admin revokes GPKD → status='revoked'; phase-03 cron auto-pauses delegations."""
    admin_id = int(admin_claims["sub"])
    try:
        profile = operator_business_service.admin_revoke_gpkd(
            profile_id=profile_id,
            admin_user_id=admin_id,
            db=db,
        )
        db.commit()
        db.refresh(profile)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "REVOKE_CONFLICT", "message": str(exc)},
        ) from exc

    return LegalRepInfoResponse(
        profile_id=profile.id,
        legal_representative_name=profile.legal_representative_name,
        verification_status=profile.verification_status,
    )


@router.post(
    "/admin/kyc/operator-business/{profile_id}/approve-legal-rep-change",
    response_model=LegalRepInfoResponse,
    summary="Admin approve legal-rep change (AC-65)",
)
def admin_approve_legal_rep_change(
    profile_id: int,
    admin_claims: dict = Depends(_require_admin),
    db: Session = Depends(get_db),
) -> LegalRepInfoResponse:
    """Admin approves legal-rep change; old credentials invalidated within 48h (AC-65)."""
    admin_id = int(admin_claims["sub"])
    try:
        profile = operator_business_service.admin_approve_legal_rep_change(
            profile_id=profile_id,
            admin_user_id=admin_id,
            db=db,
        )
        db.commit()
        db.refresh(profile)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "LEGAL_REP_CHANGE_APPROVE_CONFLICT", "message": str(exc)},
        ) from exc

    return LegalRepInfoResponse(
        profile_id=profile.id,
        legal_representative_name=profile.legal_representative_name,
        verification_status=profile.verification_status,
    )
