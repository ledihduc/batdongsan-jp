"""VinaCA digital signature provider (fallback vendor — AS-14).

Pre-launch gate AS-14: this provider is a skeleton until the VinaCA vendor contract
is signed. All methods raise DigitalSignatureError with a clear message.

When contract is signed:
1. Set DIGITAL_SIGNATURE_PROVIDER=vinaca in env.
2. Set VINACA_API_KEY and VINACA_API_SECRET in env.
3. Replace TODO sections below with real VinaCA REST API calls.

VinaCA API reference (placeholder — URL from vendor sales contact):
  POST https://api.vinaca.vn/v1/signing/request
  POST https://api.vinaca.vn/v1/signing/webhook
"""

from __future__ import annotations

import logging
from typing import Optional

from app.services.kyc.digital_signature.provider_interface import (
    DigitalSignatureError,
    DigitalSignatureProvider,
    SigningResult,
)

logger = logging.getLogger(__name__)

_VINACA_BASE_URL = "https://api.vinaca.vn/v1"
_REQUEST_PATH = "/signing/request"
_WEBHOOK_PATH = "/signing/webhook"


class VinaCAProvider(DigitalSignatureProvider):
    """VinaCA REST API client for digital POA signing (fallback, AS-14).

    Structure mirrors FastCAProvider to ease future vendor swap.
    """

    def _get_credentials(self) -> tuple[str, str]:
        """Return (api_key, api_secret) or raise DigitalSignatureError if absent."""
        from app.config import settings

        api_key = getattr(settings, "vinaca_api_key", None)
        api_secret = getattr(settings, "vinaca_api_secret", None)

        if not api_key or not api_secret:
            raise DigitalSignatureError(
                "VinaCA credentials not configured. "
                "Set VINACA_API_KEY and VINACA_API_SECRET environment variables. "
                "Pre-launch gate AS-14 must be satisfied before enabling this provider."
            )
        return api_key, api_secret

    def is_configured(self) -> bool:
        from app.config import settings

        api_key = getattr(settings, "vinaca_api_key", None)
        api_secret = getattr(settings, "vinaca_api_secret", None)
        return bool(api_key and api_secret)

    def initiate_signing(
        self,
        user_phone: str,
        document_bytes: bytes,
        document_name: str,
        *,
        metadata: Optional[dict] = None,
    ) -> SigningResult:
        """Call VinaCA signing request endpoint.

        TODO (AS-14 contract): Implement with real VinaCA REST client.
        """
        _, _ = self._get_credentials()

        logger.warning(
            "VinaCAProvider.initiate_signing called but AS-14 integration is not yet "
            "implemented. doc=%s phone=%s",
            document_name,
            user_phone[-4:] if len(user_phone) >= 4 else "****",
        )

        raise DigitalSignatureError(
            "VinaCA integration pending vendor contract (AS-14). "
            "Use DIGITAL_SIGNATURE_PROVIDER=stub for v0."
        )

    def verify_callback(
        self,
        payload: dict,
        vendor_signature: Optional[str] = None,
    ) -> SigningResult:
        """Verify VinaCA webhook callback.

        TODO (AS-14 contract): Implement HMAC verification + payload parsing.
        """
        _, _ = self._get_credentials()

        raise DigitalSignatureError(
            "VinaCA callback verification pending vendor contract (AS-14)."
        )
