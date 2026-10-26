"""APScheduler daily cron — APPI user deletion purge.

Runs daily at 03:00 JST.
Finds users where deletion_scheduled_at < now() and soft-anonymizes them:
  - Hash email (SHA-256 prefix + random salt stored separate)
  - Clear first_name, last_name, phone
  - Keep id (FK integrity) and invoice rows (7-year tax retention)
  - Set deleted_at = now()

Irreversibility warning: this is a one-way operation.
72-hour grace is factored into deletion_scheduled_at at request time
(schedule = now + 30d, not shorter).

Misfire grace: 3600s — handles container restarts.
"""

from __future__ import annotations

import hashlib
import logging
import secrets
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)

_ANON_EMAIL_SUFFIX = "@deleted.ancu365.jp"


def _anonymize_email(original_email: str) -> str:
    """Hash original email to an irreversible but unique anonymized form."""
    salt = secrets.token_hex(8)
    h = hashlib.sha256(f"{salt}:{original_email}".encode("utf-8")).hexdigest()[:16]
    return f"anon-{h}{_ANON_EMAIL_SUFFIX}"


def _run_deletion_purge() -> None:
    """Soft-anonymize users past their deletion_scheduled_at.

    Called by APScheduler at 03:00 JST.
    Uses late imports to avoid mapper config issues at module load.
    """
    from app.database import SessionLocal
    from sqlalchemy import text

    now = datetime.now(timezone.utc)
    logger.info("Deletion cron: running at %s", now.isoformat())

    with SessionLocal() as db:
        try:
            # Find users past their deletion schedule (column added in migration 0158)
            result = db.execute(
                text(
                    "SELECT id, email FROM users "
                    "WHERE deletion_scheduled_at IS NOT NULL "
                    "  AND deletion_scheduled_at <= :now "
                    "  AND deleted_at IS NULL"
                ),
                {"now": now},
            )
            users = result.fetchall()
            logger.info("Deletion cron: %d users to anonymize", len(users))

            purged_count = 0
            for user_row in users:
                user_id: int = user_row[0]
                original_email: str = user_row[1] or ""
                try:
                    _anonymize_user(user_id, original_email, now, db)
                    db.commit()
                    purged_count += 1
                    logger.info("Deletion cron: anonymized user %d", user_id)
                except Exception as exc:
                    db.rollback()
                    logger.error(
                        "Deletion cron: failed to anonymize user %d: %s",
                        user_id, exc, exc_info=True,
                    )

            logger.info(
                "Deletion cron complete: purged=%d total=%d",
                purged_count, len(users),
            )

        except Exception as exc:
            db.rollback()
            logger.error("Deletion cron failed: %s", exc, exc_info=True)
            raise


def _anonymize_user(
    user_id: int,
    original_email: str,
    now: datetime,
    db: Any,
) -> None:
    """Soft-anonymize a single user row.

    Preserves id for FK integrity.
    Exempt from purge: invoice rows (queried but not touched here —
    7-year JP tax retention law applies).
    """
    from sqlalchemy import text

    anon_email = _anonymize_email(original_email)

    db.execute(
        text(
            "UPDATE users SET "
            "  email = :anon_email, "
            "  first_name = NULL, "
            "  last_name = NULL, "
            "  phone = NULL, "
            "  phone_masked = NULL, "
            "  deleted_at = :now, "
            "  deletion_scheduled_at = NULL "
            "WHERE id = :user_id"
        ),
        {"anon_email": anon_email, "now": now, "user_id": user_id},
    )
    db.flush()

    logger.info(
        "User %d anonymized: email→%s first/last/phone cleared",
        user_id, anon_email,
    )


def start_deletion_cron(scheduler: Any) -> None:
    """Register the daily deletion cron job with an APScheduler instance.

    Args:
        scheduler: APScheduler BackgroundScheduler or AsyncIOScheduler instance.
    """
    from apscheduler.triggers.cron import CronTrigger

    scheduler.add_job(
        _run_deletion_purge,
        trigger=CronTrigger(
            hour=3,
            minute=0,
            timezone="Asia/Tokyo",
        ),
        id="jp_deletion_daily",
        replace_existing=True,
        misfire_grace_time=3600,  # 1h grace on container restart
    )
    logger.info("Deletion cron registered: daily 03:00 JST")
