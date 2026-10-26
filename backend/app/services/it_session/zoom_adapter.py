"""Zoom adapter for IT重説 session creation.

Two implementations:
  ZoomMockAdapter  — local dev / CI (no HTTP calls, realistic payloads)
  ZoomClient       — real Zoom API (deferred to production readiness)

Factory: use get_zoom_adapter() which checks settings.use_mock_providers.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from app.config import settings

logger = logging.getLogger(__name__)


@dataclass
class ZoomMeeting:
    """Zoom meeting creation result."""
    meeting_id: str
    join_url: str
    host_url: str
    password: str


class ZoomMockAdapter:
    """Mock Zoom adapter — returns realistic fake meeting details."""

    async def create_meeting(
        self,
        topic: str,
        scheduled_at: datetime,
        duration_minutes: int = 60,
    ) -> ZoomMeeting:
        """Return a mock Zoom meeting without HTTP calls."""
        meeting_id = f"mock_{uuid.uuid4().int % 100_000_000_000:011d}"
        password = uuid.uuid4().hex[:6].upper()
        logger.info(
            "ZoomMock.create_meeting: topic='%s' scheduled=%s → meeting_id=%s",
            topic, scheduled_at.isoformat(), meeting_id,
        )
        return ZoomMeeting(
            meeting_id=meeting_id,
            join_url=f"https://zoom.us/j/{meeting_id}?pwd={password}",
            host_url=f"https://zoom.us/s/{meeting_id}",
            password=password,
        )


class ZoomClient:
    """Real Zoom API client (OAuth2 Server-to-Server).

    Credentials loaded from OrgProviderConfig (provider_type='conference', provider_name='zoom').
    Deferred: not implemented in P2 MVP — ZoomMockAdapter used for all envs.
    """

    def __init__(self, account_id: str, client_id: str, client_secret: str) -> None:
        self.account_id = account_id
        self.client_id = client_id
        self.client_secret = client_secret

    async def create_meeting(
        self,
        topic: str,
        scheduled_at: datetime,
        duration_minutes: int = 60,
    ) -> ZoomMeeting:
        raise NotImplementedError(
            "ZoomClient is deferred to P3 infrastructure work. "
            "Use ZoomMockAdapter (settings.use_mock_providers=True)."
        )


def get_zoom_adapter() -> ZoomMockAdapter | ZoomClient:
    """Return the appropriate Zoom adapter based on settings."""
    use_mock: bool = getattr(settings, "use_mock_providers", True)
    if use_mock:
        return ZoomMockAdapter()
    # Production: load creds from OrgProviderConfig (not implemented in P2)
    raise NotImplementedError(
        "Real Zoom adapter requires OrgProviderConfig(provider_type='conference'). "
        "Set use_mock_providers=True for development."
    )
