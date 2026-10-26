"""Digital signature integration — FastCA/VinaCA thin client (Phase 04, AC-55d).

Provides:
  - SignatureClient: abstract interface for digital signature vendors
  - FastCASignatureClient: FastCA stub (raises VendorNotConfigured if FASTCA_API_KEY not set)
  - MockSignatureClient: in-memory mock for tests
  - get_signature_client(): factory based on env config

Design (TL-7):
  - Default vendor: FastCA (lower per-sig cost per AS-14 budget)
  - Fallback: VinaCA (if DIGITAL_SIG_VENDOR=vinaca)
  - If vendor contract not signed (AS-14 delayed): caller catches VendorNotConfigured
    and falls back to notarized POA path (AC-55d).

Circuit breaker (risk mitigation):
  - 3 consecutive failures → mark vendor down for 5 min
  - Callers check _is_vendor_available() before calling
"""

from __future__ import annotations

import logging
import os
import time
from abc import ABC, abstractmethod
from typing import Optional

logger = logging.getLogger(__name__)

# Circuit breaker state (module-level — simple in-memory for v1 single-instance)
_vendor_failure_count: int = 0
_vendor_down_until: float = 0.0
_CIRCUIT_BREAK_FAILURES = 3
_CIRCUIT_BREAK_COOLDOWN_SECONDS = 300  # 5 minutes


class VendorNotConfigured(Exception):
    """Raised when vendor API key is not set — caller should fallback to notarized POA."""


class VendorUnavailable(Exception):
    """Raised when circuit breaker is open (too many recent failures)."""


class SignatureClient(ABC):
    """Abstract interface for digital signature vendor integrations."""

    @abstractmethod
    def get_signature_reference(self, delegation_id: str) -> Optional[str]:
        """Return signature reference string for a delegation, or None if not found.

        Args:
            delegation_id: UUID of the Delegation row

        Returns:
            Vendor-assigned signature reference string (e.g. FastCA transaction ID)
            or None if no signature exists for this delegation.

        Raises:
            VendorNotConfigured: if API key is not set
            VendorUnavailable: if circuit breaker is open
        """

    @abstractmethod
    def register_delegation_poa(self, delegation_id: str, poa_document_path: str) -> str:
        """Register a POA document for digital signature with the vendor.

        Args:
            delegation_id: UUID of the Delegation
            poa_document_path: path to the signed POA document

        Returns:
            Vendor transaction reference ID

        Raises:
            VendorNotConfigured: if API key is not set
            VendorUnavailable: if circuit breaker is open
        """


class FastCASignatureClient(SignatureClient):
    """FastCA digital signature vendor client (AS-14 primary vendor).

    Raises VendorNotConfigured if FASTCA_API_KEY environment variable is not set.
    This is the expected behavior when AS-14 vendor contract has not been signed yet —
    callers should catch and fallback to notarized POA path.
    """

    def __init__(self) -> None:
        self.api_key = os.getenv("FASTCA_API_KEY", "").strip()
        self.api_base = os.getenv("FASTCA_API_BASE", "https://api.fastca.vn/v1")
        if not self.api_key:
            raise VendorNotConfigured(
                "FASTCA_API_KEY not set — FastCA vendor contract not yet signed (AS-14). "
                "Fallback to notarized POA path."
            )

    def get_signature_reference(self, delegation_id: str) -> Optional[str]:
        """Look up existing signature reference for delegation in FastCA system."""
        _check_circuit_breaker()
        try:
            # v1.0 stub — real HTTP call added when AS-14 contract signed
            # Simulates: GET /api/v1/poa/delegations/{delegation_id}
            logger.info(
                "[FastCA] get_signature_reference delegation_id=%s (stub)", delegation_id
            )
            _reset_failure_count()
            return None  # No signature registered yet in v1 stub
        except Exception as exc:  # noqa: BLE001
            _record_failure()
            logger.error("[FastCA] get_signature_reference failed: %s", exc)
            raise

    def register_delegation_poa(self, delegation_id: str, poa_document_path: str) -> str:
        """Register POA document with FastCA for digital signature."""
        _check_circuit_breaker()
        try:
            # v1.0 stub — real HTTP call added when AS-14 contract signed
            # Simulates: POST /api/v1/poa/register
            logger.info(
                "[FastCA] register_delegation_poa delegation_id=%s path=%s (stub)",
                delegation_id,
                poa_document_path,
            )
            _reset_failure_count()
            return f"fastca_stub_{delegation_id}"
        except Exception as exc:  # noqa: BLE001
            _record_failure()
            logger.error("[FastCA] register_delegation_poa failed: %s", exc)
            raise


class VinaCaSignatureClient(SignatureClient):
    """VinaCA digital signature fallback vendor.

    Raises VendorNotConfigured if VINACA_API_KEY not set.
    """

    def __init__(self) -> None:
        self.api_key = os.getenv("VINACA_API_KEY", "").strip()
        self.api_base = os.getenv("VINACA_API_BASE", "https://api.vnpt-ca.vn/v1")
        if not self.api_key:
            raise VendorNotConfigured(
                "VINACA_API_KEY not set — VinaCA vendor contract not signed. "
                "Fallback to notarized POA path."
            )

    def get_signature_reference(self, delegation_id: str) -> Optional[str]:
        _check_circuit_breaker()
        logger.info("[VinaCA] get_signature_reference delegation_id=%s (stub)", delegation_id)
        return None

    def register_delegation_poa(self, delegation_id: str, poa_document_path: str) -> str:
        _check_circuit_breaker()
        logger.info("[VinaCA] register_delegation_poa (stub)")
        return f"vinaca_stub_{delegation_id}"


class MockSignatureClient(SignatureClient):
    """In-memory mock for tests. Always returns a canned reference."""

    def __init__(self, reference: Optional[str] = "mock_ref_12345") -> None:
        self._reference = reference

    def get_signature_reference(self, delegation_id: str) -> Optional[str]:
        logger.debug("[MockSignature] get_signature_reference delegation_id=%s", delegation_id)
        return self._reference

    def register_delegation_poa(self, delegation_id: str, poa_document_path: str) -> str:
        logger.debug("[MockSignature] register_delegation_poa (mock)")
        return f"mock_{delegation_id}"


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------


def get_signature_client() -> SignatureClient:
    """Return appropriate signature client based on DIGITAL_SIG_VENDOR env var.

    DIGITAL_SIG_VENDOR=fastca  (default)
    DIGITAL_SIG_VENDOR=vinaca  (fallback)
    DIGITAL_SIG_VENDOR=mock    (tests only)

    Raises VendorNotConfigured if no vendor API key is configured.
    """
    vendor = os.getenv("DIGITAL_SIG_VENDOR", "fastca").lower().strip()

    if vendor == "mock":
        return MockSignatureClient()
    if vendor == "vinaca":
        return VinaCaSignatureClient()
    # Default: FastCA
    return FastCASignatureClient()


# ---------------------------------------------------------------------------
# Circuit breaker helpers
# ---------------------------------------------------------------------------


def _check_circuit_breaker() -> None:
    """Raise VendorUnavailable if circuit breaker is open."""
    global _vendor_down_until  # noqa: PLW0602
    if _vendor_down_until > time.time():
        remaining = int(_vendor_down_until - time.time())
        raise VendorUnavailable(
            f"Digital signature vendor circuit breaker open — retry in {remaining}s"
        )


def _record_failure() -> None:
    """Increment failure count; open circuit breaker if threshold exceeded."""
    global _vendor_failure_count, _vendor_down_until  # noqa: PLW0603
    _vendor_failure_count += 1
    if _vendor_failure_count >= _CIRCUIT_BREAK_FAILURES:
        _vendor_down_until = time.time() + _CIRCUIT_BREAK_COOLDOWN_SECONDS
        logger.error(
            "[DigitalSig] Circuit breaker OPEN — vendor down for %d seconds",
            _CIRCUIT_BREAK_COOLDOWN_SECONDS,
        )


def _reset_failure_count() -> None:
    """Reset failure count on successful call."""
    global _vendor_failure_count  # noqa: PLW0603
    _vendor_failure_count = 0
