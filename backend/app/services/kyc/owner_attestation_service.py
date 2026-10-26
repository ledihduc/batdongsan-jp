"""Owner attestation service.

AC-64 — sole-ownership attestation (one-way, account-level).
AC-65 — PMC legal-rep change workflow (covered in operator_business_service).
AC-66 — shared-login disclosure acknowledgment on delegation.

Security:
  - AC-64 attestation is one-way: set to True cannot be reverted by user in v1.
    Re-attestation requires admin assistance (BA §6.11, AS-15).
  - AC-64 records ip_address + user_agent for evidence (AS-15 indemnity clause).
  - AC-66 ack is idempotent: already-acked delegations are not re-blocked.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.models import User

logger = logging.getLogger(__name__)


def attest_sole_ownership(
    user_id: int,
    db: Session,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> User:
    """Record AC-64 sole-ownership attestation on user record.

    Idempotent: if already attested, returns user without updating timestamp
    (prevents accidental timestamp reset from duplicate taps).
    One-way: cannot be reverted by user (admin-assist only per AS-15).

    Args:
        user_id:    ID of the owner attesting.
        db:         SQLAlchemy session (caller commits).
        ip_address: Request IP for evidence trail (AS-15).
        user_agent: Client user-agent string for evidence trail.

    Returns:
        Updated User model.

    Raises:
        ValueError: If user_id does not exist.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise ValueError(f"User id={user_id} not found.")

    if user.sole_ownership_attested_at is not None:
        # Already attested — idempotent (AC-64)
        logger.info(
            "owner_attestation: user=%s already attested at=%s (idempotent)",
            user_id,
            user.sole_ownership_attested_at.isoformat(),
        )
        return user

    user.sole_ownership_attested_at = datetime.utcnow()

    logger.info(
        "owner_attestation: AC-64 sole-ownership attested user=%s ip=%s ua=%s",
        user_id,
        ip_address,
        (user_agent or "")[:80],  # truncate for log safety
    )
    return user


def get_sole_ownership_status(user_id: int, db: Session) -> dict:
    """Return AC-64 attestation status for API response.

    Returns:
        {attested_at: ISO datetime | null}
    """
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        return {"attested_at": None}

    return {
        "attested_at": (
            user.sole_ownership_attested_at.isoformat()
            if user.sole_ownership_attested_at
            else None
        )
    }


def check_sole_ownership_attested(user_id: int, db: Session) -> bool:
    """Return True if owner has completed AC-64 attestation.

    Used by delegation invite creation (phase-03) to gate 412 response.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        return False
    return user.sole_ownership_attested_at is not None


def ack_shared_login_disclosure(
    delegation_id: str,
    operator_user_id: int,
    db: Session,
) -> object:
    """Record AC-66 shared-login disclosure acknowledgment on delegation.

    Idempotent: if already acked, returns delegation unchanged.
    After ack, the delegation activation gate check (phase-03 state machine)
    will evaluate remaining conditions (KYC verified) before flipping to 'active'.

    Args:
        delegation_id:    UUID string of the Delegation.
        operator_user_id: Must match delegation.operator_id (caller validates).
        db:               SQLAlchemy session (caller commits).

    Returns:
        Updated Delegation model.

    Raises:
        ValueError: If delegation not found or operator_id mismatch.
    """
    from app.domain.delegation import Delegation

    delegation = db.query(Delegation).filter(Delegation.id == delegation_id).first()
    if delegation is None:
        raise ValueError(f"Delegation id={delegation_id} not found.")

    if int(delegation.operator_id) != operator_user_id:
        raise ValueError(
            f"User {operator_user_id} is not the operator of delegation {delegation_id}."
        )

    # Idempotent: already acked
    if getattr(delegation, "shared_login_disclosure_ack_at", None) is not None:
        logger.info(
            "owner_attestation: AC-66 ack already present delegation=%s (idempotent)",
            delegation_id,
        )
        return delegation

    # Write ack timestamp
    delegation.shared_login_disclosure_ack_at = datetime.utcnow()  # type: ignore[assignment]
    delegation.updated_at = datetime.utcnow()

    logger.info(
        "owner_attestation: AC-66 shared_login_disclosure acked delegation=%s operator=%s",
        delegation_id,
        operator_user_id,
    )
    return delegation
