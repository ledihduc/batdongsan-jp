"""Compliance evidence service — assembles APPI audit data for GET /jp/compliance/evidence.

Reads from existing tables only. No new migrations needed.

Data sources:
  - jp_user_consents          → appi_consented_users_count
  - jp_deletion_cron_log      → last_deletion_cron_run, last_deletion_purged_count
                                (falls back to cron metadata table if present, else None)
  - pii_key_rotation_log      → pii_key_rotation_date (optional table)
  - jp_webhook_events         → hmac_rotation_ledger (via org_webhook_configs if present)

All queries use raw SQL text() with bound params — no string interpolation.
All functions handle missing tables gracefully (table may not exist in all envs).
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.schemas.jp.compliance import ComplianceEvidenceResponse, HmacRotationEntry

logger = logging.getLogger(__name__)


def _count_appi_consented_users(db: Session) -> int:
    """Count distinct users with at least one active service_use APPI consent.

    Active = granted_at IS NOT NULL AND revoked_at IS NULL.
    Uses jp_user_consents table (migration 0153).
    Returns 0 on any error.
    """
    try:
        result = db.execute(
            text(
                "SELECT COUNT(DISTINCT user_id) FROM jp_user_consents "
                "WHERE purpose = 'service_use' "
                "  AND granted_at IS NOT NULL "
                "  AND revoked_at IS NULL"
            )
        )
        row = result.fetchone()
        return int(row[0]) if row and row[0] is not None else 0
    except Exception as exc:
        logger.warning("Could not count APPI consented users: %s", exc)
        return 0


def _get_last_deletion_cron_info(db: Session) -> tuple[Optional[str], int]:
    """Return (last_run_iso, purged_count) for the most recent deletion cron execution.

    Reads from jp_deletion_cron_log if it exists (migration 0158+).
    Falls back to scanning users.deleted_at for an approximation when the log table
    is absent (e.g., older DB without migration applied).

    Returns: (None, 0) if no data found.
    """
    try:
        # Try dedicated cron log table first (preferred — set in deletion_cron.py)
        result = db.execute(
            text(
                "SELECT ran_at, purged_count FROM jp_deletion_cron_log "
                "ORDER BY ran_at DESC LIMIT 1"
            )
        )
        row = result.fetchone()
        if row:
            ran_at: Optional[str] = row[0].isoformat() if row[0] else None
            count = int(row[1]) if row[1] is not None else 0
            return ran_at, count
    except Exception:
        # Table may not exist — fall through to approximation
        pass

    # Approximation: count users anonymized today via deleted_at
    try:
        result = db.execute(
            text(
                "SELECT MAX(deleted_at), COUNT(*) FROM users "
                "WHERE deleted_at IS NOT NULL "
                "  AND email LIKE '%@deleted.ancu365.jp'"
            )
        )
        row = result.fetchone()
        if row and row[0]:
            last_run_iso: Optional[str] = row[0].isoformat() if row[0] else None
            count = int(row[1]) if row[1] is not None else 0
            return last_run_iso, count
    except Exception as exc:
        logger.warning("Could not determine last deletion cron run: %s", exc)

    return None, 0


def _get_pii_key_rotation_date(db: Session) -> Optional[str]:
    """Return ISO date string of the last PII Fernet key rotation.

    Reads from pii_key_rotation_log if present.
    Returns None if table absent or no rotations recorded.
    """
    try:
        result = db.execute(
            text(
                "SELECT MAX(rotated_at) FROM pii_key_rotation_log"
            )
        )
        row = result.fetchone()
        if row and row[0]:
            rotated: datetime = row[0]
            return rotated.date().isoformat()
    except Exception:
        # Table may not exist — expected on fresh envs
        pass
    return None


def _get_hmac_rotation_ledger(db: Session) -> list[HmacRotationEntry]:
    """Build per-org HMAC secret rotation ledger.

    Reads from org_webhook_hmac_rotations if present; falls back to
    org_provider_configs hmac_rotated_at column if that table is absent.

    Returns empty list on any failure.
    """
    entries: list[HmacRotationEntry] = []

    try:
        # Try dedicated rotation ledger table
        result = db.execute(
            text(
                "SELECT org_id, MAX(rotated_at) AS last_rotated, COUNT(*) AS cnt "
                "FROM org_webhook_hmac_rotations "
                "GROUP BY org_id "
                "ORDER BY org_id"
            )
        )
        rows = result.fetchall()
        for row in rows:
            entries.append(
                HmacRotationEntry(
                    org_id=str(row[0]),
                    rotated_at=row[1].isoformat() if row[1] else "",
                    rotation_count=int(row[2]) if row[2] else 0,
                )
            )
        return entries
    except Exception:
        # Table may not exist — try fallback
        pass

    try:
        # Fallback: read from org_webhook_events — look for event_type=hmac_rotated
        result = db.execute(
            text(
                "SELECT org_id, MAX(created_at) AS last_rotated, "
                "       COUNT(*) AS cnt "
                "FROM jp_webhook_events "
                "WHERE event_type = 'hmac_rotated' "
                "GROUP BY org_id "
                "ORDER BY org_id"
            )
        )
        rows = result.fetchall()
        for row in rows:
            entries.append(
                HmacRotationEntry(
                    org_id=str(row[0]),
                    rotated_at=row[1].isoformat() if row[1] else "",
                    rotation_count=int(row[2]) if row[2] else 0,
                )
            )
    except Exception as exc:
        logger.warning("Could not fetch HMAC rotation ledger: %s", exc)

    return entries


def build_compliance_evidence(db: Session) -> ComplianceEvidenceResponse:
    """Assemble the full compliance evidence snapshot.

    Aggregates data from multiple sources. Any individual source failure
    is handled gracefully — the endpoint returns partial data with 0/null
    rather than a 500.

    Args:
        db: SQLAlchemy session (read-only operations only).

    Returns:
        ComplianceEvidenceResponse with all APPI audit data points.
    """
    generated_at = datetime.now(timezone.utc).isoformat()

    consented_count = _count_appi_consented_users(db)
    last_cron_run, purged_count = _get_last_deletion_cron_info(db)
    pii_rotation_date = _get_pii_key_rotation_date(db)
    hmac_ledger = _get_hmac_rotation_ledger(db)

    return ComplianceEvidenceResponse(
        appi_consented_users_count=consented_count,
        last_deletion_cron_run=last_cron_run,
        last_deletion_purged_count=purged_count,
        pii_key_rotation_date=pii_rotation_date,
        hmac_rotation_ledger=hmac_ledger,
        generated_at=generated_at,
    )
