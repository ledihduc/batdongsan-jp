"""Multi-org webhook HMAC resolver.

Maps an inbound provider event to the correct org and verifies the HMAC
using that org's configured secret. Unknown org → deny (401).

Security invariant (zero-trust):
  1. Parse provider identifier from payload/header (pre-HMAC — fields are not trusted yet).
  2. Look up OrgProviderConfig matching (provider_name, provider_account_id).
  3. Only after finding org config: verify HMAC with org's secret.
  4. If HMAC fails: deny even if org was found (tampering).
  5. If no org found: deny with 401 (not 404 — don't leak org existence).

Supported providers:
  - komoju: provider_account_id from payload['data']['object']['metadata']['komoju_account_id']
             or payload['account_id']
  - cloudsign: account identifier from X-CloudSign-Account header.

HMAC algorithm: HMAC-SHA256 (both providers).
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
from dataclasses import dataclass
from typing import Optional

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class HmacResolveResult:
    """Result of resolve() — carries org_id and verification status."""

    org_id: str
    verified: bool
    provider: str


def resolve(
    *,
    provider: str,
    headers: dict[str, str],
    body: bytes,
    db: Session,
    signature: str,
) -> HmacResolveResult:
    """Resolve provider event to org and verify HMAC.

    Args:
        provider:  Provider name ('komoju' or 'cloudsign').
        headers:   Request headers dict (lower-cased keys).
        body:      Raw request body bytes.
        db:        SQLAlchemy session.
        signature: Extracted HMAC signature from headers.

    Returns:
        HmacResolveResult with org_id and verified status.

    Raises:
        ValueError: if org not found (caller should return 401).
        ValueError: if HMAC verification fails.
    """
    if provider == "komoju":
        return _resolve_komoju(headers=headers, body=body, db=db, signature=signature)
    elif provider == "cloudsign":
        return _resolve_cloudsign(headers=headers, body=body, db=db, signature=signature)
    else:
        raise ValueError(f"Unsupported provider: {provider!r}")


def _extract_komoju_account_id(body: bytes) -> Optional[str]:
    """Extract Komoju account identifier from payload.

    Checks: payload['account_id'] or payload['data']['object']['metadata']['org_id'].
    """
    try:
        payload = json.loads(body)
        # Direct account_id field (Komoju Connect webhooks)
        account_id = payload.get("account_id")
        if account_id:
            return str(account_id)
        # Metadata org_id embedded by us during session creation
        meta_org = (
            payload.get("data", {})
            .get("object", {})
            .get("metadata", {})
            .get("org_id")
        )
        return str(meta_org) if meta_org else None
    except Exception:
        return None


def _extract_cloudsign_account_id(headers: dict[str, str]) -> Optional[str]:
    """Extract CloudSign account identifier from X-CloudSign-Account header."""
    return headers.get("x-cloudsign-account") or headers.get("X-CloudSign-Account") or None


def _lookup_org_secret(
    *,
    provider_name: str,
    provider_account_id: str,
    db: Session,
) -> tuple[str, str]:
    """Look up (org_id, webhook_secret) for a provider account.

    Returns:
        Tuple of (org_id, webhook_secret_plaintext).

    Raises:
        ValueError: if no config found for this provider account.
    """
    from app.domain.jp.provider_config import OrgProviderConfig
    from app.services.crypto import decrypt_config

    # Find OrgProviderConfig where provider_account_id matches
    config_row = (
        db.query(OrgProviderConfig)
        .filter(
            OrgProviderConfig.provider_name == provider_name,
            OrgProviderConfig.provider_type == "payment"
            if provider_name == "komoju"
            else OrgProviderConfig.provider_type == "esign",
        )
        .all()
    )

    for row in config_row:
        try:
            decrypted = decrypt_config(row.config_encrypted)
            # Config must have provider_account_id and webhook_secret
            if str(decrypted.get("provider_account_id", "")) == provider_account_id:
                secret = decrypted.get("webhook_secret", "")
                if secret:
                    return row.org_id, secret
        except Exception as exc:
            logger.warning(
                "Failed to decrypt config for org=%s provider=%s: %s",
                row.org_id, provider_name, exc,
            )
            continue

    raise ValueError(
        f"No org config found for provider={provider_name!r} account={provider_account_id!r}"
    )


def _verify_hmac_sha256(*, body: bytes, secret: str, signature: str) -> bool:
    """Verify HMAC-SHA256 signature against body using secret.

    Uses constant-time comparison to prevent timing attacks.
    Supports both raw hex and 'sha256=<hex>' prefixed formats.
    """
    sig_clean = signature.removeprefix("sha256=").strip()
    computed = hmac.new(
        secret.encode("utf-8"),
        body,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(computed, sig_clean)


def _resolve_komoju(
    *,
    headers: dict[str, str],
    body: bytes,
    db: Session,
    signature: str,
) -> HmacResolveResult:
    """Resolve a Komoju webhook to org and verify HMAC."""
    account_id = _extract_komoju_account_id(body)
    if not account_id:
        raise ValueError("Cannot extract Komoju account_id from payload")

    try:
        org_id, secret = _lookup_org_secret(
            provider_name="komoju",
            provider_account_id=account_id,
            db=db,
        )
    except ValueError:
        logger.warning("Komoju webhook: no org for account_id=%r", account_id)
        raise

    verified = _verify_hmac_sha256(body=body, secret=secret, signature=signature)
    if not verified:
        logger.warning(
            "Komoju HMAC verification failed: org=%s account=%s",
            org_id, account_id,
        )
        raise ValueError(f"HMAC verification failed for org={org_id!r}")

    return HmacResolveResult(org_id=org_id, verified=True, provider="komoju")


def _resolve_cloudsign(
    *,
    headers: dict[str, str],
    body: bytes,
    db: Session,
    signature: str,
) -> HmacResolveResult:
    """Resolve a CloudSign webhook to org and verify HMAC."""
    account_id = _extract_cloudsign_account_id(headers)
    if not account_id:
        raise ValueError("Cannot extract CloudSign account ID from X-CloudSign-Account header")

    try:
        org_id, secret = _lookup_org_secret(
            provider_name="cloudsign",
            provider_account_id=account_id,
            db=db,
        )
    except ValueError:
        logger.warning("CloudSign webhook: no org for account_id=%r", account_id)
        raise

    verified = _verify_hmac_sha256(body=body, secret=secret, signature=signature)
    if not verified:
        logger.warning(
            "CloudSign HMAC verification failed: org=%s account=%s",
            org_id, account_id,
        )
        raise ValueError(f"HMAC verification failed for org={org_id!r}")

    return HmacResolveResult(org_id=org_id, verified=True, provider="cloudsign")
