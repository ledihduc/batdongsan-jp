"""Email delivery service — provider interface + StubProvider + SESProvider.

Provider selection at startup via NOTIFICATION_EMAIL_PROVIDER env var:
  - "stub" (default): logs + writes DB row with delivery_status='sent_stub'. No HTTP.
  - "ses": AWS SES via boto3. Requires SES_REGION + SES_FROM_EMAIL in env.

Both providers implement EmailProvider interface — swap is config-only, no code change.

NFR-14: SES provider captures MessageId for read-receipt tracking via SNS webhook
(app/routers/webhooks_ses.py updates Notification.read_receipt_opened_at).
"""

from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Value types
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class EmailMessage:
    """Immutable email payload. Subject must NOT contain PII per security rules."""

    to_address: str
    subject: str
    html_body: str
    text_body: str
    # Optional reply-to for owner communications
    reply_to: Optional[str] = None
    # Metadata for audit / logging
    notification_type: str = ""
    related_id: Optional[int] = None


@dataclass
class SendResult:
    """Result of a send() call."""

    success: bool
    external_message_id: Optional[str] = None  # SES MessageId / vendor ref
    error: Optional[str] = None
    provider: str = "unknown"
    sent_at: datetime = field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# Provider interface
# ---------------------------------------------------------------------------


class EmailProvider(ABC):
    """Abstract email provider — all implementations must honour this contract."""

    @abstractmethod
    async def send(self, message: EmailMessage) -> SendResult:
        """Send an email. Implementations MUST NOT raise — return SendResult(success=False)."""
        ...

    @property
    @abstractmethod
    def provider_name(self) -> str: ...


# ---------------------------------------------------------------------------
# Stub provider (default, v0)
# ---------------------------------------------------------------------------


class StubEmailProvider(EmailProvider):
    """No-op provider for development and pre-contract phase.

    Records delivery_status='sent_stub' in the DB (via notification_service).
    All sends are logged at INFO level for verifiability without vendor costs.
    """

    @property
    def provider_name(self) -> str:
        return "stub"

    async def send(self, message: EmailMessage) -> SendResult:
        logger.info(
            "[EMAIL STUB] to=%s subject=%r type=%s related_id=%s",
            message.to_address,
            message.subject,
            message.notification_type,
            message.related_id,
        )
        return SendResult(
            success=True,
            external_message_id=f"stub-email-{datetime.utcnow().timestamp():.0f}",
            provider="stub",
        )


# ---------------------------------------------------------------------------
# AWS SES provider
# ---------------------------------------------------------------------------


class SESEmailProvider(EmailProvider):
    """AWS SES email provider via boto3.

    Required env vars (loaded from app.config.settings):
      SES_REGION       — AWS region (e.g. 'ap-southeast-1')
      SES_FROM_EMAIL   — Verified sender (e.g. 'noreply@ancu365.com')

    Pre-launch validation gates:
      - Domain SPF/DKIM/DMARC must be configured (scripts/configure_ses.sh).
      - SES account must be out of sandbox (production access request).
      - SNS topic subscription for bounce/open/click events must be active.
    """

    def __init__(self, region: str, from_email: str) -> None:
        self._region = region
        self._from_email = from_email
        self._client: object | None = None

    def _get_client(self) -> object:
        """Lazy boto3 client — avoids import crash when boto3 is not installed in stub mode."""
        if self._client is None:
            try:
                import boto3  # type: ignore[import-untyped]
                self._client = boto3.client("ses", region_name=self._region)
            except ImportError as exc:
                raise RuntimeError(
                    "boto3 is required for SES provider. "
                    "Install it or set NOTIFICATION_EMAIL_PROVIDER=stub."
                ) from exc
        return self._client

    @property
    def provider_name(self) -> str:
        return "ses"

    async def send(self, message: EmailMessage) -> SendResult:
        """Send via SES send_email API. Returns MessageId for read-receipt tracking."""
        try:
            client = self._get_client()
            # Build destination
            destination = {"ToAddresses": [message.to_address]}
            if message.reply_to:
                destination["ReplyToAddresses"] = [message.reply_to]

            response = client.send_email(  # type: ignore[union-attr]
                Source=self._from_email,
                Destination=destination,
                Message={
                    "Subject": {"Data": message.subject, "Charset": "UTF-8"},
                    "Body": {
                        "Text": {"Data": message.text_body, "Charset": "UTF-8"},
                        "Html": {"Data": message.html_body, "Charset": "UTF-8"},
                    },
                },
            )
            message_id: str = response["MessageId"]
            logger.info(
                "[EMAIL SES] sent to=%s type=%s ses_message_id=%s",
                message.to_address,
                message.notification_type,
                message_id,
            )
            return SendResult(
                success=True,
                external_message_id=message_id,
                provider="ses",
            )
        except Exception as exc:  # noqa: BLE001 — must not propagate to caller
            logger.error(
                "[EMAIL SES] FAILED to=%s type=%s error=%s",
                message.to_address,
                message.notification_type,
                exc,
                exc_info=True,
            )
            return SendResult(success=False, error=str(exc), provider="ses")


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------


def build_email_provider(provider_name: str, settings: object) -> EmailProvider:
    """Build an EmailProvider from config.

    Args:
        provider_name: "stub" | "ses"
        settings: app.config.Settings instance (or any object with SES_REGION, SES_FROM_EMAIL attrs)

    Returns:
        EmailProvider implementation. Raises ValueError for unknown provider names.
    """
    if provider_name == "stub":
        return StubEmailProvider()
    if provider_name == "ses":
        # Use attribute value if present and non-empty; fall back to env-sourced defaults.
        # If BOTH the attr is missing AND we can't find a reasonable default → raise.
        region = getattr(settings, "ses_region", None)
        from_email = getattr(settings, "ses_from_email", None)
        if not region or not from_email:
            raise ValueError(
                "SES provider requires SES_REGION and SES_FROM_EMAIL to be configured. "
                "Set them in .env or pass NOTIFICATION_EMAIL_PROVIDER=stub to use stub."
            )
        return SESEmailProvider(region=region, from_email=from_email)
    raise ValueError(
        f"Unknown email provider: {provider_name!r}. "
        "Valid values: 'stub', 'ses'."
    )
