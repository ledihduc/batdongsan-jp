"""Unit tests — sms_service.py (StubProvider + ESMSProvider + normalisation + factory).

Tests cover:
- normalise_phone_e164: VN phone formats → E.164
- StubSmsProvider: success, logging, no HTTP
- ESMSSmsProvider: successful send, error codes, HTTP failures, phone validation
- build_sms_provider: correct type, ValueError for unknown
"""

from __future__ import annotations

import os
from unittest.mock import AsyncMock, MagicMock

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


from app.services.notification.sms_service import (
    ESMSSmsProvider,
    SmsMessage,
    SmsSendResult,
    StubSmsProvider,
    build_sms_provider,
    normalise_phone_e164,
)


# ---------------------------------------------------------------------------
# Phone normalisation
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "input_phone,expected",
    [
        ("0901234567", "+84901234567"),
        ("84901234567", "+84901234567"),
        ("+84901234567", "+84901234567"),
        ("0 901 234 567", "+84901234567"),
        ("0901-234-567", "+84901234567"),
    ],
)
def test_normalise_phone_happy_paths(input_phone: str, expected: str):
    assert normalise_phone_e164(input_phone) == expected


def test_normalise_phone_raises_on_invalid():
    with pytest.raises(ValueError, match="Cannot normalise phone"):
        normalise_phone_e164("12345")  # Only 5 digits after +84 prefix


# ---------------------------------------------------------------------------
# StubSmsProvider
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_stub_sms_provider_succeeds():
    provider = StubSmsProvider()
    msg = SmsMessage(
        to_phone="0901234567",
        content="[ancu365] Test SMS",
        notification_type="approval_reminder_24h",
    )
    result = await provider.send(msg)
    assert result.success is True
    assert result.provider == "stub"
    assert result.external_message_id is not None
    assert result.external_message_id.startswith("stub-sms-")
    assert result.normalised_phone == "+84901234567"


@pytest.mark.asyncio
async def test_stub_sms_provider_logs(mocker):
    # Use mocker to capture log calls, not caplog (avoids full-suite interference)
    mock_log = mocker.patch("app.services.notification.sms_service.logger")
    provider = StubSmsProvider()
    msg = SmsMessage(to_phone="0987654321", content="[ancu365] Test")
    await provider.send(msg)
    mock_log.info.assert_called_once()
    logged_msg = str(mock_log.info.call_args)
    assert "SMS STUB" in logged_msg


@pytest.mark.asyncio
async def test_stub_sms_provider_name():
    assert StubSmsProvider().provider_name == "stub"


@pytest.mark.asyncio
async def test_stub_sms_handles_invalid_phone_gracefully():
    """StubProvider must not raise even with malformed phone."""
    provider = StubSmsProvider()
    msg = SmsMessage(to_phone="INVALID", content="test")
    result = await provider.send(msg)
    # Success because stub doesn't validate phone (just logs as-is)
    assert result.success is True


# ---------------------------------------------------------------------------
# ESMSSmsProvider
# ---------------------------------------------------------------------------


def test_esms_provider_name():
    p = ESMSSmsProvider(api_key="key", secret_key="secret")
    assert p.provider_name == "esms"


def test_esms_provider_raises_without_credentials():
    with pytest.raises(ValueError, match="ESMS_API_KEY"):
        ESMSSmsProvider(api_key="", secret_key="")


@pytest.mark.asyncio
async def test_esms_provider_successful_send(mocker):
    """ESMSProvider sends correctly structured request and returns SMS ID."""
    mock_response = MagicMock()
    mock_response.json.return_value = {"CodeResponse": "100", "SMSID": "esms-999"}
    mock_response.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=None)
    mock_client.post = AsyncMock(return_value=mock_response)

    mocker.patch("httpx.AsyncClient", return_value=mock_client)

    provider = ESMSSmsProvider(api_key="test-api-key", secret_key="test-secret")
    msg = SmsMessage(
        to_phone="0901234567",
        content="[ancu365] Test notification",
        notification_type="approval_reminder_24h",
    )
    result = await provider.send(msg)

    assert result.success is True
    assert result.external_message_id == "esms-999"
    assert result.normalised_phone == "+84901234567"
    assert result.provider == "esms"

    # Verify correct payload structure
    call_kwargs = mock_client.post.call_args[1]
    payload = call_kwargs["json"]
    assert payload["ApiKey"] == "test-api-key"
    assert payload["Phone"] == "+84901234567"
    assert payload["Content"] == "[ancu365] Test notification"


@pytest.mark.asyncio
async def test_esms_provider_handles_vendor_error_code(mocker):
    """ESMSProvider returns success=False when CodeResponse != '100'."""
    mock_response = MagicMock()
    mock_response.json.return_value = {"CodeResponse": "104", "ErrorMessage": "Insufficient balance"}
    mock_response.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=None)
    mock_client.post = AsyncMock(return_value=mock_response)

    mocker.patch("httpx.AsyncClient", return_value=mock_client)

    provider = ESMSSmsProvider(api_key="key", secret_key="secret")
    msg = SmsMessage(to_phone="0901234567", content="test")
    result = await provider.send(msg)

    assert result.success is False
    assert "104" in (result.error or "")


@pytest.mark.asyncio
async def test_esms_provider_handles_http_error(mocker):
    """ESMSProvider returns success=False on HTTP errors."""
    import httpx

    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=None)

    mock_resp = MagicMock()
    mock_resp.status_code = 503
    mock_client.post = AsyncMock(
        side_effect=httpx.HTTPStatusError("Service unavailable", request=MagicMock(), response=mock_resp)
    )

    mocker.patch("httpx.AsyncClient", return_value=mock_client)

    provider = ESMSSmsProvider(api_key="key", secret_key="secret")
    msg = SmsMessage(to_phone="0901234567", content="test")
    result = await provider.send(msg)

    assert result.success is False
    assert "503" in (result.error or "")


@pytest.mark.asyncio
async def test_esms_provider_handles_invalid_phone():
    """ESMSProvider returns success=False for invalid phone, does not raise."""
    provider = ESMSSmsProvider(api_key="key", secret_key="secret")
    msg = SmsMessage(to_phone="123", content="test")
    result = await provider.send(msg)
    assert result.success is False
    assert result.error is not None


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------


def test_build_sms_provider_stub():
    provider = build_sms_provider("stub", object())
    assert isinstance(provider, StubSmsProvider)


def test_build_sms_provider_esms():
    class FakeSettings:
        esms_api_key = "api-key"
        esms_secret_key = "secret-key"

    provider = build_sms_provider("esms", FakeSettings())
    assert isinstance(provider, ESMSSmsProvider)


def test_build_sms_provider_raises_for_unknown():
    with pytest.raises(ValueError, match="Unknown SMS provider"):
        build_sms_provider("twilio", object())


def test_build_sms_provider_esms_requires_credentials():
    class EmptySettings:
        esms_api_key = ""
        esms_secret_key = ""

    with pytest.raises(ValueError, match="ESMS_API_KEY"):
        build_sms_provider("esms", EmptySettings())
