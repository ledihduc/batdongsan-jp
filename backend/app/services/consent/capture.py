"""APPI consent capture service.

Responsibilities:
  - record_consent(): validate purposes, create grant rows, return active state.
  - revoke_consent(): revoke one purpose for a user.
  - get_consent_status(): return current active consents for a user.

All mutations are append-only — see JpUserConsentRepository design.

Usage:
    from app.services.consent.capture import record_consent, revoke_consent
    grants = await record_consent(
        user_id=42,
        purposes=["service_use", "marketing"],
        ip_address="1.2.3.4",
        user_agent="Mozilla/5.0...",
        db=db,
    )
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import Request
from sqlalchemy.orm import Session

from app.domain.jp.user_consent import PURPOSE_VALUES, JpUserConsent
from app.repositories.jp.user_consent import JpUserConsentRepository
from app.services.privacy.consent_pii_encrypt import encrypt_on_write

logger = logging.getLogger(__name__)


def _extract_request_meta(request: Optional[Request]) -> tuple[Optional[str], Optional[str]]:
    """Extract IP address and user-agent from FastAPI Request."""
    if request is None:
        return None, None
    ip = (
        request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
        or str(request.client.host)
        if request.client else None
    )
    ua = request.headers.get("User-Agent")
    return ip or None, ua or None


def record_consent(
    user_id: int,
    purposes: list[str],
    db: Session,
    request: Optional[Request] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
    consent_version: str = "1.0",
) -> list[JpUserConsent]:
    """Grant consent for one or more purposes.

    Validates purpose values. Revokes any existing active consent before
    inserting a new grant (re-grant pattern keeps audit trail clean).

    Args:
        user_id: Platform user ID.
        purposes: List of purpose strings from PURPOSE_VALUES.
        db: SQLAlchemy session.
        request: FastAPI Request for IP/UA extraction (optional).
        ip_address: Override IP if not using request.
        user_agent: Override UA if not using request.
        consent_version: Version of consent text shown.

    Returns:
        List of newly created JpUserConsent rows.

    Raises:
        ValueError: if any purpose is invalid.
    """
    invalid = [p for p in purposes if p not in PURPOSE_VALUES]
    if invalid:
        raise ValueError(
            f"Invalid consent purposes: {invalid}. "
            f"Valid: {list(PURPOSE_VALUES)}"
        )

    if request is not None:
        req_ip, req_ua = _extract_request_meta(request)
        ip_address = ip_address or req_ip
        user_agent = user_agent or req_ua

    repo = JpUserConsentRepository(db)
    granted: list[JpUserConsent] = []

    for purpose in purposes:
        # Revoke existing active consent before re-granting (clean audit trail)
        existing = repo.get_active(user_id, purpose)
        if existing:
            existing.revoked_at = __import__("datetime").datetime.utcnow()

        row = repo.grant(
            user_id=user_id,
            purpose=purpose,
            ip_address=ip_address,
            user_agent=user_agent,
            consent_version=consent_version,
        )
        # Encrypt PII at rest (P3: adds encrypted columns, keeps plaintext for 1 release)
        try:
            encrypt_on_write(row, ip_address, user_agent)
        except Exception as _enc_exc:
            logger.warning("Consent PII encryption failed (non-critical): %s", _enc_exc)
        granted.append(row)
        logger.info(
            "Consent granted: user=%d purpose=%s version=%s",
            user_id, purpose, consent_version,
        )

    return granted


def revoke_consent(
    user_id: int,
    purpose: str,
    db: Session,
) -> Optional[JpUserConsent]:
    """Revoke active consent for one purpose.

    Args:
        user_id: Platform user ID.
        purpose: Purpose to revoke.
        db: SQLAlchemy session.

    Returns:
        Updated JpUserConsent row, or None if no active consent found.

    Raises:
        ValueError: if purpose is invalid.
    """
    if purpose not in PURPOSE_VALUES:
        raise ValueError(
            f"Invalid consent purpose: '{purpose}'. "
            f"Valid: {list(PURPOSE_VALUES)}"
        )

    repo = JpUserConsentRepository(db)
    row = repo.revoke(user_id, purpose)
    if row:
        logger.info("Consent revoked: user=%d purpose=%s", user_id, purpose)
    else:
        logger.info("Consent revoke no-op: user=%d purpose=%s (no active consent)", user_id, purpose)
    return row


def get_consent_status(
    user_id: int,
    db: Session,
) -> dict[str, bool]:
    """Return {purpose: is_active} for all known purposes.

    Purposes not yet granted default to False.
    """
    repo = JpUserConsentRepository(db)
    active_rows = repo.list_active_for_user(user_id)
    active_set = {row.purpose for row in active_rows}
    return {purpose: purpose in active_set for purpose in PURPOSE_VALUES}
