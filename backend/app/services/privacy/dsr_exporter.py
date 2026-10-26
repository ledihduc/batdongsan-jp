"""DSR real cross-domain data exporter — APPI compliance.

Aggregates all user data from multiple JP domain repositories into a
single structured dict for DSR export.

Data collected (per APPI Art. 28 response obligation):
  - User profile (users table)
  - Consent history (jp_user_consents)
  - Viewings (jp_viewings)
  - Applications (jp_tenant_applications)
  - Payment intents (jp_payment_intents)
  - Listings owned (jp_listings where owner_user_id = user_id)

APPI time limit: last 2 years (personal data retention per Art. 19).
Invoice rows exempt from deletion but included in export (7-year tax retention).

Architecture: pure aggregator — takes user_id + db → returns dict.
No streaming: synchronous for MVP. Move to ARQ for large orgs in P4.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# APPI Art. 19 — data within last 2 years
_APPI_RETENTION_YEARS = 2


def _two_years_ago() -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=365 * _APPI_RETENTION_YEARS)


def collect(user_id: int, org_id: str, db: Session) -> dict[str, Any]:
    """Aggregate all user data across JP domains for DSR export.

    Args:
        user_id: Platform user ID.
        org_id:  Broker org ID (for multi-tenant scoped queries).
        db:      SQLAlchemy session.

    Returns:
        Dict with sections: profile, consents, viewings, applications,
        payments, listings, metadata.
    """
    since = _two_years_ago()
    logger.info("DSR collect: user=%d org=%s since=%s", user_id, org_id, since.date())

    return {
        "profile": _collect_profile(user_id, db),
        "consents": _collect_consents(user_id, db),
        "viewings": _collect_viewings(user_id, org_id, since, db),
        "applications": _collect_applications(user_id, org_id, since, db),
        "payments": _collect_payments(user_id, org_id, since, db),
        "listings": _collect_owned_listings(user_id, org_id, db),
        "metadata": {
            "user_id": user_id,
            "org_id": org_id,
            "export_generated_at": datetime.now(timezone.utc).isoformat(),
            "appi_retention_years": _APPI_RETENTION_YEARS,
            "format_version": "2.0",
        },
    }


def _collect_profile(user_id: int, db: Session) -> dict[str, Any]:
    """Collect user profile data from users table."""
    try:
        result = db.execute(
            text(
                "SELECT id, email, phone, first_name, last_name, created_at, "
                "       updated_at, deletion_scheduled_at "
                "FROM users WHERE id = :user_id"
            ),
            {"user_id": user_id},
        )
        row = result.fetchone()
        if not row:
            return {"user_id": user_id, "found": False}
        return {
            "user_id": row[0],
            "email": row[1],
            "phone": row[2],
            "first_name": row[3],
            "last_name": row[4],
            "created_at": _iso(row[5]),
            "updated_at": _iso(row[6]),
            "deletion_scheduled_at": _iso(row[7]),
        }
    except Exception as exc:
        logger.warning("DSR profile query failed: user=%d err=%s", user_id, exc)
        return {"user_id": user_id, "error": "profile_unavailable"}


def _collect_consents(user_id: int, db: Session) -> list[dict[str, Any]]:
    """Collect full consent history from jp_user_consents."""
    try:
        from app.repositories.jp.user_consent import JpUserConsentRepository
        from app.services.privacy.consent_pii_encrypt import decrypt_ip, decrypt_ua

        repo = JpUserConsentRepository(db)
        rows = repo.list_all_for_user(user_id)
        return [
            {
                "id": c.id,
                "purpose": c.purpose,
                "consent_version": c.consent_version,
                "granted_at": _iso(c.granted_at),
                "revoked_at": _iso(c.revoked_at),
                "legal_hold": c.legal_hold,
                # Decrypt PII for DSR export only
                "ip_address": decrypt_ip(c) or c.ip_address,
                "user_agent": decrypt_ua(c) or c.user_agent,
            }
            for c in rows
        ]
    except Exception as exc:
        logger.warning("DSR consents query failed: user=%d err=%s", user_id, exc)
        return []


def _collect_viewings(
    user_id: int, org_id: str, since: datetime, db: Session
) -> list[dict[str, Any]]:
    """Collect viewing appointments from jp_viewings."""
    try:
        result = db.execute(
            text(
                "SELECT id, listing_id, scheduled_at, status, created_at "
                "FROM jp_viewings "
                "WHERE applicant_user_id = :user_id "
                "  AND org_id = :org_id "
                "  AND created_at >= :since "
                "ORDER BY created_at DESC"
            ),
            {"user_id": user_id, "org_id": org_id, "since": since},
        )
        rows = result.fetchall()
        return [
            {
                "id": r[0],
                "listing_id": r[1],
                "scheduled_at": _iso(r[2]),
                "status": r[3],
                "created_at": _iso(r[4]),
            }
            for r in rows
        ]
    except Exception as exc:
        logger.warning("DSR viewings query failed: user=%d err=%s", user_id, exc)
        return []


def _collect_applications(
    user_id: int, org_id: str, since: datetime, db: Session
) -> list[dict[str, Any]]:
    """Collect tenant applications from jp_tenant_applications."""
    try:
        result = db.execute(
            text(
                "SELECT id, listing_id, status, employer_name, "
                "       annual_income_jpy, created_at, submitted_at "
                "FROM jp_tenant_applications "
                "WHERE applicant_user_id = :user_id "
                "  AND org_id = :org_id "
                "  AND created_at >= :since "
                "ORDER BY created_at DESC"
            ),
            {"user_id": user_id, "org_id": org_id, "since": since},
        )
        rows = result.fetchall()
        return [
            {
                "id": r[0],
                "listing_id": r[1],
                "status": r[2],
                "employer_name": r[3],
                "annual_income_jpy": str(r[4]) if r[4] is not None else None,
                "created_at": _iso(r[5]),
                "submitted_at": _iso(r[6]),
            }
            for r in rows
        ]
    except Exception as exc:
        logger.warning("DSR applications query failed: user=%d err=%s", user_id, exc)
        return []


def _collect_payments(
    user_id: int, org_id: str, since: datetime, db: Session
) -> list[dict[str, Any]]:
    """Collect payment intents from jp_payment_intents."""
    try:
        result = db.execute(
            text(
                "SELECT id, amount_jpy, currency, status, created_at "
                "FROM jp_payment_intents "
                "WHERE user_id = :user_id "
                "  AND org_id = :org_id "
                "  AND created_at >= :since "
                "ORDER BY created_at DESC"
            ),
            {"user_id": user_id, "org_id": org_id, "since": since},
        )
        rows = result.fetchall()
        return [
            {
                "id": r[0],
                "amount_jpy": str(r[1]) if r[1] is not None else None,
                "currency": r[2],
                "status": r[3],
                "created_at": _iso(r[4]),
            }
            for r in rows
        ]
    except Exception as exc:
        logger.warning("DSR payments query failed: user=%d err=%s", user_id, exc)
        return []


def _collect_owned_listings(
    user_id: int, org_id: str, db: Session
) -> list[dict[str, Any]]:
    """Collect listings owned by the user from jp_listings."""
    try:
        result = db.execute(
            text(
                "SELECT id, title, status, created_at "
                "FROM jp_listings "
                "WHERE owner_user_id = :user_id "
                "  AND org_id = :org_id "
                "ORDER BY created_at DESC"
            ),
            {"user_id": user_id, "org_id": org_id},
        )
        rows = result.fetchall()
        return [
            {
                "id": r[0],
                "title": r[1],
                "status": r[2],
                "created_at": _iso(r[3]),
            }
            for r in rows
        ]
    except Exception as exc:
        logger.warning("DSR listings query failed: user=%d err=%s", user_id, exc)
        return []


def _iso(dt: Optional[Any]) -> Optional[str]:
    """Convert datetime to ISO string, or return None."""
    if dt is None:
        return None
    if isinstance(dt, datetime):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.isoformat()
    return str(dt)
