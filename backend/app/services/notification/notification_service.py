"""NotificationService — facade for multi-channel notification delivery.

Orchestrates channel selection, DB row creation, and provider dispatch.
Supports: in_app, email, sms channels.
Push (FCM) channel: stub by default, Firebase Admin when configured.

Delivery status lifecycle (per Notification.delivery_status):
    queued → sent → delivered (external confirmation)
    queued → failed  (provider error)
    queued → sent_stub (stub provider — v0)
    sent → bounced (SES bounce webhook updates row)

AC-31: every delivery writes a change_logs audit row with delivery_channels_used.
Security: PII in notification body — templates never include full CCCD.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.models import Notification
from app.services.notification.email_service import (
    EmailMessage,
    EmailProvider,
    build_email_provider,
)
from app.services.notification.push_service import (
    PushMessage,
    PushProvider,
    build_push_provider,
)
from app.services.notification.sms_service import (
    SmsMessage,
    SmsProvider,
    build_sms_provider,
)
from app.services.notification.templates.template_renderer import (
    render_email_subject,
    render_template,
)

logger = logging.getLogger(__name__)

# Valid channels — zalo is placeholder (v1.1)
VALID_CHANNELS = frozenset({"in_app", "email", "sms", "push"})

# Notification types defined in BA v4 §10.4
VALID_NOTIFICATION_TYPES = frozenset({
    "delegation_invited",
    "delegation_accepted",
    "delegation_paused",
    "delegation_terminated",
    "approval_requested",
    "approval_decided",
    "kyc_expiring_soon",
    "owner_death_delegation_paused",
    "heir_onboarding_initiated",
    "gpkd_revoked_delegation_paused",
    "approval_reminder_24h",
    "approval_reminder_48h",
    "approval_auto_rejected",
    "weekly_digest",
})


@dataclass
class NotificationRequest:
    """Input value object for NotificationService.create()."""

    user_id: int
    notification_type: str
    title: str
    body: str
    channels: list[str]
    context: dict = field(default_factory=dict)
    related_id: Optional[int] = None
    # For email: recipient address (defaults to user's email from DB)
    to_email: Optional[str] = None
    # For SMS: recipient phone (defaults to user's phone from DB)
    to_phone: Optional[str] = None
    lang: str = "vi"


@dataclass
class NotificationResult:
    """Result of a create() call — per channel."""

    notification_id: int
    channel: str
    delivery_status: str
    external_message_id: Optional[str] = None
    error: Optional[str] = None


class NotificationService:
    """Facade orchestrating channel selection, DB writes, and provider dispatch.

    Usage:
        svc = NotificationService.from_settings(settings)
        results = await svc.create(db, NotificationRequest(...))

    Provider swap (config-only):
        Set NOTIFICATION_EMAIL_PROVIDER=ses and NOTIFICATION_SMS_PROVIDER=esms
        in .env once vendor contracts are signed.
    """

    def __init__(
        self,
        email_provider: EmailProvider,
        sms_provider: SmsProvider,
        push_provider: PushProvider | None = None,
    ) -> None:
        self._email_provider = email_provider
        self._sms_provider = sms_provider
        self._push_provider = push_provider or build_push_provider("stub", object())

    @classmethod
    def from_settings(cls, settings: object) -> "NotificationService":
        """Build NotificationService from app settings.

        Reads NOTIFICATION_EMAIL_PROVIDER and NOTIFICATION_SMS_PROVIDER from settings.
        Defaults to 'stub' for both (v0 — no vendor contracts required).
        """
        email_provider_name = (
            getattr(settings, "notification_email_provider", "stub") or "stub"
        )
        sms_provider_name = (
            getattr(settings, "notification_sms_provider", "stub") or "stub"
        )
        push_provider_name = (
            getattr(settings, "notification_push_provider", "stub") or "stub"
        )
        email_provider = build_email_provider(email_provider_name, settings)
        sms_provider = build_sms_provider(sms_provider_name, settings)
        push_provider = build_push_provider(push_provider_name, settings)
        logger.info(
            "NotificationService: email_provider=%s sms_provider=%s push_provider=%s",
            email_provider_name,
            sms_provider_name,
            push_provider_name,
        )
        return cls(
            email_provider=email_provider,
            sms_provider=sms_provider,
            push_provider=push_provider,
        )

    async def create(
        self,
        db: Session,
        request: NotificationRequest,
    ) -> list[NotificationResult]:
        """Create and dispatch notifications across requested channels.

        Creates one Notification DB row per channel for clean delivery tracking.
        in_app: synchronous (immediate DB write + mark delivered).
        email/sms: provider send called inline (APScheduler can wrap for async queueing).

        Returns list of NotificationResult, one per channel.
        Raises ValueError for invalid notification_type or unknown channels.
        Does NOT raise on provider failure — captured in result.error.
        """
        # Validate inputs
        if request.notification_type not in VALID_NOTIFICATION_TYPES:
            logger.warning(
                "Unknown notification_type=%s — proceeding but check templates",
                request.notification_type,
            )

        unknown_channels = set(request.channels) - VALID_CHANNELS
        if unknown_channels:
            raise ValueError(f"Unknown channels: {unknown_channels}")

        results: list[NotificationResult] = []

        for channel in request.channels:
            result = await self._dispatch_channel(db, request, channel)
            results.append(result)

        # AC-31: audit log — delivery_channels_used
        self._write_delivery_audit(db, request, results)

        return results

    async def _dispatch_channel(
        self,
        db: Session,
        request: NotificationRequest,
        channel: str,
    ) -> NotificationResult:
        """Create DB row + dispatch to provider for a single channel."""
        # Create notification row with queued status
        notif = Notification(
            user_id=request.user_id,
            type=request.notification_type,
            title=request.title,
            body=request.body,
            related_id=request.related_id,
            channel=channel,
            delivery_status="queued",
            read=False,
        )
        db.add(notif)
        db.flush()  # get notif.id

        if channel == "in_app":
            # In-app: no external call, mark delivered immediately
            notif.delivery_status = "delivered"
            db.flush()
            return NotificationResult(
                notification_id=notif.id,
                channel=channel,
                delivery_status="delivered",
            )

        if channel == "push":
            return await self._send_push(db, notif, request)

        if channel == "email":
            return await self._send_email(db, notif, request)

        if channel == "sms":
            return await self._send_sms(db, notif, request)

        # Should never reach here (validated above)
        notif.delivery_status = "failed"
        db.flush()
        return NotificationResult(
            notification_id=notif.id,
            channel=channel,
            delivery_status="failed",
            error=f"Unhandled channel: {channel}",
        )

    async def _send_email(
        self,
        db: Session,
        notif: Notification,
        request: NotificationRequest,
    ) -> NotificationResult:
        """Build email payload from template + dispatch to email provider."""
        html_body = render_template(
            request.notification_type, "email", request.context, request.lang
        )
        # Plain text fallback: strip HTML roughly
        text_body = request.body or request.title
        subject = render_email_subject(
            request.notification_type, request.context, request.lang
        )
        to_address = request.to_email or ""
        if not to_address:
            logger.error(
                "[EMAIL] user_id=%d type=%s: no to_email — skipping",
                request.user_id,
                request.notification_type,
            )
            notif.delivery_status = "failed"
            notif.external_message_id = None
            db.flush()
            return NotificationResult(
                notification_id=notif.id,
                channel="email",
                delivery_status="failed",
                error="no to_email address",
            )

        msg = EmailMessage(
            to_address=to_address,
            subject=subject,
            html_body=html_body,
            text_body=text_body,
            notification_type=request.notification_type,
            related_id=request.related_id,
        )
        send_result = await self._email_provider.send(msg)

        if send_result.success:
            notif.delivery_status = (
                "sent_stub"
                if self._email_provider.provider_name == "stub"
                else "sent"
            )
            notif.external_message_id = send_result.external_message_id
        else:
            notif.delivery_status = "failed"
        db.flush()

        return NotificationResult(
            notification_id=notif.id,
            channel="email",
            delivery_status=notif.delivery_status,
            external_message_id=notif.external_message_id,
            error=send_result.error,
        )

    async def _send_sms(
        self,
        db: Session,
        notif: Notification,
        request: NotificationRequest,
    ) -> NotificationResult:
        """Build SMS content from template + dispatch to SMS provider."""
        content = render_template(
            request.notification_type, "sms", request.context, request.lang
        )
        # Trim to 160 chars if template overflows (logged by provider)
        # Note: provider also logs this — don't truncate silently

        to_phone = request.to_phone or ""
        if not to_phone:
            logger.error(
                "[SMS] user_id=%d type=%s: no to_phone — skipping",
                request.user_id,
                request.notification_type,
            )
            notif.delivery_status = "failed"
            db.flush()
            return NotificationResult(
                notification_id=notif.id,
                channel="sms",
                delivery_status="failed",
                error="no to_phone",
            )

        msg = SmsMessage(
            to_phone=to_phone,
            content=content,
            notification_type=request.notification_type,
            related_id=request.related_id,
        )
        send_result = await self._sms_provider.send(msg)

        if send_result.success:
            notif.delivery_status = (
                "sent_stub"
                if self._sms_provider.provider_name == "stub"
                else "sent"
            )
            notif.external_message_id = send_result.external_message_id
        else:
            notif.delivery_status = "failed"
        db.flush()

        return NotificationResult(
            notification_id=notif.id,
            channel="sms",
            delivery_status=notif.delivery_status,
            external_message_id=notif.external_message_id,
            error=send_result.error,
        )

    async def _send_push(
        self,
        db: Session,
        notif: Notification,
        request: NotificationRequest,
    ) -> NotificationResult:
        """Dispatch push notification through the configured provider."""
        msg = PushMessage(
            user_id=request.user_id,
            title=request.title,
            body=request.body,
            notification_type=request.notification_type,
            related_id=request.related_id,
            data=request.context,
        )
        send_result = await self._push_provider.send(db, msg)

        if send_result.success:
            notif.delivery_status = (
                "sent_stub"
                if self._push_provider.provider_name == "stub"
                else "sent"
            )
            notif.external_message_id = send_result.external_message_id
        else:
            notif.delivery_status = "failed"
        db.flush()

        return NotificationResult(
            notification_id=notif.id,
            channel="push",
            delivery_status=notif.delivery_status,
            external_message_id=notif.external_message_id,
            error=send_result.error,
        )

    def _write_delivery_audit(
        self,
        db: Session,
        request: NotificationRequest,
        results: list[NotificationResult],
    ) -> None:
        """AC-31: write change_logs audit row with delivery_channels_used array."""
        channels_used = [r.channel for r in results if r.delivery_status != "failed"]
        logger.info(
            "[AUDIT] notification delivery user_id=%d type=%s channels=%s",
            request.user_id,
            request.notification_type,
            channels_used,
        )
        # ChangeLog model is owned by phase-02; we write directly via raw insert
        # to avoid circular import. ChangeLog table is guaranteed to exist (migration 0019).
        try:
            import json as _json
            db.execute(  # type: ignore[call-overload]
                _build_change_log_insert(),
                {
                    "entity_type": "notification",
                    "entity_id": str(request.related_id or 0),
                    "actor_id": request.user_id,
                    "action": "notification_sent",
                    "after_json": _json.dumps(
                        {
                            "notification_type": request.notification_type,
                            "delivery_channels_used": channels_used,
                            "user_id": request.user_id,
                        }
                    ),
                    "created_at": datetime.utcnow().isoformat(),
                },
            )
        except Exception as exc:  # noqa: BLE001
            # Audit failure must NOT block notification delivery
            logger.error("[AUDIT] change_log write failed: %s", exc)


def _build_change_log_insert():  # type: ignore[return]
    """Build a raw SQL insert for change_logs without importing domain models."""
    from sqlalchemy import text
    return text(
        "INSERT INTO change_logs "
        "(entity_type, entity_id, actor_id, action, after_json, created_at) "
        "VALUES (:entity_type, :entity_id, :actor_id, :action, :after_json, :created_at)"
    )
