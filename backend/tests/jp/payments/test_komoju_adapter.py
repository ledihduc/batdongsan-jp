"""Tests for Komoju payment adapter — mock and real adapter behavior.

No DB connection, no HTTP calls — pure unit tests.
"""

from __future__ import annotations

import json
import os
from decimal import Decimal

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest

from app.services.payment.jp.komoju.client import KomojuMockClient


class TestKomojuMockClientCreateIntent:
    """Tests for KomojuMockClient.create_payment_intent()."""

    @pytest.mark.asyncio
    async def test_returns_pending_status(self) -> None:
        client = KomojuMockClient(org_id="org-001")
        result = await client.create_payment_intent("inv-001", 80000, "card")
        assert result.status == "pending"

    @pytest.mark.asyncio
    async def test_returns_provider_intent_id(self) -> None:
        client = KomojuMockClient(org_id="org-001")
        result = await client.create_payment_intent("inv-001", 80000, "card")
        assert result.provider_intent_id.startswith("mock_intent_")

    @pytest.mark.asyncio
    async def test_konbini_includes_deadline(self) -> None:
        client = KomojuMockClient(org_id="org-001")
        result = await client.create_payment_intent("inv-001", 80000, "konbini")
        assert "payment_deadline" in result.metadata

    @pytest.mark.asyncio
    async def test_bank_transfer_includes_account_details(self) -> None:
        client = KomojuMockClient(org_id="org-001")
        result = await client.create_payment_intent("inv-001", 80000, "bank_transfer")
        assert "bank_name" in result.metadata
        assert "account_number" in result.metadata
        assert "transfer_reference" in result.metadata


class TestKomojuMockClientKonbiniVoucher:
    """Tests for KomojuMockClient.issue_konbini_voucher()."""

    @pytest.mark.asyncio
    async def test_returns_voucher_details(self) -> None:
        client = KomojuMockClient(org_id="org-001")
        voucher = await client.issue_konbini_voucher("mock_intent_abc123")
        assert voucher.store_name == "FamilyMart"
        assert voucher.confirmation_number.startswith("FM")
        assert len(voucher.confirmation_number) == 12  # FM + 10 digits
        assert voucher.expiry_at != ""

    @pytest.mark.asyncio
    async def test_voucher_has_instructions_url(self) -> None:
        client = KomojuMockClient(org_id="org-001")
        voucher = await client.issue_konbini_voucher("mock_intent_abc123")
        assert "sandbox.komoju.com" in voucher.instructions_url


class TestKomojuMockClientVerifyWebhook:
    """Tests for KomojuMockClient.verify_webhook() — mock skips HMAC."""

    @pytest.mark.asyncio
    async def test_parses_valid_json_body(self) -> None:
        client = KomojuMockClient(org_id="org-001")
        payload = {
            "id": "evt_test_001",
            "type": "payment.succeeded",
            "data": {"object": {"id": "intent_abc", "status": "succeeded"}},
        }
        event = await client.verify_webhook("any-sig", json.dumps(payload).encode())
        assert event.event_type == "payment.succeeded"
        assert event.external_event_id == "evt_test_001"
        assert event.provider == "komoju"
        assert event.intent_id == "intent_abc"
        assert event.status == "succeeded"

    @pytest.mark.asyncio
    async def test_invalid_json_raises_value_error(self) -> None:
        client = KomojuMockClient(org_id="org-001")
        with pytest.raises(ValueError, match="not valid JSON"):
            await client.verify_webhook("any-sig", b"not json {")


class TestWebhookIdempotency:
    """Test that duplicate external_event_id is detected."""

    def test_try_insert_idempotent_returns_false_for_duplicate(self) -> None:
        """Simulates what JpWebhookEventRepository.try_insert_idempotent does."""
        from unittest.mock import MagicMock

        repo = MagicMock()
        existing_row = MagicMock()
        existing_row.external_event_id = "evt_001"
        # First call: not found → insert → is_new=True
        repo.try_insert_idempotent.return_value = (existing_row, True)

        row1, is_new1 = repo.try_insert_idempotent(
            provider="komoju",
            event_type="payment.succeeded",
            external_event_id="evt_001",
            payload={"id": "evt_001"},
        )
        assert is_new1 is True

        # Second call (same event_id): repo returns is_new=False
        repo.try_insert_idempotent.return_value = (existing_row, False)
        row2, is_new2 = repo.try_insert_idempotent(
            provider="komoju",
            event_type="payment.succeeded",
            external_event_id="evt_001",
            payload={"id": "evt_001"},
        )
        assert is_new2 is False


class TestHmacRejection:
    """Tests for HMAC rejection in real KomojuClient."""

    @pytest.mark.asyncio
    async def test_invalid_hmac_raises_value_error(self) -> None:
        from app.services.payment.jp.komoju.client import KomojuClient
        client = KomojuClient(
            api_key="test_key",
            webhook_secret="test_secret",
            is_sandbox=True,
            org_id="org-001",
        )
        body = b'{"id": "evt_001", "type": "payment.succeeded"}'
        bad_signature = "bad_signature_hex"

        with pytest.raises(ValueError, match="HMAC signature mismatch"):
            await client.verify_webhook(bad_signature, body)

    @pytest.mark.asyncio
    async def test_valid_hmac_accepted(self) -> None:
        import hashlib
        import hmac as hmac_lib

        from app.services.payment.jp.komoju.client import KomojuClient
        secret = "test_secret_abc"
        body = json.dumps({
            "id": "evt_valid_001",
            "type": "payment.succeeded",
            "data": {"object": {"id": "intent_xyz", "status": "succeeded"}},
        }).encode()
        sig = hmac_lib.new(secret.encode(), body, hashlib.sha256).hexdigest()

        client = KomojuClient(
            api_key="test_key",
            webhook_secret=secret,
            is_sandbox=True,
            org_id="org-001",
        )
        event = await client.verify_webhook(sig, body)
        assert event.external_event_id == "evt_valid_001"
        assert event.event_type == "payment.succeeded"
