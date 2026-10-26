"""Operator individual KYC service.

US-P3 / AC-06: Individual operator reuses host KYC (HostProfile).
Phase 05 additions:
  - is_operator_individual_kyc_complete(): shared gate check used by delegation flow.
  - mark_individual_kyc_complete(): sets kyc_expires_at = verified_at + 5y on approval.
  - submit_individual_kyc(): file upload + hash — delegates to sensitive_file_service.

Individual operator KYC is considered complete when:
  host_profiles.verified = True
  AND host_profiles.cccd_number_hash IS NOT NULL
  AND host_profiles.bank_account_number IS NOT NULL (AC-06)

AC-50: kyc_expires_at written at verification time; cron jobs (phase-03/08) use it
for pro-active warnings + grace period activation.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models import HostProfile, User

logger = logging.getLogger(__name__)

# CCCD individual expiry: 5 years from verification (AC-50, phase-05 spec §Architecture)
_INDIVIDUAL_KYC_EXPIRY_YEARS = 5


def is_operator_individual_kyc_complete(user_id: int, db: Session) -> bool:
    """Check if user has completed individual operator KYC (AC-06 gate).

    Returns True when:
      - host_profiles row exists for user_id
      - verified = True
      - cccd_number_hash is not null (CCCD was submitted)
      - bank_account_number is not null (bank account linked)

    Used by delegation invite preview and by operator_onboarding orchestrator.
    """
    profile = db.query(HostProfile).filter(HostProfile.user_id == user_id).first()
    if profile is None:
        return False

    return bool(
        profile.verified
        and profile.cccd_number_hash
        and profile.bank_account_number
    )


def mark_individual_kyc_complete(user_id: int, db: Session) -> HostProfile:
    """Set is_operator_capable=True and kyc_expires_at on the user/host_profile.

    Called by admin approval endpoint after reviewing CCCD docs.
    Writes kyc_expires_at = verified_at + 5 years (AC-50 canonical).
    Commits are the caller's responsibility.

    Raises:
        ValueError: If host_profiles row does not exist for user_id.
        ValueError: If profile is not yet verified.
    """
    profile = db.query(HostProfile).filter(HostProfile.user_id == user_id).first()
    if profile is None:
        raise ValueError(
            f"No host_profiles row for user_id={user_id}. "
            "User must complete host onboarding before operator KYC can be approved."
        )

    if not profile.verified:
        raise ValueError(
            f"host_profiles.verified is False for user_id={user_id}. "
            "Admin must mark verified first."
        )

    verified_at = profile.updated_at or datetime.utcnow()
    expires_at = verified_at + timedelta(days=365 * _INDIVIDUAL_KYC_EXPIRY_YEARS)

    profile.kyc_expires_at = expires_at

    # Promote user to is_operator_capable = True
    user = db.query(User).filter(User.id == user_id).first()
    if user is not None:
        user.is_operator_capable = True

    logger.info(
        "operator_individual_kyc: user=%s marked operator-capable; kyc_expires_at=%s",
        user_id,
        expires_at.isoformat(),
    )
    return profile


def get_kyc_status_for_user(user_id: int, db: Session) -> dict:
    """Return KYC status dict for API response.

    Used by GET /api/kyc/operator/individual/status.
    Never returns raw file paths (security: paths are internal).
    """
    profile = db.query(HostProfile).filter(HostProfile.user_id == user_id).first()
    if profile is None:
        return {
            "kyc_complete": False,
            "verified": False,
            "has_cccd": False,
            "has_bank": False,
            "kyc_expires_at": None,
            "kyc_grace_period_until": None,
        }

    return {
        "kyc_complete": is_operator_individual_kyc_complete(user_id, db),
        "verified": bool(profile.verified),
        "has_cccd": bool(profile.cccd_number_hash),
        "has_bank": bool(profile.bank_account_number),
        "kyc_expires_at": profile.kyc_expires_at.isoformat() if profile.kyc_expires_at else None,
        "kyc_grace_period_until": (
            profile.kyc_grace_period_until.isoformat()
            if profile.kyc_grace_period_until
            else None
        ),
    }
