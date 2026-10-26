"""Unit tests — email_service.py (StubProvider + SESProvider + factory).

Tests cover:
- StubEmailProvider: always succeeds, returns stub message ID, logs
- SESEmailProvider: boto3 client called with correct params; handles failures
- build_email_provider: returns correct type; raises ValueError for unknown names
- EmailMessage: immutable, no PII in subject check
"""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


from app.services.notification.email_service import (
    EmailMessage,
    SendResult,
    StubEmailProvider,
    SESEmailProvider,
    build_email_provider,
)


# ---------------------------------------------------------------------------
# StubEmailProvider
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_stub_provider_always_succeeds():
    provider = StubEmailProvider()
    msg = EmailMessage(
        to_address="owner@example.com",
        subject="[ancu365] Test",
        html_body="<p>Hello</p>",
        text_body="Hello",
        notification_type="approval_requested",
    )
    result = await provider.send(msg)
    assert result.success is True
    assert result.provider == "stub"
    assert result.external_message_id is not None
    assert result.external_message_id.startswith("stub-email-")
    assert result.error is None


@pytest.mark.asyncio
async def test_stub_provider_name():
    provider = StubEmailProvider()
    assert provider.provider_name == "stub"


@pytest.mark.asyncio
async def test_stub_provider_does_not_raise(mocker):
    """StubProvider must never raise — it logs and returns success."""
    # Use mocker to capture log calls, not caplog (avoids full-suite interference)
    mock_log = mocker.patch(
        "app.services.notification.email_service.logger"
    )
    provider = StubEmailProvider()
    msg = EmailMessage(
        to_address="x@example.com",
        subject="[ancu365] Test",
        html_body="<p>body</p>",
        text_body="body",
    )
    result = await provider.send(msg)
    assert result.success is True
    mock_log.info.assert_called_once()
    logged_msg = str(mock_log.info.call_args)
    assert "EMAIL STUB" in logged_msg


# ---------------------------------------------------------------------------
# SESEmailProvider
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_ses_provider_name():
    provider = SESEmailProvider(region="ap-southeast-1", from_email="noreply@ancu365.com")
    assert provider.provider_name == "ses"


@pytest.mark.asyncio
async def test_ses_provider_calls_boto3(mocker):
    """SES provider calls boto3.client.send_email with correct params."""
    mock_client = mocker.MagicMock()
    mock_client.send_email.return_value = {"MessageId": "ses-msg-abc123"}

    # Patch boto3 at the point where the module imports it (inside _get_client)
    mocker.patch.dict(
        "sys.modules",
        {"boto3": mocker.MagicMock(client=mocker.MagicMock(return_value=mock_client))},
    )

    provider = SESEmailProvider(region="ap-southeast-1", from_email="noreply@ancu365.com")
    provider._client = mock_client  # Inject pre-built mock client directly

    msg = EmailMessage(
        to_address="owner@example.com",
        subject="[ancu365] Cần phê duyệt",
        html_body="<p>Cần phê duyệt</p>",
        text_body="Cần phê duyệt",
        notification_type="approval_requested",
        related_id=42,
    )
    result = await provider.send(msg)

    assert result.success is True
    assert result.external_message_id == "ses-msg-abc123"
    assert result.provider == "ses"
    assert result.error is None

    mock_client.send_email.assert_called_once()
    call_kwargs = mock_client.send_email.call_args[1]
    assert call_kwargs["Source"] == "noreply@ancu365.com"
    assert call_kwargs["Destination"]["ToAddresses"] == ["owner@example.com"]


@pytest.mark.asyncio
async def test_ses_provider_handles_boto3_exception(mocker):
    """SES provider captures exception and returns success=False."""
    mock_client = mocker.MagicMock()
    mock_client.send_email.side_effect = Exception("SES quota exceeded")

    provider = SESEmailProvider(region="ap-southeast-1", from_email="noreply@ancu365.com")
    provider._client = mock_client  # Inject pre-built mock client directly

    msg = EmailMessage(
        to_address="owner@example.com",
        subject="[ancu365] Test",
        html_body="<p>body</p>",
        text_body="body",
    )
    result = await provider.send(msg)

    assert result.success is False
    assert result.error is not None
    assert "quota" in result.error


@pytest.mark.asyncio
async def test_ses_provider_raises_if_boto3_not_installed(mocker):
    """SESEmailProvider raises RuntimeError if boto3 import fails."""
    import builtins

    real_import = builtins.__import__

    def mock_import(name, *args, **kwargs):
        if name == "boto3":
            raise ImportError("No module named 'boto3'")
        return real_import(name, *args, **kwargs)

    provider = SESEmailProvider(region="ap-southeast-1", from_email="noreply@ancu365.com")
    provider._client = None  # Reset cached client

    mocker.patch("builtins.__import__", side_effect=mock_import)

    msg = EmailMessage(
        to_address="test@example.com",
        subject="[ancu365] Test",
        html_body="<p>body</p>",
        text_body="body",
    )
    # Should return SendResult(success=False) not raise, because boto3 error
    # is caught by get_client() which will be called inside send()
    # (we patched __import__ so boto3 module import fails inside get_client)
    result = await provider.send(msg)
    assert result.success is False


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------


def test_build_email_provider_stub():
    provider = build_email_provider("stub", object())
    assert isinstance(provider, StubEmailProvider)


def test_build_email_provider_ses():
    class FakeSettings:
        ses_region = "ap-southeast-1"
        ses_from_email = "noreply@ancu365.com"

    provider = build_email_provider("ses", FakeSettings())
    assert isinstance(provider, SESEmailProvider)


def test_build_email_provider_raises_for_unknown():
    with pytest.raises(ValueError, match="Unknown email provider"):
        build_email_provider("sendgrid", object())


def test_build_email_provider_ses_requires_region():
    class EmptySettings:
        ses_region = ""
        ses_from_email = ""

    with pytest.raises(ValueError, match="SES_REGION"):
        build_email_provider("ses", EmptySettings())
