"""Operator onboarding orchestrator.

Phase 05: US-P3 (individual) + US-P4 (business) onboarding flows.
Orchestrates KYC completion checks and handoff to invitation flow (phase-03).

Individual path:
  - Reuses existing host onboarding (step1_info, step2_cccd, step3_bank).
  - This module adds: is_individual_onboarding_complete() gate check.
  - Phase-03 invitation creation checks this gate before issuing invite.

Business path:
  - 4-step greenfield wizard: business_info → gpkd_upload → legal_rep_info → review.
  - Each step calls operator_business_service.
  - After admin approval, delegation invitations can be accepted.

Operator type detection:
  - Individual: user.is_operator_capable == True (set by admin after host KYC).
  - Business: user has OperatorBusinessProfile with status == 'verified'.
  - A user can be both (host who also runs a business entity) — dual capabilities.
"""

from __future__ import annotations

import logging
from typing import Literal, Optional

from sqlalchemy.orm import Session

from app.services.kyc.operator_individual_service import is_operator_individual_kyc_complete
from app.services.kyc.operator_business_service import (
    is_operator_business_kyc_complete,
    get_business_profile_for_user,
)
from app.models import User

logger = logging.getLogger(__name__)

OperatorType = Literal["individual", "business", "both", "none"]


def get_operator_type(user_id: int, db: Session) -> OperatorType:
    """Determine operator capability type for a user.

    Returns:
        'individual' — only individual KYC complete.
        'business'   — only business KYC complete.
        'both'       — both paths complete (host who runs a PMC).
        'none'       — no operator capability.

    Used by invitation accept flow to determine which KYC path to check.
    """
    individual_ok = is_operator_individual_kyc_complete(user_id, db)
    business_ok = is_operator_business_kyc_complete(user_id, db)

    if individual_ok and business_ok:
        return "both"
    if individual_ok:
        return "individual"
    if business_ok:
        return "business"
    return "none"


def is_operator_kyc_complete(user_id: int, db: Session) -> bool:
    """Return True if user has any valid operator KYC path complete.

    AC-06 gate: True when either individual OR business KYC is verified.
    Used by delegation invite acceptance validation.
    """
    return (
        is_operator_individual_kyc_complete(user_id, db)
        or is_operator_business_kyc_complete(user_id, db)
    )


def get_onboarding_status(user_id: int, db: Session) -> dict:
    """Return full onboarding status for Flutter UI rendering.

    Drives onboarding progress indicator + next-step routing.
    Never returns sensitive file paths.
    """
    from app.models import HostProfile
    from app.domain.operator_business import OperatorBusinessProfile

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        return {"error": "user_not_found"}

    host_profile = db.query(HostProfile).filter(HostProfile.user_id == user_id).first()
    business_profile: Optional[OperatorBusinessProfile] = get_business_profile_for_user(
        user_id, db
    )

    individual_kyc_complete = is_operator_individual_kyc_complete(user_id, db)
    business_kyc_complete = is_operator_business_kyc_complete(user_id, db)

    return {
        "user_id": user_id,
        "is_operator_capable": bool(user.is_operator_capable),
        "operator_type": get_operator_type(user_id, db),
        "individual": {
            "kyc_complete": individual_kyc_complete,
            "has_host_profile": host_profile is not None,
            "host_profile_verified": bool(host_profile.verified) if host_profile else False,
            "has_cccd": bool(host_profile and host_profile.cccd_number_hash),
            "has_bank": bool(host_profile and host_profile.bank_account_number),
            "kyc_expires_at": (
                host_profile.kyc_expires_at.isoformat()
                if host_profile and host_profile.kyc_expires_at
                else None
            ),
        },
        "business": {
            "kyc_complete": business_kyc_complete,
            "profile_exists": business_profile is not None,
            "verification_status": (
                business_profile.verification_status if business_profile else None
            ),
            "business_name": business_profile.business_name if business_profile else None,
            "gpkd_expires_at": (
                business_profile.gpkd_expires_at.isoformat()
                if business_profile and business_profile.gpkd_expires_at
                else None
            ),
            "steps_complete": _business_steps_complete(business_profile),
        },
        "sole_ownership_attested": user.sole_ownership_attested_at is not None,
    }


def _business_steps_complete(profile: Optional[object]) -> dict:
    """Return per-step completion flags for Flutter progress indicator."""
    if profile is None:
        return {"step1_info": False, "step2_gpkd": False, "step3_legal_rep": False}

    return {
        "step1_info": bool(
            getattr(profile, "business_name", None)
            and getattr(profile, "business_registration_number", None)
        ),
        "step2_gpkd": bool(getattr(profile, "gpkd_document_path", None)),
        "step3_legal_rep": bool(getattr(profile, "legal_representative_cccd_number_hash", None)),
    }
