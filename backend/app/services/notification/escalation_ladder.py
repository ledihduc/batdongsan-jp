"""Escalation ladder scheduler for pending approval requests.

AC-30b ladder (standard):
    T+0h   : push + in_app (initial — called by approval_service at creation)
    T+24h  : push + email   (reminder)
    T+24h* : SMS             (* only if high-value ≥20M VND/month AND email not opened)
    T+48h  : push + email   (final reminder)
    T+60h  : SMS            (last gate before auto-reject)
    T+72h  : auto-REJECT + SMS + in_app admin alert (phase-04 owns REJECT; phase-08 owns SMS)

KB04 fast-track (AC-55 / 6h SLA — compressed ladder):
    T+1h  : push
    T+3h  : push + email + SMS
    T+6h  : auto-action

Fraud-termination lockdown (AC-43b / 24h SLA):
    T+0h  : push + email + SMS
    T+12h : push + SMS reminder
    T+24h : auto-REJECT

APScheduler job IDs:
    escalate_approval_{approval_id}_{stage}
    e.g. escalate_approval_abc123_24h

Risk R4 mitigation (APScheduler job loss on restart):
    On app startup, approval_service should call reschedule_pending_approvals()
    to re-register any jobs that were lost during restart. Jobs are idempotent
    (replace_existing=True).

Usage:
    from app.services.notification.escalation_ladder import (
        schedule_approval_escalation,
        cancel_approval_escalation,
    )

    # Called when a new approval_request is created:
    schedule_approval_escalation(scheduler, approval_id, created_at, config)

    # Called when approval is decided (approved or rejected):
    cancel_approval_escalation(scheduler, approval_id)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional

logger = logging.getLogger(__name__)

# High-value monthly rent threshold for early SMS trigger (NFR-14)
HIGH_VALUE_RENT_THRESHOLD_VND = 20_000_000


@dataclass
class ApprovalEscalationConfig:
    """Config for a single approval's escalation ladder."""

    approval_id: str
    owner_id: int
    operator_id: int
    owner_email: Optional[str] = None
    owner_phone: Optional[str] = None
    property_name: str = ""
    operator_name: str = ""
    request_type_label: str = ""
    monthly_rent_vnd: Optional[float] = None
    approval_url: str = ""
    ladder_type: str = "standard"  # "standard" | "kb04_fasttrack" | "fraud_lockdown"
    # Context passed to notification templates
    extra_context: dict = field(default_factory=dict)


def schedule_approval_escalation(
    scheduler: object,
    config: ApprovalEscalationConfig,
    created_at: datetime,
    db_session_factory: object,
) -> None:
    """Register APScheduler jobs for the escalation ladder.

    Args:
        scheduler: APScheduler BackgroundScheduler instance
        config: ApprovalEscalationConfig with owner/operator details
        created_at: datetime when the approval_request was created (T+0)
        db_session_factory: callable returning a DB session (for deferred jobs)

    Jobs are registered with replace_existing=True for idempotent re-registration
    on app restart (risk R4 mitigation).
    """
    ladder = _build_ladder(config, created_at)
    for job_id, run_date, stage_fn, args in ladder:
        try:
            scheduler.add_job(  # type: ignore[union-attr]
                stage_fn,
                trigger="date",
                run_date=run_date,
                id=job_id,
                replace_existing=True,
                misfire_grace_time=3600,
                args=args,
            )
            logger.info(
                "[ESCALATION] Scheduled job %s at %s for approval %s",
                job_id,
                run_date.isoformat(),
                config.approval_id,
            )
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "[ESCALATION] Failed to schedule job %s: %s", job_id, exc
            )


def cancel_approval_escalation(scheduler: object, approval_id: str) -> None:
    """Cancel all pending escalation jobs for a given approval_id.

    Called when approval is decided (approved or rejected) to prevent
    unnecessary escalation notifications.
    """
    stages = ["24h", "48h", "60h", "72h", "1h", "3h", "6h", "12h"]
    for stage in stages:
        job_id = _job_id(approval_id, stage)
        try:
            scheduler.remove_job(job_id)  # type: ignore[union-attr]
            logger.info(
                "[ESCALATION] Cancelled job %s (approval decided)", job_id
            )
        except Exception:  # noqa: BLE001 — job may not exist (already fired/not scheduled)
            pass


def _job_id(approval_id: str, stage: str) -> str:
    """Canonical job ID format: escalate_approval_{approval_id}_{stage}."""
    return f"escalate_approval_{approval_id}_{stage}"


def _build_ladder(
    config: ApprovalEscalationConfig,
    created_at: datetime,
) -> list[tuple[str, datetime, object, list]]:
    """Build the list of (job_id, run_date, job_fn, args) tuples for the ladder."""
    ladder_type = config.ladder_type

    if ladder_type == "kb04_fasttrack":
        return _kb04_ladder(config, created_at)
    if ladder_type == "fraud_lockdown":
        return _fraud_lockdown_ladder(config, created_at)
    return _standard_ladder(config, created_at)


def _standard_ladder(
    config: ApprovalEscalationConfig,
    created_at: datetime,
) -> list[tuple[str, datetime, object, list]]:
    """Standard escalation: 24h email, 48h email final, 60h SMS, 72h auto-reject SMS."""
    base_ctx = _base_context(config)
    jobs = []

    # T+24h: push + email reminder
    jobs.append((
        _job_id(config.approval_id, "24h"),
        created_at + timedelta(hours=24),
        _run_email_escalation_job,
        [config.approval_id, config.owner_id, config.owner_email,
         "approval_reminder_24h", {**base_ctx}, config.monthly_rent_vnd],
    ))

    # T+48h: push + email final reminder
    jobs.append((
        _job_id(config.approval_id, "48h"),
        created_at + timedelta(hours=48),
        _run_email_escalation_job,
        [config.approval_id, config.owner_id, config.owner_email,
         "approval_reminder_48h", {**base_ctx}, None],
    ))

    # T+60h: SMS (last gate)
    jobs.append((
        _job_id(config.approval_id, "60h"),
        created_at + timedelta(hours=60),
        _run_sms_escalation_job,
        [config.approval_id, config.owner_id, config.owner_phone,
         "approval_reminder_48h", {**base_ctx}],
    ))

    # T+72h: SMS auto-reject notification (auto-REJECT itself is phase-04's job)
    jobs.append((
        _job_id(config.approval_id, "72h"),
        created_at + timedelta(hours=72),
        _run_auto_reject_notification_job,
        [config.approval_id, config.owner_id, config.owner_phone, {**base_ctx}],
    ))

    return jobs


def _kb04_ladder(
    config: ApprovalEscalationConfig,
    created_at: datetime,
) -> list[tuple[str, datetime, object, list]]:
    """KB04 fast-track: 1h push, 3h push+email+SMS, 6h auto-action notification."""
    base_ctx = _base_context(config)
    jobs = []

    # T+3h: email + SMS (compressed)
    jobs.append((
        _job_id(config.approval_id, "3h"),
        created_at + timedelta(hours=3),
        _run_email_escalation_job,
        [config.approval_id, config.owner_id, config.owner_email,
         "approval_reminder_24h", {**base_ctx, "is_kb04": True}, None],
    ))

    # T+6h: SMS auto-reject notification
    jobs.append((
        _job_id(config.approval_id, "6h"),
        created_at + timedelta(hours=6),
        _run_auto_reject_notification_job,
        [config.approval_id, config.owner_id, config.owner_phone, {**base_ctx}],
    ))

    return jobs


def _fraud_lockdown_ladder(
    config: ApprovalEscalationConfig,
    created_at: datetime,
) -> list[tuple[str, datetime, object, list]]:
    """Fraud-termination lockdown: 12h reminder, 24h auto-reject notification."""
    base_ctx = _base_context(config)
    jobs = []

    # T+12h: SMS reminder
    jobs.append((
        _job_id(config.approval_id, "12h"),
        created_at + timedelta(hours=12),
        _run_sms_escalation_job,
        [config.approval_id, config.owner_id, config.owner_phone,
         "approval_reminder_24h", {**base_ctx}],
    ))

    # T+24h: auto-reject SMS notification
    jobs.append((
        _job_id(config.approval_id, "24h"),
        created_at + timedelta(hours=24),
        _run_auto_reject_notification_job,
        [config.approval_id, config.owner_id, config.owner_phone, {**base_ctx}],
    ))

    return jobs


def _base_context(config: ApprovalEscalationConfig) -> dict:
    """Build the base template context from config."""
    return {
        "operator_name": config.operator_name,
        "property_name": config.property_name,
        "request_type_label": config.request_type_label,
        "monthly_rent_vnd": config.monthly_rent_vnd,
        "approval_url": config.approval_url,
        "approval_url_short": config.approval_url,  # URL shortener: future v2
        "app_url": "https://ancu365.com",
        **config.extra_context,
    }


# ---------------------------------------------------------------------------
# Job functions — called by APScheduler
# These are module-level functions (not methods) because APScheduler serialises
# callables by dotted module path.
# ---------------------------------------------------------------------------


def _run_email_escalation_job(
    approval_id: str,
    owner_id: int,
    owner_email: Optional[str],
    notification_type: str,
    context: dict,
    monthly_rent_vnd: Optional[float],
) -> None:
    """APScheduler job: send escalation email for a pending approval.

    Re-checks approval status before sending to avoid stale notifications.
    High-value threshold check: if monthly_rent_vnd ≥ 20M VND at 24h stage
    AND email not opened → also send SMS (NFR-14 early trigger).
    """
    import asyncio as _asyncio

    logger.info(
        "[ESCALATION JOB] email approval_id=%s owner_id=%d type=%s",
        approval_id,
        owner_id,
        notification_type,
    )

    if not owner_email:
        logger.warning(
            "[ESCALATION JOB] No owner email for approval %s — skipping email", approval_id
        )
        return

    # Check if approval is still pending (avoid stale escalation)
    if not _is_approval_still_pending(approval_id):
        logger.info(
            "[ESCALATION JOB] Approval %s no longer pending — skipping escalation",
            approval_id,
        )
        return

    try:
        from app.config import settings as _settings
        from app.database import SessionLocal as _SessionLocal
        from app.services.notification.notification_service import (
            NotificationRequest,
            NotificationService,
        )

        svc = NotificationService.from_settings(_settings)
        req = NotificationRequest(
            user_id=owner_id,
            notification_type=notification_type,
            title=context.get("property_name", "ancu365"),
            body="",
            channels=["in_app", "email"],
            context=context,
            to_email=owner_email,
            lang="vi",
        )

        db = _SessionLocal()
        try:
            _asyncio.run(svc.create(db, req))
            db.commit()
        finally:
            db.close()

        # NFR-14: high-value early SMS at 24h if email not opened
        if (
            notification_type == "approval_reminder_24h"
            and monthly_rent_vnd is not None
            and monthly_rent_vnd >= HIGH_VALUE_RENT_THRESHOLD_VND
        ):
            _maybe_send_early_sms(approval_id, owner_id, context)

    except Exception as exc:  # noqa: BLE001
        logger.error(
            "[ESCALATION JOB] email job failed approval_id=%s: %s",
            approval_id,
            exc,
            exc_info=True,
        )


def _run_sms_escalation_job(
    approval_id: str,
    owner_id: int,
    owner_phone: Optional[str],
    notification_type: str,
    context: dict,
) -> None:
    """APScheduler job: send escalation SMS for a pending approval."""
    import asyncio as _asyncio

    logger.info(
        "[ESCALATION JOB] sms approval_id=%s owner_id=%d type=%s",
        approval_id,
        owner_id,
        notification_type,
    )

    if not owner_phone:
        logger.warning(
            "[ESCALATION JOB] No owner phone for approval %s — skipping SMS", approval_id
        )
        return

    if not _is_approval_still_pending(approval_id):
        logger.info(
            "[ESCALATION JOB] Approval %s no longer pending — skipping SMS", approval_id
        )
        return

    try:
        from app.config import settings as _settings
        from app.database import SessionLocal as _SessionLocal
        from app.services.notification.notification_service import (
            NotificationRequest,
            NotificationService,
        )

        svc = NotificationService.from_settings(_settings)
        req = NotificationRequest(
            user_id=owner_id,
            notification_type=notification_type,
            title=context.get("property_name", "ancu365"),
            body="",
            channels=["sms"],
            context=context,
            to_phone=owner_phone,
            lang="vi",
        )

        db = _SessionLocal()
        try:
            _asyncio.run(svc.create(db, req))
            db.commit()
        finally:
            db.close()

    except Exception as exc:  # noqa: BLE001
        logger.error(
            "[ESCALATION JOB] sms job failed approval_id=%s: %s",
            approval_id,
            exc,
            exc_info=True,
        )


def _run_auto_reject_notification_job(
    approval_id: str,
    owner_id: int,
    owner_phone: Optional[str],
    context: dict,
) -> None:
    """APScheduler job: send SMS notification when approval is auto-rejected.

    NOTE: The actual auto-REJECT (status change) is phase-04's responsibility.
    This job only sends the notification to the owner.
    """
    import asyncio as _asyncio

    logger.info(
        "[ESCALATION JOB] auto_reject_notification approval_id=%s owner_id=%d",
        approval_id,
        owner_id,
    )

    if not owner_phone:
        logger.warning(
            "[ESCALATION JOB] No owner phone for approval %s — skipping auto-reject SMS",
            approval_id,
        )
        return

    try:
        from app.config import settings as _settings
        from app.database import SessionLocal as _SessionLocal
        from app.services.notification.notification_service import (
            NotificationRequest,
            NotificationService,
        )

        svc = NotificationService.from_settings(_settings)
        req = NotificationRequest(
            user_id=owner_id,
            notification_type="approval_auto_rejected",
            title="Yêu cầu đã bị từ chối tự động",
            body="",
            channels=["in_app", "sms"],
            context=context,
            to_phone=owner_phone,
            lang="vi",
        )

        db = _SessionLocal()
        try:
            _asyncio.run(svc.create(db, req))
            db.commit()
        finally:
            db.close()

    except Exception as exc:  # noqa: BLE001
        logger.error(
            "[ESCALATION JOB] auto_reject_notification failed approval_id=%s: %s",
            approval_id,
            exc,
            exc_info=True,
        )


def _is_approval_still_pending(approval_id: str) -> bool:
    """Check if approval_request is still pending_owner_approval.

    Returns True if pending (escalation should proceed).
    Returns False if decided/expired (escalation should be skipped).
    On DB error: returns True (err on the side of over-notifying vs silent drops).
    """
    try:
        from app.database import SessionLocal as _SL
        from sqlalchemy import text

        db = _SL()
        try:
            row = db.execute(
                text(
                    "SELECT status FROM delegation_approvals WHERE id = :id LIMIT 1"
                ),
                {"id": approval_id},
            ).fetchone()
            if row is None:
                return False
            status = str(row[0])
            return status == "pending_owner_approval"
        finally:
            db.close()
    except Exception as exc:  # noqa: BLE001
        logger.error(
            "[ESCALATION] Could not check approval status for %s: %s — defaulting to pending",
            approval_id,
            exc,
        )
        return True  # err on the side of over-notifying


def _maybe_send_early_sms(
    approval_id: str,
    owner_id: int,
    context: dict,
) -> None:
    """NFR-14: send early SMS at 24h if high-value email was not opened.

    Checks Notification.read_receipt_opened_at for the most recent email
    notification for this approval. If not opened within 24h → send SMS.
    """
    try:
        from app.database import SessionLocal as _SL
        from sqlalchemy import text

        db = _SL()
        try:
            # Find the most recent email notification for this approval
            row = db.execute(
                text(
                    "SELECT read_receipt_opened_at FROM notifications "
                    "WHERE related_id = :related_id AND channel = 'email' "
                    "ORDER BY created_at DESC LIMIT 1"
                ),
                {"related_id": int(context.get("related_id", 0)) if context.get("related_id") else 0},
            ).fetchone()

            email_opened = row is not None and row[0] is not None

            if not email_opened:
                logger.info(
                    "[NFR-14] High-value approval %s email not opened at 24h — triggering early SMS",
                    approval_id,
                )
                # Trigger SMS via sms escalation
                owner_phone = context.get("owner_phone")
                if owner_phone:
                    import asyncio as _asyncio
                    from app.config import settings as _settings
                    from app.services.notification.notification_service import (
                        NotificationRequest,
                        NotificationService,
                    )
                    svc = NotificationService.from_settings(_settings)
                    req = NotificationRequest(
                        user_id=owner_id,
                        notification_type="approval_reminder_24h",
                        title="Cần phê duyệt khẩn",
                        body="",
                        channels=["sms"],
                        context=context,
                        to_phone=owner_phone,
                        lang="vi",
                    )
                    db2 = _SL()
                    try:
                        _asyncio.run(svc.create(db2, req))
                        db2.commit()
                    finally:
                        db2.close()
            else:
                logger.info(
                    "[NFR-14] High-value approval %s email WAS opened — no early SMS needed",
                    approval_id,
                )
        finally:
            db.close()
    except Exception as exc:  # noqa: BLE001
        logger.error("[NFR-14] early SMS check failed: %s", exc)
