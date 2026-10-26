"""FastCA digital signature provider (primary vendor — AS-14).

Pre-launch gate AS-14: this provider is a skeleton until the FastCA vendor contract
is signed. All methods raise DigitalSignatureError with a clear message.

When contract is signed:
1. Set DIGITAL_SIGNATURE_PROVIDER=fastca in env.
2. Set FASTCA_API_KEY and FASTCA_API_SECRET in env.
3. Replace TODO sections below with real FastCA REST API calls.
4. Remove the 'raise' guards after integration testing.

Security:
  - API key/secret read from Settings (env only); never logged.
  - HTTP calls must use TLS (https://). Validate SSL cert.
  - HMAC verification must happen in verify_callback before trusting payload.

FastCA API reference (placeholder — URL from vendor sales contact):
  POST https://api.fastca.vn/v1/signing/initiate
  POST https://api.fastca.vn/v1/signing/verify-callback
"""

from __future__ import annotations

import logging
from typing import Optional

from app.services.kyc.digital_signature.provider_interface import (
    DigitalSignatureError,
    DigitalSignatureProvider,
    SigningResult,
    SigningStatus,
)

logger = logging.getLogger(__name__)

# FastCA API endpoints — update once vendor provides production URLs
_FASTCA_BASE_URL = "https://api.fastca.vn/v1"
_INITIATE_PATH = "/signing/initiate"
_CALLBACK_VERIFY_PATH = "/signing/verify-callback"


class FastCAProvider(DigitalSignatureProvider):
    """FastCA REST API client for digital POA signing.

    Credentials are read lazily from settings on each call to avoid
    module-load side effects.
    """

    def _get_credentials(self) -> tuple[str, str]:
        """Return (api_key, api_secret) or raise DigitalSignatureError if absent."""
        from app.config import settings

        api_key = getattr(settings, "fastca_api_key", None)
        api_secret = getattr(settings, "fastca_api_secret", None)

        if not api_key or not api_secret:
            raise DigitalSignatureError(
                "FastCA credentials not configured. "
                "Set FASTCA_API_KEY and FASTCA_API_SECRET environment variables. "
                "Pre-launch gate AS-14 must be satisfied before enabling this provider."
            )
        return api_key, api_secret

    def is_configured(self) -> bool:
        """Return True only when both API key and secret are set."""
        from app.config import settings

        api_key = getattr(settings, "fastca_api_key", None)
        api_secret = getattr(settings, "fastca_api_secret", None)
        return bool(api_key and api_secret)

    def initiate_signing(
        self,
        user_phone: str,
        document_bytes: bytes,
        document_name: str,
        *,
        metadata: Optional[dict] = None,
    ) -> SigningResult:
        """Call FastCA signing initiate endpoint.

        TODO (AS-14 contract): Implement with real FastCA REST client.
        Steps:
          1. POST {BASE}/signing/initiate with document + phone + metadata.
          2. Parse response: {session_id, session_url, expires_at}.
          3. Return SigningResult(status=PENDING, signature_ref=session_id, session_url=...).
        """
        api_key, _ = self._get_credentials()

        logger.warning(
            "FastCAProvider.initiate_signing called but AS-14 integration is not yet "
            "implemented. doc=%s phone=%s",
            document_name,
            user_phone[-4:] if len(user_phone) >= 4 else "****",
        )

        # TODO: Replace with actual FastCA REST call after vendor contract signed.
        raise DigitalSignatureError(
            "FastCA integration pending vendor contract (AS-14). "
            "Use DIGITAL_SIGNATURE_PROVIDER=stub for v0."
        )

    def verify_callback(
        self,
        payload: dict,
        vendor_signature: Optional[str] = None,
    ) -> SigningResult:
        """Verify FastCA webhook callback.

        TODO (AS-14 contract): Implement HMAC-SHA256 verification.
        Steps:
          1. Compute expected_sig = HMAC-SHA256(api_secret, raw_body).
          2. Compare with vendor_signature header (constant-time compare).
          3. Parse payload fields: {session_id, status, signed_doc_url}.
          4. Return SigningResult accordingly.
        """
        _, _ = self._get_credentials()

        # TODO: Replace with real HMAC verify + payload parse after vendor contract.
        raise DigitalSignatureError(
            "FastCA callback verification pending vendor contract (AS-14)."
        )
