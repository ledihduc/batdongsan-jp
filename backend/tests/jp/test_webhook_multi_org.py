"""Tests for multi-org webhook HMAC resolver.

Tests HMAC verification logic using pure function approach.
DB lookups are mocked.
"""

from __future__ import annotations

import hashlib
import hmac
import json
from unittest.mock import MagicMock, patch

import pytest


def _make_komoju_body(account_id: str = "acct-123") -> bytes:
    """Create a mock Komoju webhook payload."""
    payload = {
        "account_id": account_id,
        "type": "payment.succeeded",
        "data": {"object": {"id": "ch-xxx", "metadata": {"org_id": "org-abc"}}},
    }
    return json.dumps(payload).encode("utf-8")


def _make_signature(body: bytes, secret: str) -> str:
    """Compute HMAC-SHA256 signature as hex string."""
    return hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()


class TestHmacVerification:
    """Tests for _verify_hmac_sha256()."""

    def test_valid_signature_returns_true(self):
        from app.services.webhook.hmac_resolver import _verify_hmac_sha256

        body = b'{"test": "payload"}'
        secret = "my-webhook-secret"
        sig = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()

        assert _verify_hmac_sha256(body=body, secret=secret, signature=sig) is True

    def test_prefixed_sha256_format_accepted(self):
        from app.services.webhook.hmac_resolver import _verify_hmac_sha256

        body = b'{"test": "payload"}'
        secret = "my-webhook-secret"
        sig = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()

        assert _verify_hmac_sha256(body=body, secret=secret, signature=sig) is True

    def test_wrong_secret_returns_false(self):
        from app.services.webhook.hmac_resolver import _verify_hmac_sha256

        body = b'{"test": "payload"}'
        sig = hmac.new(b"correct-secret", body, hashlib.sha256).hexdigest()

        assert _verify_hmac_sha256(body=body, secret="wrong-secret", signature=sig) is False

    def test_tampered_body_returns_false(self):
        from app.services.webhook.hmac_resolver import _verify_hmac_sha256

        original_body = b'{"amount": 1000}'
        tampered_body = b'{"amount": 9999}'
        secret = "webhook-secret"
        sig = hmac.new(secret.encode(), original_body, hashlib.sha256).hexdigest()

        assert _verify_hmac_sha256(body=tampered_body, secret=secret, signature=sig) is False

    def test_empty_signature_returns_false(self):
        from app.services.webhook.hmac_resolver import _verify_hmac_sha256

        body = b'{"test": "data"}'
        assert _verify_hmac_sha256(body=body, secret="secret", signature="") is False


class TestExtractKomojuAccountId:
    """Tests for _extract_komoju_account_id()."""

    def test_extracts_top_level_account_id(self):
        from app.services.webhook.hmac_resolver import _extract_komoju_account_id

        body = json.dumps({"account_id": "komoju-acct-999"}).encode()
        result = _extract_komoju_account_id(body)
        assert result == "komoju-acct-999"

    def test_extracts_metadata_org_id_as_fallback(self):
        from app.services.webhook.hmac_resolver import _extract_komoju_account_id

        body = json.dumps({
            "data": {"object": {"metadata": {"org_id": "org-from-meta"}}}
        }).encode()
        result = _extract_komoju_account_id(body)
        assert result == "org-from-meta"

    def test_returns_none_on_invalid_json(self):
        from app.services.webhook.hmac_resolver import _extract_komoju_account_id

        result = _extract_komoju_account_id(b"not-json")
        assert result is None

    def test_returns_none_when_no_account_id(self):
        from app.services.webhook.hmac_resolver import _extract_komoju_account_id

        body = json.dumps({"type": "payment.failed"}).encode()
        result = _extract_komoju_account_id(body)
        assert result is None


class TestExtractCloudsignAccountId:
    """Tests for _extract_cloudsign_account_id()."""

    def test_extracts_header(self):
        from app.services.webhook.hmac_resolver import _extract_cloudsign_account_id

        headers = {"x-cloudsign-account": "cs-account-abc"}
        result = _extract_cloudsign_account_id(headers)
        assert result == "cs-account-abc"

    def test_returns_none_when_header_absent(self):
        from app.services.webhook.hmac_resolver import _extract_cloudsign_account_id

        result = _extract_cloudsign_account_id({})
        assert result is None


class TestResolveKomoju:
    """Integration tests for resolve() with Komoju provider."""

    def test_resolve_raises_when_no_account_id(self):
        from app.services.webhook.hmac_resolver import resolve

        body = json.dumps({"type": "payment.failed"}).encode()  # no account_id
        db = MagicMock()

        with pytest.raises(ValueError, match="Cannot extract Komoju account_id"):
            resolve(
                provider="komoju",
                headers={},
                body=body,
                db=db,
                signature="deadbeef",
            )

    def test_resolve_raises_on_unknown_org(self):
        from app.services.webhook.hmac_resolver import resolve

        body = _make_komoju_body("unknown-acct")
        db = MagicMock()

        with patch("app.services.webhook.hmac_resolver._lookup_org_secret") as mock_lookup:
            mock_lookup.side_effect = ValueError("No org config found")

            with pytest.raises(ValueError):
                resolve(
                    provider="komoju",
                    headers={},
                    body=body,
                    db=db,
                    signature="deadbeef",
                )

    def test_resolve_raises_on_hmac_failure(self):
        from app.services.webhook.hmac_resolver import resolve

        body = _make_komoju_body("acct-123")
        secret = "real-secret"
        wrong_sig = "00000000deadbeef"

        db = MagicMock()

        with patch("app.services.webhook.hmac_resolver._lookup_org_secret") as mock_lookup:
            mock_lookup.return_value = ("org-abc", secret)

            with pytest.raises(ValueError, match="HMAC verification failed"):
                resolve(
                    provider="komoju",
                    headers={},
                    body=body,
                    db=db,
                    signature=wrong_sig,
                )

    def test_resolve_returns_result_on_valid_hmac(self):
        from app.services.webhook.hmac_resolver import resolve

        body = _make_komoju_body("acct-123")
        secret = "real-secret"
        sig = _make_signature(body, secret)

        db = MagicMock()

        with patch("app.services.webhook.hmac_resolver._lookup_org_secret") as mock_lookup:
            mock_lookup.return_value = ("org-abc", secret)

            result = resolve(
                provider="komoju",
                headers={},
                body=body,
                db=db,
                signature=sig,
            )

        assert result.org_id == "org-abc"
        assert result.verified is True
        assert result.provider == "komoju"

    def test_unsupported_provider_raises(self):
        from app.services.webhook.hmac_resolver import resolve

        with pytest.raises(ValueError, match="Unsupported provider"):
            resolve(
                provider="stripe",
                headers={},
                body=b"{}",
                db=MagicMock(),
                signature="sig",
            )
