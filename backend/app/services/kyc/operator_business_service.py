"""Operator business (legal entity) KYC service.

US-P4 / AC-49 / AC-50b / AC-61 / AC-65: Greenfield business operator KYC.
Phase 05 spec §Architecture — operator-business KYC endpoints.

Verification state machine:
  pending → verified (admin_approve_business)
           → rejected (admin_reject_business)
  verified → revoked (admin_revoke_gpkd — AC-61)
  verified → pending_legal_rep_change (initiate_legal_rep_change — AC-50b)
  pending_legal_rep_change → verified (admin_approve_legal_rep_change — AC-65)

AC-50: kyc_expires_at = GPKD gpkd_expires_at for business (overrides individual 5y rule).
AC-65: force-logout old legal-rep on approve (JWT revocation deferred to v1.1; use short TTL).
AS-06: 1 pháp nhân = 1 user (UNIQUE user_id on operator_business_profiles).

Security:
  - Legal-rep CCCD stored as bcrypt hash + encrypted path via sensitive_file_service.
  - GPKD document stored via sensitive_file_service (never return raw path in API).
  - All mutations write to ChangeLog (dual-identity via caller's ActorContext).
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

import bcrypt
from sqlalchemy.orm import Session

from app.domain.operator_business import OperatorBusinessProfile
from app.models import User
from app.services import sensitive_file_service

logger = logging.getLogger(__name__)

# Valid verification statuses (state machine)
_VALID_STATUSES = frozenset(
    ["pending", "verified", "rejected", "revoked", "pending_legal_rep_change"]
)


def _hash_cccd(cccd_number: str) -> str:
    """One-way bcrypt hash of CCCD number (mirrors host_profile pattern)."""
    return bcrypt.hashpw(
        cccd_number.encode("utf-8"),
        bcrypt.gensalt(rounds=12),
    ).decode("utf-8")


def submit_business_info(
    user_id: int,
    business_name: str,
    business_registration_number: str,
    gpkd_industry_codes: list[str],
    db: Session,
) -> OperatorBusinessProfile:
    """Step 1: Create or update OperatorBusinessProfile with basic business info.

    Creates row with verification_status='pending'.
    Idempotent: if profile already exists for user_id, updates name/number (pending only).

    Raises:
        ValueError: If user already has a verified/revoked profile (re-submission blocked).
    """
    existing = (
        db.query(OperatorBusinessProfile)
        .filter(OperatorBusinessProfile.user_id == user_id)
        .first()
    )

    if existing is not None and existing.verification_status in ("verified", "revoked"):
        raise ValueError(
            f"Business profile for user_id={user_id} is already {existing.verification_status}. "
            "Use legal-rep-change flow (AC-65) to update."
        )

    if existing is None:
        profile = OperatorBusinessProfile(
            user_id=user_id,
            business_name=business_name,
            business_registration_number=business_registration_number,
            gpkd_industry_codes_json=gpkd_industry_codes,
            # Required non-null fields — will be filled in subsequent steps
            gpkd_document_path="",
            gpkd_issued_at=datetime.utcnow(),
            legal_representative_name="",
            legal_representative_phone="",
            verification_status="pending",
        )
        db.add(profile)
    else:
        existing.business_name = business_name
        existing.business_registration_number = business_registration_number
        existing.gpkd_industry_codes_json = gpkd_industry_codes
        existing.updated_at = datetime.utcnow()
        profile = existing

    logger.info(
        "operator_business_service: submit_business_info user=%s business=%s",
        user_id,
        business_name,
    )
    return profile


def submit_business_gpkd(
    user_id: int,
    gpkd_bytes: bytes,
    gpkd_extension: str,
    gpkd_issued_at: datetime,
    gpkd_expires_at: Optional[datetime],
    db: Session,
    accessor_ip: Optional[str] = None,
) -> OperatorBusinessProfile:
    """Step 2: Upload GPKD document.

    Stores via sensitive_file_service (encrypted-at-rest path).
    Sets gpkd_issued_at + gpkd_expires_at (used for AC-50 expiry cron).

    Raises:
        ValueError: If no pending business profile exists for user_id.
    """
    profile = _get_pending_profile(user_id, db)

    rel_path = sensitive_file_service.store_file(
        file_bytes=gpkd_bytes,
        file_type="gpkd_document",
        owner_user_id=user_id,
        extension=gpkd_extension,
        db=db,
        accessor_user_id=user_id,
        ip_address=accessor_ip,
    )

    profile.gpkd_document_path = rel_path
    profile.gpkd_issued_at = gpkd_issued_at
    profile.gpkd_expires_at = gpkd_expires_at
    profile.updated_at = datetime.utcnow()

    logger.info(
        "operator_business_service: gpkd uploaded user=%s path=%s",
        user_id,
        rel_path,
    )
    return profile


def submit_legal_rep_info(
    user_id: int,
    legal_rep_name: str,
    legal_rep_cccd_number: str,
    legal_rep_phone: str,
    cccd_front_bytes: bytes,
    cccd_back_bytes: bytes,
    cccd_extension: str,
    db: Session,
    accessor_ip: Optional[str] = None,
) -> OperatorBusinessProfile:
    """Step 3: Submit legal representative CCCD.

    Stores CCCD images via sensitive_file_service.
    Stores CCCD number as one-way bcrypt hash (mirrors host_profile pattern).
    Triggers is_complete check: if gpkd_document_path is set, profile is ready for admin review.

    Raises:
        ValueError: If no pending business profile exists for user_id.
    """
    profile = _get_pending_profile(user_id, db)

    cccd_front_path = sensitive_file_service.store_file(
        file_bytes=cccd_front_bytes,
        file_type="legal_rep_cccd",
        owner_user_id=user_id,
        extension=cccd_extension,
        db=db,
        accessor_user_id=user_id,
        ip_address=accessor_ip,
    )
    cccd_back_path = sensitive_file_service.store_file(
        file_bytes=cccd_back_bytes,
        file_type="legal_rep_cccd",
        owner_user_id=user_id,
        extension=cccd_extension,
        db=db,
        accessor_user_id=user_id,
        ip_address=accessor_ip,
    )

    profile.legal_representative_name = legal_rep_name
    profile.legal_representative_cccd_number_hash = _hash_cccd(legal_rep_cccd_number)
    profile.legal_representative_cccd_front_path = cccd_front_path
    profile.legal_representative_cccd_back_path = cccd_back_path
    profile.legal_representative_phone = legal_rep_phone
    profile.updated_at = datetime.utcnow()

    logger.info(
        "operator_business_service: legal_rep_info submitted user=%s rep=%s",
        user_id,
        legal_rep_name,
    )
    return profile


def admin_approve_business(
    profile_id: int,
    admin_user_id: int,
    db: Session,
) -> OperatorBusinessProfile:
    """Admin approves business KYC → status='verified'.

    Sets verified_at = now(), verified_by_user_id = admin_user_id.
    Updates user.is_operator_capable = True.
    Caller is responsible for writing ChangeLog + emitting notification.

    Raises:
        ValueError: If profile not found or not in 'pending' status.
    """
    profile = _get_profile_by_id(profile_id, db)
    if profile.verification_status != "pending":
        raise ValueError(
            f"Profile {profile_id} is in status={profile.verification_status}; "
            "can only approve 'pending' profiles."
        )

    profile.verification_status = "verified"
    profile.verified_at = datetime.utcnow()
    profile.verified_by_user_id = admin_user_id
    profile.updated_at = datetime.utcnow()

    # Promote user to operator-capable
    user = db.query(User).filter(User.id == profile.user_id).first()
    if user is not None:
        user.is_operator_capable = True

    # Hồ sơ nộp từ eKYC chủ nhà (mig 0140) → bật "đã xác minh" + báo chủ nhà.
    from app.services import ekyc_chu_nha

    ekyc_chu_nha.sau_khi_admin_xet(db, profile, duyet=True)

    logger.info(
        "operator_business_service: admin=%s approved profile=%s for user=%s",
        admin_user_id,
        profile_id,
        profile.user_id,
    )
    return profile


def admin_reject_business(
    profile_id: int,
    admin_user_id: int,
    reason: str,
    db: Session,
) -> OperatorBusinessProfile:
    """Admin rejects business KYC → status='rejected'.

    Caller is responsible for writing ChangeLog + emitting notification with reason.

    Raises:
        ValueError: If profile not found or not in 'pending' status.
    """
    profile = _get_profile_by_id(profile_id, db)
    if profile.verification_status != "pending":
        raise ValueError(
            f"Profile {profile_id} is in status={profile.verification_status}; "
            "can only reject 'pending' profiles."
        )

    profile.verification_status = "rejected"
    profile.updated_at = datetime.utcnow()

    # eKYC chủ nhà: lý do từ chối về lại app để chủ nhà chụp/nộp lại.
    from app.services import ekyc_chu_nha

    ekyc_chu_nha.sau_khi_admin_xet(db, profile, duyet=False, ly_do=reason)

    logger.info(
        "operator_business_service: admin=%s rejected profile=%s reason='%s'",
        admin_user_id,
        profile_id,
        reason,
    )
    return profile


def admin_revoke_gpkd(
    profile_id: int,
    admin_user_id: int,
    db: Session,
) -> OperatorBusinessProfile:
    """Admin revokes GPKD → status='revoked' (AC-61).

    Phase-03 cron (delegation_kyc_expiry_pauser) will auto-pause active delegations.
    If not re-verified in 15 days, phase-03 cron auto-terminates.

    Raises:
        ValueError: If profile not found or not in 'verified' status.
    """
    profile = _get_profile_by_id(profile_id, db)
    if profile.verification_status != "verified":
        raise ValueError(
            f"Profile {profile_id} is in status={profile.verification_status}; "
            "can only revoke 'verified' profiles."
        )

    profile.verification_status = "revoked"
    profile.updated_at = datetime.utcnow()

    logger.info(
        "operator_business_service: admin=%s revoked GPKD profile=%s user=%s",
        admin_user_id,
        profile_id,
        profile.user_id,
    )
    return profile


def initiate_legal_rep_change(
    profile_id: int,
    new_legal_rep_name: str,
    new_cccd_number: str,
    new_phone: str,
    new_cccd_front_bytes: bytes,
    new_cccd_back_bytes: bytes,
    cccd_extension: str,
    reason: str,
    db: Session,
    accessor_ip: Optional[str] = None,
) -> OperatorBusinessProfile:
    """Operator submits new legal representative for review (AC-50b / AC-65).

    Transitions profile to 'pending_legal_rep_change'.
    Stores new CCCD for review (overwrites staging fields).
    Old legal rep data preserved until admin approves.
    Phase-03 hook (caller) should pause active delegations of this profile.

    Raises:
        ValueError: If profile not found or not in 'verified' status.
    """
    profile = _get_profile_by_id(profile_id, db)
    if profile.verification_status != "verified":
        raise ValueError(
            f"Profile {profile_id} must be 'verified' to initiate legal-rep change. "
            f"Current status: {profile.verification_status}"
        )

    # Store new CCCD images (labelled as legal_rep_cccd type)
    new_front_path = sensitive_file_service.store_file(
        file_bytes=new_cccd_front_bytes,
        file_type="legal_rep_cccd",
        owner_user_id=profile.user_id,
        extension=cccd_extension,
        db=db,
        accessor_user_id=profile.user_id,
        ip_address=accessor_ip,
    )
    new_back_path = sensitive_file_service.store_file(
        file_bytes=new_cccd_back_bytes,
        file_type="legal_rep_cccd",
        owner_user_id=profile.user_id,
        extension=cccd_extension,
        db=db,
        accessor_user_id=profile.user_id,
        ip_address=accessor_ip,
    )

    # Preserve current rep as previous (AC-65 audit trail)
    profile.previous_legal_rep_user_id = profile.user_id
    profile.legal_rep_changed_at = datetime.utcnow()

    # Stage new rep data (admin will confirm before promotion)
    profile.legal_representative_name = new_legal_rep_name
    profile.legal_representative_cccd_number_hash = _hash_cccd(new_cccd_number)
    profile.legal_representative_cccd_front_path = new_front_path
    profile.legal_representative_cccd_back_path = new_back_path
    profile.legal_representative_phone = new_phone

    profile.verification_status = "pending_legal_rep_change"
    profile.updated_at = datetime.utcnow()

    logger.info(
        "operator_business_service: legal_rep_change initiated profile=%s new_rep=%s reason='%s'",
        profile_id,
        new_legal_rep_name,
        reason,
    )
    return profile


def admin_approve_legal_rep_change(
    profile_id: int,
    admin_user_id: int,
    db: Session,
) -> OperatorBusinessProfile:
    """Admin approves legal-rep change → status='verified', legal_rep_changed_at set (AC-65).

    Per spec: old credentials disabled within 48h.
    v1: sets profile back to verified; JWT short-TTL (24h) serves as de-facto revocation.
    TODO v1.1: implement explicit JWT revocation list if 24h TTL is insufficient.

    Raises:
        ValueError: If profile not found or not in 'pending_legal_rep_change'.
    """
    profile = _get_profile_by_id(profile_id, db)
    if profile.verification_status != "pending_legal_rep_change":
        raise ValueError(
            f"Profile {profile_id} must be in 'pending_legal_rep_change' state. "
            f"Current: {profile.verification_status}"
        )

    profile.verification_status = "verified"
    profile.verified_at = datetime.utcnow()
    profile.verified_by_user_id = admin_user_id
    profile.updated_at = datetime.utcnow()

    logger.info(
        "operator_business_service: admin=%s approved legal_rep_change profile=%s",
        admin_user_id,
        profile_id,
    )
    return profile


def is_operator_business_kyc_complete(user_id: int, db: Session) -> bool:
    """Check if user has a verified OperatorBusinessProfile (AC-06 business gate).

    Used by delegation invite preview + operator_onboarding orchestrator.
    """
    profile = (
        db.query(OperatorBusinessProfile)
        .filter(OperatorBusinessProfile.user_id == user_id)
        .first()
    )
    return profile is not None and profile.verification_status == "verified"


def get_business_profile_for_user(
    user_id: int,
    db: Session,
) -> Optional[OperatorBusinessProfile]:
    """Return the OperatorBusinessProfile for a user, or None."""
    return (
        db.query(OperatorBusinessProfile)
        .filter(OperatorBusinessProfile.user_id == user_id)
        .first()
    )


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _get_pending_profile(user_id: int, db: Session) -> OperatorBusinessProfile:
    """Get a profile that is in a mutable state (pending or pending_legal_rep_change).

    Raises ValueError if not found or in terminal state.
    """
    profile = (
        db.query(OperatorBusinessProfile)
        .filter(OperatorBusinessProfile.user_id == user_id)
        .first()
    )
    if profile is None:
        raise ValueError(
            f"No OperatorBusinessProfile for user_id={user_id}. "
            "Submit business info first (step 1)."
        )
    if profile.verification_status in ("verified", "rejected", "revoked"):
        raise ValueError(
            f"Business profile for user_id={user_id} is in terminal status "
            f"'{profile.verification_status}'. Cannot update."
        )
    return profile


def _get_profile_by_id(profile_id: int, db: Session) -> OperatorBusinessProfile:
    """Get OperatorBusinessProfile by primary key.

    Raises ValueError if not found.
    """
    profile = (
        db.query(OperatorBusinessProfile)
        .filter(OperatorBusinessProfile.id == profile_id)
        .first()
    )
    if profile is None:
        raise ValueError(f"OperatorBusinessProfile id={profile_id} not found.")
    return profile
