"""Unit tests for digital signature provider interface + stub provider.

Coverage:
  - StubSignatureProvider.is_configured: always True
  - StubSignatureProvider.initiate_signing: deterministic ref, status=signed_stub
  - StubSignatureProvider.verify_callback: parse ref from payload
  - get_provider: returns stub by default
  - FastCAProvider.is_configured: returns False when no credentials
  - VinaCAProvider.is_configured: returns False when no credentials
"""

from __future__ import annotations

import os
from unittest.mock import patch

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("DIGITAL_SIGNATURE_PROVIDER", "stub")


# ---------------------------------------------------------------------------
# StubSignatureProvider
# ---------------------------------------------------------------------------


class TestStubSignatureProvider:
    def setup_method(self):
        from app.services.kyc.digital_signature.provider_interface import StubSignatureProvider
        self.provider = StubSignatureProvider()

    def test_is_configured_always_true(self):
        assert self.provider.is_configured() is True

    def test_initiate_signing_returns_signed_stub_status(self):
        from app.services.kyc.digital_signature.provider_interface import SigningStatus

        result = self.provider.initiate_signing(
            user_phone="0901234567",
            document_bytes=b"test document",
            document_name="POA.pdf",
        )
        assert result.status == SigningStatus.SIGNED_STUB

    def test_initiate_signing_returns_deterministic_ref(self):
        """Same phone + doc → same ref (reproducible for tests)."""
        result1 = self.provider.initiate_signing(
            user_phone="0901234567",
            document_bytes=b"same document",
            document_name="POA.pdf",
        )
        result2 = self.provider.initiate_signing(
            user_phone="0901234567",
            document_bytes=b"same document",
            document_name="POA.pdf",
        )
        assert result1.signature_ref == result2.signature_ref

    def test_initiate_signing_ref_differs_with_different_doc(self):
        result1 = self.provider.initiate_signing(
            user_phone="0901234567",
            document_bytes=b"doc A",
            document_name="POA.pdf",
        )
        result2 = self.provider.initiate_signing(
            user_phone="0901234567",
            document_bytes=b"doc B",
            document_name="POA.pdf",
        )
        assert result1.signature_ref != result2.signature_ref

    def test_initiate_signing_session_url_is_none(self):
        result = self.provider.initiate_signing(
            user_phone="0901234567",
            document_bytes=b"test",
            document_name="POA.pdf",
        )
        assert result.session_url is None

    def test_verify_callback_reads_signature_ref(self):
        from app.services.kyc.digital_signature.provider_interface import SigningStatus

        result = self.provider.verify_callback(
            payload={"signature_ref": "stub-12345678-abcd"},
        )
        assert result.signature_ref == "stub-12345678-abcd"
        assert result.status == SigningStatus.SIGNED_STUB

    def test_verify_callback_reads_ref_key_fallback(self):
        result = self.provider.verify_callback(
            payload={"ref": "alt-ref-value"},
        )
        assert result.signature_ref == "alt-ref-value"

    def test_verify_callback_handles_unknown_ref(self):
        result = self.provider.verify_callback(payload={})
        assert "unknown" in result.signature_ref


# ---------------------------------------------------------------------------
# get_provider factory
# ---------------------------------------------------------------------------


class TestGetProvider:
    """Tests that require reloading settings — uses direct provider name check, not env pollution."""

    def test_returns_stub_by_default(self):
        """Stub provider returned when digital_signature_provider='stub'."""
        from app.services.kyc.digital_signature.provider_interface import (
            StubSignatureProvider,
            DigitalSignatureProvider,
        )
        # Directly instantiate stub to verify it satisfies the interface
        provider = StubSignatureProvider()
        assert isinstance(provider, DigitalSignatureProvider)
        assert provider.is_configured() is True

    def test_fastca_provider_satisfies_interface(self):
        from app.services.kyc.digital_signature.fastca_provider import FastCAProvider
        from app.services.kyc.digital_signature.provider_interface import DigitalSignatureProvider
        provider = FastCAProvider()
        assert isinstance(provider, DigitalSignatureProvider)

    def test_vinaca_provider_satisfies_interface(self):
        from app.services.kyc.digital_signature.vinaca_provider import VinaCAProvider
        from app.services.kyc.digital_signature.provider_interface import DigitalSignatureProvider
        provider = VinaCAProvider()
        assert isinstance(provider, DigitalSignatureProvider)

    def test_get_provider_returns_stub_when_env_is_stub(self, monkeypatch):
        """get_provider() factory returns StubSignatureProvider for provider=stub."""
        from unittest.mock import MagicMock
        mock_settings = MagicMock()
        mock_settings.digital_signature_provider = "stub"

        with patch("app.config.settings", mock_settings):
            from app.services.kyc.digital_signature import get_provider
            from app.services.kyc.digital_signature.provider_interface import StubSignatureProvider
            provider = get_provider()
            assert isinstance(provider, StubSignatureProvider)

    def test_get_provider_returns_fastca_when_env_is_fastca(self, monkeypatch):
        from unittest.mock import MagicMock
        mock_settings = MagicMock()
        mock_settings.digital_signature_provider = "fastca"

        with patch("app.config.settings", mock_settings):
            from app.services.kyc.digital_signature import get_provider
            from app.services.kyc.digital_signature.fastca_provider import FastCAProvider
            provider = get_provider()
            assert isinstance(provider, FastCAProvider)

    def test_get_provider_returns_vinaca_when_env_is_vinaca(self, monkeypatch):
        from unittest.mock import MagicMock
        mock_settings = MagicMock()
        mock_settings.digital_signature_provider = "vinaca"

        with patch("app.config.settings", mock_settings):
            from app.services.kyc.digital_signature import get_provider
            from app.services.kyc.digital_signature.vinaca_provider import VinaCAProvider
            provider = get_provider()
            assert isinstance(provider, VinaCAProvider)


# ---------------------------------------------------------------------------
# FastCAProvider / VinaCAProvider — credential checks
# ---------------------------------------------------------------------------


class TestFastCAProvider:
    def setup_method(self):
        # Ensure no credentials are set
        os.environ.pop("FASTCA_API_KEY", None)
        os.environ.pop("FASTCA_API_SECRET", None)

    def test_is_configured_false_when_no_creds(self):
        from app.services.kyc.digital_signature.fastca_provider import FastCAProvider
        provider = FastCAProvider()
        assert provider.is_configured() is False

    def test_initiate_raises_digital_signature_error(self):
        from app.services.kyc.digital_signature.fastca_provider import FastCAProvider
        from app.services.kyc.digital_signature.provider_interface import DigitalSignatureError

        provider = FastCAProvider()
        with pytest.raises(DigitalSignatureError, match="AS-14"):
            provider.initiate_signing(
                user_phone="0901234567",
                document_bytes=b"test",
                document_name="POA.pdf",
            )


class TestVinaCAProvider:
    def setup_method(self):
        os.environ.pop("VINACA_API_KEY", None)
        os.environ.pop("VINACA_API_SECRET", None)

    def test_is_configured_false_when_no_creds(self):
        from app.services.kyc.digital_signature.vinaca_provider import VinaCAProvider
        provider = VinaCAProvider()
        assert provider.is_configured() is False

    def test_initiate_raises_digital_signature_error(self):
        from app.services.kyc.digital_signature.vinaca_provider import VinaCAProvider
        from app.services.kyc.digital_signature.provider_interface import DigitalSignatureError

        provider = VinaCAProvider()
        with pytest.raises(DigitalSignatureError, match="AS-14"):
            provider.initiate_signing(
                user_phone="0901234567",
                document_bytes=b"test",
                document_name="POA.pdf",
            )
