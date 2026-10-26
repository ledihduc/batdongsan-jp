"""Notification service package — email, SMS, in-app delivery + escalation ladder.

Phase 08: Owner-Operator Delegation v1.
Provider strategy: default 'stub' (log + DB only) for v0. Swap to 'ses' / 'esms'
via NOTIFICATION_EMAIL_PROVIDER / NOTIFICATION_SMS_PROVIDER env vars once vendor
contracts are signed (pre-launch validation gate).

Public API:
    NotificationService.create(...)  — dispatch a notification across channels
    schedule_approval_escalation(...)  — register 24h/48h/60h/72h escalation jobs
    cancel_approval_escalation(...)    — cancel pending escalation jobs on decision
    run_weekly_digest_job()             — AC-41 Monday 08:00 ICT digest
"""

from app.services.notification.notification_service import NotificationService

__all__ = ["NotificationService"]
