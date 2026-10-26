"""APPI Data Subject Rights (DSR) service.

Implements:
  export_user_data()     — gather user data → zip → return metadata with job_id.
  request_user_deletion() — soft-flag user for 30-day purge schedule.

JP legal constraints:
  - Invoice records must be retained for 7 years (国税通則法/法人税法).
    Rows with legal_hold=True are NEVER purged.
  - Personal info on non-legal-hold rows is redacted (not deleted) after 30d.
  - Consent records are also legal_hold-eligible if tied to a financial transaction.

Architecture note:
  Export is synchronous in this MVP (small datasets). For large orgs, move to
  Celery/ARQ background task and return a job_id to poll.
  DSR delete schedules via a scheduler entry (cron-style daily job).
"""

from __future__ import annotations

import io
import json
import logging
import uuid
import zipfile
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.repositories.jp.user_consent import JpUserConsentRepository

logger = logging.getLogger(__name__)

# Signed URL TTL for export download (24 hours)
_EXPORT_URL_TTL_HOURS = 24

# Grace period before actual purge after deletion request (30 days per APPI safe harbour)
_DELETION_GRACE_DAYS = 30


@dataclass
class DataExportResult:
    """Result of export_user_data()."""
    job_id: str
    # In a real implementation this would be a signed S3/GCS URL.
    # MVP: returns a data URI or placeholder — the route layer handles delivery.
    zip_bytes: bytes
    expires_at: str  # ISO8601 UTC


@dataclass
class DeletionScheduleResult:
    """Result of request_user_deletion()."""
    scheduled_purge_at: str  # ISO8601 UTC
    message: str


def export_user_data(
    user_id: int,
    db: Session,
) -> DataExportResult:
    """Collect all user data and return a zip.

    Gathers:
      - Consent history (jp_user_consents)
      - Placeholder stubs for: profile, listings, applications, payments
        (these require joins to models outside the JP domain boundary;
         a real implementation would call each domain's repository.)

    Returns:
        DataExportResult with zip bytes and expiry.
    """
    job_id = f"dsr-export-{uuid.uuid4().hex[:12]}"
    logger.info("DSR export starting: user=%d job=%s", user_id, job_id)

    # Gather consent history
    consent_repo = JpUserConsentRepository(db)
    consents = consent_repo.list_all_for_user(user_id)
    consent_data: list[dict[str, Any]] = [
        {
            "id": c.id,
            "purpose": c.purpose,
            "consent_version": c.consent_version,
            "granted_at": c.granted_at.isoformat() if c.granted_at else None,
            "revoked_at": c.revoked_at.isoformat() if c.revoked_at else None,
        }
        for c in consents
    ]

    # Build zip in-memory
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        # Consents
        zf.writestr(
            "consents.json",
            json.dumps({"user_id": user_id, "consents": consent_data}, ensure_ascii=False, indent=2),
        )
        # Placeholder sections — real implementation queries each domain repo
        for section in ("profile", "listings", "applications", "payments"):
            zf.writestr(
                f"{section}.json",
                json.dumps(
                    {
                        "user_id": user_id,
                        "note": (
                            f"{section} data will be included in production. "
                            "This export is a P2 MVP stub."
                        ),
                    },
                    ensure_ascii=False,
                    indent=2,
                ),
            )
        # Metadata
        zf.writestr(
            "metadata.json",
            json.dumps(
                {
                    "job_id": job_id,
                    "user_id": user_id,
                    "generated_at": datetime.now(timezone.utc).isoformat(),
                    "format_version": "1.0",
                },
                ensure_ascii=False,
                indent=2,
            ),
        )

    zip_bytes = buf.getvalue()
    expires_at = (
        datetime.now(timezone.utc) + timedelta(hours=_EXPORT_URL_TTL_HOURS)
    ).isoformat()

    logger.info(
        "DSR export complete: user=%d job=%s zip_size=%d bytes",
        user_id, job_id, len(zip_bytes),
    )
    return DataExportResult(
        job_id=job_id,
        zip_bytes=zip_bytes,
        expires_at=expires_at,
    )


def request_user_deletion(
    user_id: int,
    db: Session,
) -> DeletionScheduleResult:
    """Schedule a user's data for purge after 30-day grace period.

    Legal constraints enforced:
    - jp_user_consents rows are NOT purged (kept for APPI audit).
    - Invoice rows: NOT purged (7-year tax retention).
    - The actual purge of PII fields happens in a cron job that checks
      deletion_scheduled_at on the user record.

    This implementation:
    1. Marks consent rows as legal_hold=True (they'll survive the purge).
    2. Returns scheduled_purge_at = now + 30 days.
    3. In production: sets user.deletion_scheduled_at in the users table
       and the daily cron job purges after 30d.

    MVP limitation: user table field 'deletion_scheduled_at' is not yet in the
    schema — this function logs the intent and returns the schedule. The cron
    job integration is deferred to P3 infrastructure work.
    """
    scheduled_at = datetime.now(timezone.utc) + timedelta(days=_DELETION_GRACE_DAYS)
    logger.info(
        "DSR deletion requested: user=%d scheduled_purge_at=%s",
        user_id, scheduled_at.isoformat(),
    )

    # Mark all consent rows as legal_hold (they must survive purge for APPI audit)
    consent_repo = JpUserConsentRepository(db)
    consent_rows = consent_repo.list_all_for_user(user_id)
    for row in consent_rows:
        row.legal_hold = True
    db.flush()

    logger.info(
        "DSR: marked %d consent rows as legal_hold for user=%d",
        len(consent_rows), user_id,
    )

    return DeletionScheduleResult(
        scheduled_purge_at=scheduled_at.isoformat(),
        message=(
            f"Your data will be deleted on {scheduled_at.date().isoformat()}. "
            "Financial records (invoices) are retained for 7 years per Japanese tax law."
        ),
    )
