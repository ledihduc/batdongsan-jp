"""JP payment adapter contract — Protocol-based interface.

All JP payment providers (Komoju, Stripe JP, etc.) must implement JpPaymentAdapter.
Adapters are resolved per-org via provider_resolver.py.

Design decisions:
- Protocol (structural subtyping) over ABC — allows mock classes without inheritance.
- All methods are async to support httpx.AsyncClient in real implementations.
- Method signatures are minimal and stable — expansion via metadata dicts.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol, runtime_checkable


@dataclass
class PaymentIntentResult:
    """Result of create_payment_intent().

    Fields:
        provider_intent_id: Opaque provider ID for correlation.
        status: Initial status (always 'pending' on creation).
        metadata: Provider-specific extras (payment URL, instructions, etc.).
    """
    provider_intent_id: str
    status: str  # pending | processing | succeeded | failed | expired
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass
class KonbiniVoucher:
    """Konbini payment voucher details returned to the tenant.

    Fields:
        store_name: Convenience store chain (FamilyMart, Lawson, etc.).
        confirmation_number: Number tenant brings to the store.
        expiry_at: ISO8601 UTC string when voucher expires.
        instructions_url: Link to provider-hosted instructions page (optional).
    """
    store_name: str
    confirmation_number: str
    expiry_at: str
    instructions_url: str = ""


@dataclass
class WebhookEvent:
    """Normalised webhook event from any JP payment provider.

    Fields:
        provider: Source provider name.
        event_type: Provider event type string.
        external_event_id: Provider-assigned unique event ID (idempotency key).
        payload: Full raw payload dict for audit.
        intent_id: Correlated payment intent ID (provider-side).
        status: New payment status if applicable.
    """
    provider: str
    event_type: str
    external_event_id: str
    payload: dict[str, Any]
    intent_id: str = ""
    status: str = ""


@runtime_checkable
class JpPaymentAdapter(Protocol):
    """Contract all JP payment provider adapters must satisfy.

    Implementations:
      - KomojuMockClient (tests + local dev)
      - KomojuClient (production, reads creds from OrgProviderConfig)

    Usage:
      adapter = await resolve_payment_adapter(org_id, db)
      result  = await adapter.create_payment_intent(invoice_id, amount_jpy, "konbini")
    """

    async def create_payment_intent(
        self,
        invoice_id: str,
        amount_jpy: int,
        method: str,
    ) -> PaymentIntentResult:
        """Create a new payment intent at the provider.

        Args:
            invoice_id: Platform invoice UUID (stored in metadata for correlation).
            amount_jpy: Payment amount in JPY (integer yen, no decimals).
            method: 'card' | 'konbini' | 'bank_transfer'

        Returns:
            PaymentIntentResult with provider_intent_id and initial status.
        """
        ...

    async def issue_konbini_voucher(
        self,
        intent_id: str,
    ) -> KonbiniVoucher:
        """Issue a konbini payment voucher for an existing intent.

        Args:
            intent_id: Platform JpPaymentIntent.id (not provider_intent_id).

        Returns:
            KonbiniVoucher with store details and confirmation number.
        """
        ...

    async def verify_webhook(
        self,
        signature: str,
        body: bytes,
    ) -> WebhookEvent:
        """Verify HMAC signature and parse webhook payload.

        Args:
            signature: Provider-supplied signature header value.
            body: Raw request body bytes (before any parsing).

        Returns:
            WebhookEvent parsed from the verified body.

        Raises:
            ValueError: if HMAC verification fails.
        """
        ...
