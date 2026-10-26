"""SMS delivery service — provider interface + StubProvider + ESMSProvider.

Provider selection at startup via NOTIFICATION_SMS_PROVIDER env var:
  - "stub" (default): logs + writes DB row. No HTTP call.
  - "esms": eSMS.vn primary vendor. Requires ESMS_API_KEY + ESMS_SECRET_KEY.

Phone numbers are normalised to E.164 format ('+84XXXXXXXXX') before send.
SMS content must NOT include full CCCD, only masked values (security rule).

DLT registration: brand name 'ANCU365' must be registered with VN MIC before
eSMS provider goes live (~5 business days lead time — pre-launch validation gate).
"""

from __future__ import annotations

import hashlib
import logging
import re
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

# eSMS API endpoint (v2 JSON API)
_ESMS_SEND_URL = "https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json/"

# Max SMS content length (standard GSM-7 single-segment; eSMS concatenates if longer)
_SMS_MAX_CHARS = 160


# ---------------------------------------------------------------------------
# Value types
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class SmsMessage:
    """Immutable SMS payload. Never include full CCCD or sensitive PII."""

    to_phone: str  # Will be normalised to E.164 before send
    content: str  # Max 160 chars for single segment; longer = concatenated (extra cost)
    # Metadata for audit / logging
    notification_type: str = ""
    related_id: Optional[int] = None


@dataclass
class SmsSendResult:
    """Result of an SMS send attempt."""

    success: bool
    external_message_id: Optional[str] = None
    normalised_phone: Optional[str] = None
    error: Optional[str] = None
    provider: str = "unknown"
    sent_at: datetime = field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# Phone normalisation
# ---------------------------------------------------------------------------


def normalise_phone_e164(phone: str) -> str:
    """Normalise any Vietnamese phone format to E.164 '+84XXXXXXXXX'.

    Handles: 0XXXXXXXXX, 84XXXXXXXXX, +84XXXXXXXXX.
    Strips spaces, dashes, dots.
    Raises ValueError if result is not 12 chars ('+84' + 9 digits).
    """
    cleaned = re.sub(r"[\s\-\.]", "", phone.strip())
    if cleaned.startswith("+84"):
        e164 = cleaned
    elif cleaned.startswith("84"):
        e164 = "+" + cleaned
    elif cleaned.startswith("0"):
        e164 = "+84" + cleaned[1:]
    else:
        e164 = "+84" + cleaned

    # Validate: +84 + exactly 9 digits
    if not re.fullmatch(r"\+84\d{9}", e164):
        raise ValueError(
            f"Cannot normalise phone to E.164: {phone!r} → {e164!r}. "
            "Expected Vietnamese number with 9 digits after country code."
        )
    return e164


# ---------------------------------------------------------------------------
# Provider interface
# ---------------------------------------------------------------------------


class SmsProvider(ABC):
    """Abstract SMS provider — all implementations must honour this contract."""

    @abstractmethod
    async def send(self, message: SmsMessage) -> SmsSendResult:
        """Send an SMS. Implementations MUST NOT raise — return SmsSendResult(success=False)."""
        ...

    @property
    @abstractmethod
    def provider_name(self) -> str: ...


# ---------------------------------------------------------------------------
# Stub provider (default, v0)
# ---------------------------------------------------------------------------


class StubSmsProvider(SmsProvider):
    """No-op provider for development and pre-DLT-registration phase.

    Logs delivery at INFO level. No external HTTP calls. DB row written by caller
    (notification_service) with delivery_status='sent_stub'.
    """

    @property
    def provider_name(self) -> str:
        return "stub"

    async def send(self, message: SmsMessage) -> SmsSendResult:
        try:
            normalised = normalise_phone_e164(message.to_phone)
        except ValueError:
            normalised = message.to_phone  # log as-is but don't fail

        logger.info(
            "[SMS STUB] to=%s content_len=%d type=%s related_id=%s",
            normalised,
            len(message.content),
            message.notification_type,
            message.related_id,
        )
        return SmsSendResult(
            success=True,
            external_message_id=f"stub-sms-{datetime.utcnow().timestamp():.0f}",
            normalised_phone=normalised,
            provider="stub",
        )


# ---------------------------------------------------------------------------
# eSMS.vn provider
# ---------------------------------------------------------------------------


class ESMSSmsProvider(SmsProvider):
    """eSMS.vn primary SMS provider.

    Required env vars (loaded from app.config.settings):
      ESMS_API_KEY    — eSMS account API key
      ESMS_SECRET_KEY — eSMS account secret key

    The brand name (SmsType=2, Brandname='ANCU365') requires DLT registration
    with VN MIC before production use. Use SmsType=4 (OTP/transactional) during
    DLT registration period as interim measure.

    eSMS API docs: https://esms.vn/tai-lieu-api
    """

    def __init__(
        self,
        api_key: str,
        secret_key: str,
        brand_name: str = "ANCU365",
        sms_type: int = 2,  # 2 = brandname advertising; 4 = OTP/transactional
        timeout_s: int = 10,
    ) -> None:
        if not api_key or not secret_key:
            raise ValueError("ESMS_API_KEY and ESMS_SECRET_KEY must be non-empty.")
        self._api_key = api_key
        self._secret_key = secret_key
        self._brand_name = brand_name
        self._sms_type = sms_type
        self._timeout_s = timeout_s

    @property
    def provider_name(self) -> str:
        return "esms"

    async def send(self, message: SmsMessage) -> SmsSendResult:
        """Send SMS via eSMS.vn REST API v4."""
        try:
            normalised = normalise_phone_e164(message.to_phone)
        except ValueError as exc:
            logger.error("[SMS ESMS] Invalid phone: %s", exc)
            return SmsSendResult(success=False, error=str(exc), provider="esms")

        # Content length guard (log warning — eSMS will concatenate, but costs more)
        if len(message.content) > _SMS_MAX_CHARS:
            logger.warning(
                "[SMS ESMS] content length %d > %d chars — will be concatenated (extra cost)",
                len(message.content),
                _SMS_MAX_CHARS,
            )

        payload = {
            "ApiKey": self._api_key,
            "SecretKey": self._secret_key,
            "Phone": normalised,
            "Content": message.content,
            "SmsType": str(self._sms_type),
            "Brandname": self._brand_name,
        }

        try:
            async with httpx.AsyncClient(timeout=self._timeout_s) as client:
                response = await client.post(_ESMS_SEND_URL, json=payload)
                response.raise_for_status()
                data: dict = response.json()

            code_response = str(data.get("CodeResponse", ""))
            # eSMS success code is "100"
            if code_response == "100":
                sms_id = str(data.get("SMSID", ""))
                logger.info(
                    "[SMS ESMS] sent to=%s type=%s sms_id=%s",
                    normalised,
                    message.notification_type,
                    sms_id,
                )
                return SmsSendResult(
                    success=True,
                    external_message_id=sms_id,
                    normalised_phone=normalised,
                    provider="esms",
                )
            else:
                error_msg = f"eSMS error code={code_response} data={data}"
                logger.error("[SMS ESMS] FAILED to=%s %s", normalised, error_msg)
                return SmsSendResult(
                    success=False,
                    normalised_phone=normalised,
                    error=error_msg,
                    provider="esms",
                )

        except httpx.HTTPStatusError as exc:
            err = f"HTTP {exc.response.status_code}"
            logger.error("[SMS ESMS] HTTP error to=%s: %s", normalised, err)
            return SmsSendResult(
                success=False, normalised_phone=normalised, error=err, provider="esms"
            )
        except Exception as exc:  # noqa: BLE001 — must not propagate
            logger.error("[SMS ESMS] Unexpected error to=%s: %s", normalised, exc, exc_info=True)
            return SmsSendResult(
                success=False,
                normalised_phone=normalised,
                error=str(exc),
                provider="esms",
            )


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------


def build_sms_provider(provider_name: str, settings: object) -> SmsProvider:
    """Build an SmsProvider from config.

    Args:
        provider_name: "stub" | "esms"
        settings: app.config.Settings instance (or any object with ESMS_* attrs)

    Returns:
        SmsProvider implementation. Raises ValueError for unknown names.
    """
    if provider_name == "stub":
        return StubSmsProvider()
    if provider_name == "esms":
        api_key = getattr(settings, "esms_api_key", "") or ""
        secret_key = getattr(settings, "esms_secret_key", "") or ""
        if not api_key or not secret_key:
            raise ValueError(
                "eSMS provider requires ESMS_API_KEY and ESMS_SECRET_KEY to be configured."
            )
        return ESMSSmsProvider(api_key=api_key, secret_key=secret_key)
    raise ValueError(
        f"Unknown SMS provider: {provider_name!r}. "
        "Valid values: 'stub', 'esms'."
    )
