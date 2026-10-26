"""Komoju payment adapter — implements JpPaymentAdapter.

Two implementations in this file:
  KomojuMockClient  — returned when settings.use_mock_providers=True (local dev / CI).
                      All HTTP calls are replaced with realistic static payloads.
  KomojuClient      — real httpx calls to https://komoju.com/api/v1/.
                      Credentials loaded from OrgProviderConfig via decrypt_config().

Factory: use app.services.payment.jp.provider_resolver.resolve_payment_adapter()
         rather than importing these classes directly.

HMAC signature verification:
  Komoju sends 'X-Komoju-Signature' header = HMAC-SHA256(secret, body).
  Secret = config['webhook_secret'] from OrgProviderConfig.

Sandbox parity note:
  Komoju sandbox mirrors production API exactly. The only difference is the
  base URL (https://sandbox.komoju.com vs https://komoju.com). The is_sandbox
  flag on OrgProviderConfig controls which base URL is used.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from app.config import settings
from app.services.payment.jp.base import (
    JpPaymentAdapter,
    KonbiniVoucher,
    PaymentIntentResult,
    WebhookEvent,
)

logger = logging.getLogger(__name__)

_KOMOJU_PROD_URL = "https://komoju.com/api/v1"
_KOMOJU_SANDBOX_URL = "https://sandbox.komoju.com/api/v1"


# ---------------------------------------------------------------------------
# Mock client — used when settings.use_mock_providers is True
# ---------------------------------------------------------------------------

class KomojuMockClient:
    """Mock Komoju adapter for local development and CI.

    Returns realistic static payloads without making HTTP calls.
    All methods are async to match the JpPaymentAdapter protocol.
    """

    def __init__(self, org_id: str, is_sandbox: bool = True) -> None:
        self.org_id = org_id
        self.is_sandbox = is_sandbox
        logger.info(
            "KomojuMockClient initialised for org=%s sandbox=%s",
            org_id, is_sandbox,
        )

    async def create_payment_intent(
        self,
        invoice_id: str,
        amount_jpy: int,
        method: str,
    ) -> PaymentIntentResult:
        """Return a mock payment intent (no HTTP call)."""
        mock_intent_id = f"mock_intent_{uuid.uuid4().hex[:12]}"
        logger.debug(
            "KomojuMock.create_payment_intent invoice=%s amount=%d method=%s → %s",
            invoice_id, amount_jpy, method, mock_intent_id,
        )
        metadata: dict[str, Any] = {
            "mock": True,
            "method": method,
            "invoice_id": invoice_id,
        }
        if method == "konbini":
            metadata["payment_deadline"] = (
                datetime.now(timezone.utc) + timedelta(days=3)
            ).isoformat()
        elif method == "bank_transfer":
            metadata["bank_name"] = "三菱UFJ銀行"
            metadata["branch_name"] = "東京支店"
            metadata["account_number"] = "1234567"
            metadata["transfer_reference"] = f"ANCU{uuid.uuid4().hex[:8].upper()}"

        return PaymentIntentResult(
            provider_intent_id=mock_intent_id,
            status="pending",
            metadata=metadata,
        )

    async def issue_konbini_voucher(
        self,
        intent_id: str,
    ) -> KonbiniVoucher:
        """Return a mock konbini voucher."""
        expiry = (datetime.now(timezone.utc) + timedelta(days=3)).isoformat()
        logger.debug("KomojuMock.issue_konbini_voucher intent=%s", intent_id)
        return KonbiniVoucher(
            store_name="FamilyMart",
            confirmation_number=f"FM{uuid.uuid4().int % 10_000_000_000:010d}",
            expiry_at=expiry,
            instructions_url="https://sandbox.komoju.com/mock/konbini-instructions",
        )

    async def verify_webhook(
        self,
        signature: str,
        body: bytes,
    ) -> WebhookEvent:
        """Parse mock webhook — accepts any body, no HMAC check in mock mode."""
        logger.debug("KomojuMock.verify_webhook (mock — no HMAC check)")
        try:
            payload: dict[str, Any] = json.loads(body)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Webhook body is not valid JSON: {exc}") from exc

        return WebhookEvent(
            provider="komoju",
            event_type=payload.get("type", "mock.event"),
            external_event_id=payload.get("id", f"mock_{uuid.uuid4().hex}"),
            payload=payload,
            intent_id=str(payload.get("data", {}).get("object", {}).get("id", "")),
            status=str(payload.get("data", {}).get("object", {}).get("status", "pending")),
        )


# ---------------------------------------------------------------------------
# Real client — wraps httpx.AsyncClient (used in production)
# ---------------------------------------------------------------------------

class KomojuClient:
    """Real Komoju adapter using httpx.AsyncClient.

    Credentials are passed at construction time (resolved from OrgProviderConfig).
    Never instantiate directly — use provider_resolver.resolve_payment_adapter().
    """

    def __init__(
        self,
        api_key: str,
        webhook_secret: str,
        is_sandbox: bool,
        org_id: str,
    ) -> None:
        self.api_key = api_key
        self.webhook_secret = webhook_secret
        self.base_url = _KOMOJU_SANDBOX_URL if is_sandbox else _KOMOJU_PROD_URL
        self.org_id = org_id

    def _get_client(self):  # type: ignore[return]
        """Import httpx lazily to keep mock path dependency-free."""
        try:
            import httpx
            return httpx.AsyncClient(
                base_url=self.base_url,
                auth=(self.api_key, ""),
                headers={"Content-Type": "application/json"},
                timeout=30.0,
            )
        except ImportError as exc:
            raise RuntimeError("httpx must be installed for real Komoju calls") from exc

    async def create_payment_intent(
        self,
        invoice_id: str,
        amount_jpy: int,
        method: str,
    ) -> PaymentIntentResult:
        """POST /sessions to Komoju API."""
        payload = {
            "amount": amount_jpy,
            "currency": "JPY",
            "payment_types": [method],
            "metadata": {"invoice_id": invoice_id, "org_id": self.org_id},
        }
        async with self._get_client() as client:
            resp = await client.post("/sessions", json=payload)
            resp.raise_for_status()
            data = resp.json()

        return PaymentIntentResult(
            provider_intent_id=data["id"],
            status=data.get("status", "pending"),
            metadata=data,
        )

    async def issue_konbini_voucher(
        self,
        intent_id: str,
    ) -> KonbiniVoucher:
        """GET /sessions/{session_id} and extract konbini voucher details."""
        # intent_id here is provider_intent_id stored in JpPaymentIntent
        async with self._get_client() as client:
            resp = await client.get(f"/sessions/{intent_id}")
            resp.raise_for_status()
            data = resp.json()

        payment = data.get("payment") or {}
        konbini = payment.get("payment_details") or {}
        return KonbiniVoucher(
            store_name=konbini.get("store", "コンビニ"),
            confirmation_number=konbini.get("confirmation_code", ""),
            expiry_at=konbini.get("expires_at", ""),
            instructions_url=konbini.get("instructions_url", ""),
        )

    async def verify_webhook(
        self,
        signature: str,
        body: bytes,
    ) -> WebhookEvent:
        """Verify HMAC-SHA256 signature and parse Komoju webhook payload.

        Raises ValueError on signature mismatch.
        """
        expected = hmac.new(
            self.webhook_secret.encode("utf-8"),
            body,
            hashlib.sha256,
        ).hexdigest()

        if not hmac.compare_digest(signature, expected):
            raise ValueError("Komoju webhook HMAC signature mismatch")

        payload: dict[str, Any] = json.loads(body)
        obj = payload.get("data", {}).get("object", {})
        return WebhookEvent(
            provider="komoju",
            event_type=payload.get("type", ""),
            external_event_id=payload.get("id", ""),
            payload=payload,
            intent_id=str(obj.get("id", "")),
            status=str(obj.get("status", "")),
        )
