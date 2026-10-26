"""CloudSign eContract adapter — implements create, send, and webhook handling.

Two implementations:
  CloudSignMockAdapter — local dev / CI (realistic static payloads)
  CloudSignClient      — real CloudSign API (deferred to production readiness)

CloudSign webhook HMAC: X-CS-Signature header = HMAC-SHA256(secret, body).

Webhook idempotency is handled at the route layer (jp_webhook_events table).
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import uuid
from dataclasses import dataclass
from typing import Any

from app.config import settings

logger = logging.getLogger(__name__)


@dataclass
class CloudSignDocument:
    """Result of document creation."""
    remote_doc_id: str
    status: str  # draft | sent


@dataclass
class CloudSignWebhookEvent:
    """Parsed CloudSign webhook event."""
    event_type: str        # e.g. 'document.signed'
    external_event_id: str
    remote_doc_id: str
    status: str            # New document status
    signed_pdf_url: str    # Populated on 'document.signed'
    payload: dict[str, Any]


class CloudSignMockAdapter:
    """Mock CloudSign adapter for local dev and CI."""

    async def create_document(
        self,
        application_id: int,
        template_version: str = "1.0",
    ) -> CloudSignDocument:
        """Return a mock document ID without API call."""
        mock_id = f"cs_doc_{uuid.uuid4().hex[:12]}"
        logger.info(
            "CloudSignMock.create_document: application=%d → doc_id=%s",
            application_id, mock_id,
        )
        return CloudSignDocument(remote_doc_id=mock_id, status="draft")

    async def send_for_signing(
        self, remote_doc_id: str
    ) -> CloudSignDocument:
        """Mock sending document for tenant signature."""
        logger.info("CloudSignMock.send_for_signing: doc_id=%s", remote_doc_id)
        return CloudSignDocument(remote_doc_id=remote_doc_id, status="sent")

    async def handle_webhook(
        self,
        signature: str,
        body: bytes,
    ) -> CloudSignWebhookEvent:
        """Parse mock CloudSign webhook — no HMAC check in mock mode."""
        try:
            payload: dict[str, Any] = json.loads(body)
        except json.JSONDecodeError as exc:
            raise ValueError(f"CloudSign webhook body is not valid JSON: {exc}") from exc

        remote_doc_id = payload.get("document", {}).get("id", f"cs_doc_mock_{uuid.uuid4().hex[:8]}")
        event_type = payload.get("event", "document.signed")
        return CloudSignWebhookEvent(
            event_type=event_type,
            external_event_id=payload.get("id", f"cs_evt_{uuid.uuid4().hex}"),
            remote_doc_id=remote_doc_id,
            status=payload.get("document", {}).get("status", "signed"),
            signed_pdf_url=payload.get("document", {}).get("download_url", ""),
            payload=payload,
        )


class CloudSignClient:
    """Real CloudSign API client (deferred to production readiness).

    API base: https://api.cloudsign.jp/api/documents
    Auth: Bearer token from OrgProviderConfig (provider_type='esign', provider_name='cloudsign').
    """

    def __init__(self, api_token: str, webhook_secret: str) -> None:
        self.api_token = api_token
        self.webhook_secret = webhook_secret

    async def create_document(
        self,
        application_id: int,
        template_version: str = "1.0",
    ) -> CloudSignDocument:
        raise NotImplementedError(
            "CloudSignClient deferred to P3 infrastructure. Use mock adapter."
        )

    async def send_for_signing(self, remote_doc_id: str) -> CloudSignDocument:
        raise NotImplementedError("CloudSignClient deferred to P3.")

    async def handle_webhook(
        self, signature: str, body: bytes
    ) -> CloudSignWebhookEvent:
        """Verify HMAC-SHA256 and parse webhook. Raises ValueError on failure."""
        expected = hmac.new(
            self.webhook_secret.encode("utf-8"),
            body,
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(signature, expected):
            raise ValueError("CloudSign webhook HMAC signature mismatch")

        payload: dict[str, Any] = json.loads(body)
        remote_doc_id = payload.get("document", {}).get("id", "")
        return CloudSignWebhookEvent(
            event_type=payload.get("event", ""),
            external_event_id=payload.get("id", ""),
            remote_doc_id=remote_doc_id,
            status=payload.get("document", {}).get("status", ""),
            signed_pdf_url=payload.get("document", {}).get("download_url", ""),
            payload=payload,
        )


def get_cloudsign_adapter() -> CloudSignMockAdapter | CloudSignClient:
    """Return CloudSign adapter based on settings.use_mock_providers."""
    use_mock: bool = getattr(settings, "use_mock_providers", True)
    if use_mock:
        return CloudSignMockAdapter()
    raise NotImplementedError(
        "Real CloudSign adapter requires OrgProviderConfig(provider_type='esign'). "
        "Set use_mock_providers=True for development."
    )
