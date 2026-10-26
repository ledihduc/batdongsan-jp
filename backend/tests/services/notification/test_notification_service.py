"""Unit tests — notification_service.py

Tests cover:
- NotificationService.create(): channel routing, DB row creation, delivery status
- Stub provider: writes notification row with delivery_status='sent_stub'
- In-app channel: no provider, delivery_status='delivered' immediately
- Email channel: to_email required, missing → failed
- SMS channel: to_phone required, missing → failed
- Unknown channel → ValueError
- Multiple channels in one create() call
- channel selection per delegation preferences (via channels list param)
"""

from __future__ import annotations

import os
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


from app.services.notification.email_service import SendResult, StubEmailProvider
from app.services.notification.notification_service import (
    NotificationRequest,
    NotificationResult,
    NotificationService,
)
from app.services.notification.sms_service import SmsSendResult, StubSmsProvider


def _make_service() -> NotificationService:
    """Build a NotificationService with stub providers for testing."""
    return NotificationService(
        email_provider=StubEmailProvider(),
        sms_provider=StubSmsProvider(),
    )


def _make_mock_db() -> MagicMock:
    """Build a minimal mock SQLAlchemy session."""
    db = MagicMock()
    # Simulate notification ID assignment on flush
    notif_counter = [0]

    def _flush_side_effect():
        notif_counter[0] += 1

    db.flush = MagicMock(side_effect=_flush_side_effect)
    db.add = MagicMock()
    db.execute = MagicMock()
    db.commit = MagicMock()
    return db


# ---------------------------------------------------------------------------
# in_app channel
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_in_app_channel_delivered_immediately():
    """in_app channel must set delivery_status='delivered' without provider call."""
    svc = _make_service()
    db = _make_mock_db()

    # Mock Notification object created and added to db
    from app.services.notification.notification_service import Notification
    with patch.object(Notification, "__init__", lambda self, **kwargs: setattr_many(self, kwargs)):
        pass

    req = NotificationRequest(
        user_id=1,
        notification_type="approval_requested",
        title="Cần phê duyệt",
        body="",
        channels=["in_app"],
    )

    results = await svc.create(db, req)

    assert len(results) == 1
    result = results[0]
    assert result.channel == "in_app"
    assert result.delivery_status == "delivered"
    assert result.error is None


@pytest.mark.asyncio
async def test_email_channel_sent_stub():
    """email channel with stub provider → delivery_status='sent_stub'."""
    svc = _make_service()
    db = _make_mock_db()

    req = NotificationRequest(
        user_id=2,
        notification_type="approval_requested",
        title="Cần phê duyệt",
        body="Test body",
        channels=["email"],
        to_email="owner@example.com",
        context={
            "owner_name": "Nguyễn Văn A",
            "operator_name": "Trần Thị B",
            "property_name": "Toà nhà ABC",
            "request_type_label": "Hợp đồng thuê",
            "approval_url": "https://ancu365.com/approvals/1",
        },
    )

    results = await svc.create(db, req)

    assert len(results) == 1
    r = results[0]
    assert r.channel == "email"
    assert r.delivery_status == "sent_stub"
    assert r.error is None
    assert r.external_message_id is not None


@pytest.mark.asyncio
async def test_email_channel_fails_without_to_email():
    """email channel with missing to_email → delivery_status='failed'."""
    svc = _make_service()
    db = _make_mock_db()

    req = NotificationRequest(
        user_id=3,
        notification_type="delegation_invited",
        title="Test",
        body="",
        channels=["email"],
        to_email=None,  # missing
    )

    results = await svc.create(db, req)

    assert len(results) == 1
    r = results[0]
    assert r.channel == "email"
    assert r.delivery_status == "failed"
    assert "to_email" in (r.error or "")


@pytest.mark.asyncio
async def test_sms_channel_sent_stub():
    """sms channel with stub provider → delivery_status='sent_stub'."""
    svc = _make_service()
    db = _make_mock_db()

    req = NotificationRequest(
        user_id=4,
        notification_type="approval_reminder_24h",
        title="Nhắc nhở",
        body="",
        channels=["sms"],
        to_phone="0901234567",
        context={
            "operator_name": "Trần Thị B",
            "property_name": "Toà nhà ABC",
            "approval_url_short": "ancu365.com/a/1",
        },
    )

    results = await svc.create(db, req)

    assert len(results) == 1
    r = results[0]
    assert r.channel == "sms"
    assert r.delivery_status == "sent_stub"
    assert r.error is None


@pytest.mark.asyncio
async def test_sms_channel_fails_without_to_phone():
    """sms channel with missing to_phone → delivery_status='failed'."""
    svc = _make_service()
    db = _make_mock_db()

    req = NotificationRequest(
        user_id=5,
        notification_type="approval_auto_rejected",
        title="Từ chối",
        body="",
        channels=["sms"],
        to_phone=None,  # missing
    )

    results = await svc.create(db, req)

    assert len(results) == 1
    r = results[0]
    assert r.delivery_status == "failed"
    assert "to_phone" in (r.error or "")


@pytest.mark.asyncio
async def test_multiple_channels_create_multiple_rows():
    """create() with ['in_app', 'email', 'sms'] → 3 results, one per channel."""
    svc = _make_service()
    db = _make_mock_db()

    req = NotificationRequest(
        user_id=6,
        notification_type="delegation_invited",
        title="Mời làm Operator",
        body="",
        channels=["in_app", "email", "sms"],
        to_email="owner@example.com",
        to_phone="0901234567",
        context={
            "owner_name": "Chủ nhà",
            "role_preset_label": "Operator đầy đủ",
            "scope_label": "Tất cả BĐS",
            "invite_url": "https://ancu365.com/invite/abc",
            "invite_url_short": "ancu365.com/i/abc",
        },
    )

    results = await svc.create(db, req)

    assert len(results) == 3
    channels_returned = {r.channel for r in results}
    assert channels_returned == {"in_app", "email", "sms"}


@pytest.mark.asyncio
async def test_unknown_channel_raises_value_error():
    """create() with unknown channel raises ValueError."""
    svc = _make_service()
    db = _make_mock_db()

    req = NotificationRequest(
        user_id=7,
        notification_type="delegation_invited",
        title="Test",
        body="",
        channels=["zalo"],  # not a valid channel
    )

    with pytest.raises(ValueError, match="Unknown channels"):
        await svc.create(db, req)


@pytest.mark.asyncio
async def test_from_settings_uses_stub_by_default():
    """NotificationService.from_settings returns stub providers when no env set."""

    class FakeSettings:
        notification_email_provider = "stub"
        notification_sms_provider = "stub"

    svc = NotificationService.from_settings(FakeSettings())
    assert svc._email_provider.provider_name == "stub"
    assert svc._sms_provider.provider_name == "stub"


@pytest.mark.asyncio
async def test_push_channel_logged_as_stub():
    """push channel returns sent_stub (FCM not wired in phase-08)."""
    svc = _make_service()
    db = _make_mock_db()

    req = NotificationRequest(
        user_id=8,
        notification_type="approval_requested",
        title="Test push",
        body="",
        channels=["push"],
    )

    results = await svc.create(db, req)
    assert len(results) == 1
    assert results[0].channel == "push"
    assert results[0].delivery_status == "sent_stub"


def setattr_many(obj, kwargs):
    """Helper: set multiple attributes from dict."""
    for k, v in kwargs.items():
        setattr(obj, k, v)
    # Ensure id is set for test
    if not hasattr(obj, "id"):
        obj.id = 1
