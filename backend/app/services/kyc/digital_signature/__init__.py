"""Digital signature provider package.

Implements a provider-pluggable interface for POA digital signing.
Default: StubSignatureProvider (returns deterministic mock result).
Swap via DIGITAL_SIGNATURE_PROVIDER env var once vendor contract is signed (AS-14).

Available providers:
    stub      — StubSignatureProvider (v0, dev/test)
    fastca    — FastCAProvider (primary vendor, AS-14)
    vinaca    — VinaCAProvider (fallback vendor, AS-14)

Usage:
    from app.services.kyc.digital_signature import get_provider
    provider = get_provider()
    result = provider.initiate_signing(user_phone, doc_bytes, doc_name)
"""

from __future__ import annotations

from app.services.kyc.digital_signature.provider_interface import (
    DigitalSignatureProvider,
    SigningResult,
    SigningStatus,
)


def get_provider() -> DigitalSignatureProvider:
    """Return configured digital signature provider.

    Reads DIGITAL_SIGNATURE_PROVIDER env var (default 'stub').
    Imports the concrete provider lazily to avoid circular imports.
    """
    from app.config import settings

    provider_name = getattr(settings, "digital_signature_provider", "stub")

    if provider_name == "fastca":
        from app.services.kyc.digital_signature.fastca_provider import FastCAProvider
        return FastCAProvider()
    if provider_name == "vinaca":
        from app.services.kyc.digital_signature.vinaca_provider import VinaCAProvider
        return VinaCAProvider()

    # Default: stub — safe for dev + test
    from app.services.kyc.digital_signature.provider_interface import StubSignatureProvider
    return StubSignatureProvider()


__all__ = [
    "DigitalSignatureProvider",
    "SigningResult",
    "SigningStatus",
    "get_provider",
]
