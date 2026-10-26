"""Consent PII encryption — encrypt ip_address and user_agent at rest.

Uses Fernet from app.services.crypto (same key as OrgProviderConfig encryption).

Write path (record_consent → ConsentRepo.grant):
  encrypt_on_write(ip_address, user_agent) → sets ip_address_encrypted / user_agent_encrypted.
  Plaintext ip_address / user_agent columns kept for 1 release (drop in P4).

Read path (DSR export only):
  decrypt_ip(consent_row) → plaintext IP or None.
  decrypt_ua(consent_row) → plaintext UA or None.

All operations handle None inputs gracefully (APPI: IP/UA are optional).
"""

from __future__ import annotations

import logging
from typing import Optional

from app.domain.jp.user_consent import JpUserConsent

logger = logging.getLogger(__name__)


def _get_fernet():
    """Return the module-level Fernet singleton."""
    from app.services.crypto import _get_fernet as _crypto_get_fernet
    return _crypto_get_fernet()


def encrypt_ip(ip_address: Optional[str]) -> Optional[bytes]:
    """Encrypt an IP address string to Fernet bytes. Returns None if input is None."""
    if not ip_address:
        return None
    try:
        return _get_fernet().encrypt(ip_address.encode("utf-8"))
    except Exception as exc:
        logger.error("Failed to encrypt IP address: %s", exc)
        return None


def encrypt_ua(user_agent: Optional[str]) -> Optional[bytes]:
    """Encrypt a User-Agent string to Fernet bytes. Returns None if input is None."""
    if not user_agent:
        return None
    try:
        return _get_fernet().encrypt(user_agent.encode("utf-8"))
    except Exception as exc:
        logger.error("Failed to encrypt User-Agent: %s", exc)
        return None


def decrypt_ip(consent: JpUserConsent) -> Optional[str]:
    """Decrypt ip_address_encrypted from a consent row. DSR export use only.

    Falls back to plaintext ip_address if encrypted field is absent.
    Returns None if both are absent or decryption fails.
    """
    if consent.ip_address_encrypted:
        try:
            return _get_fernet().decrypt(consent.ip_address_encrypted).decode("utf-8")
        except Exception as exc:
            logger.warning("IP decrypt failed consent.id=%s: %s", consent.id, exc)
    # Plaintext fallback (to be removed in P4 after migration settles)
    return getattr(consent, "ip_address", None)


def decrypt_ua(consent: JpUserConsent) -> Optional[str]:
    """Decrypt user_agent_encrypted from a consent row. DSR export use only.

    Falls back to plaintext user_agent if encrypted field is absent.
    Returns None if both are absent or decryption fails.
    """
    if consent.user_agent_encrypted:
        try:
            return _get_fernet().decrypt(consent.user_agent_encrypted).decode("utf-8")
        except Exception as exc:
            logger.warning("UA decrypt failed consent.id=%s: %s", consent.id, exc)
    return getattr(consent, "user_agent", None)


def encrypt_on_write(
    consent: JpUserConsent,
    ip_address: Optional[str],
    user_agent: Optional[str],
) -> None:
    """Set encrypted PII fields on a JpUserConsent row before flush.

    Call this after constructing the row, before db.flush().
    Keeps plaintext columns populated for P4 migration safety.

    Args:
        consent:    The JpUserConsent ORM object (mutated in-place).
        ip_address: Plaintext IP to encrypt.
        user_agent: Plaintext UA to encrypt.
    """
    if ip_address:
        consent.ip_address_encrypted = encrypt_ip(ip_address)
    if user_agent:
        consent.user_agent_encrypted = encrypt_ua(user_agent)
