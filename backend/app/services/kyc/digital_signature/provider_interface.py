"""Digital signature provider ABC + StubSignatureProvider.

AC-55d / AS-14 / TL-7: FastCA primary, VinaCA fallback.
Default config DIGITAL_SIGNATURE_PROVIDER=stub — real vendor swap when AS-14 contract signed.

Stub provider is gated for v0: returns status='signed_stub' with a deterministic
reference so tests are reproducible.

Security notes:
  - API keys stored in Settings (env only), never logged.
  - document_bytes are never stored in-memory beyond this call; caller owns retention.
  - signature_ref returned is an opaque vendor token — never expose raw byte content.
"""

from __future__ import annotations

import hashlib
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
from typing import Optional

logger = logging.getLogger(__name__)


class SigningStatus(str, Enum):
    """Possible outcomes of a signing request."""

    # Stub path (v0 — no vendor contract yet)
    SIGNED_STUB = "signed_stub"
    # Real vendor: signing session initiated — awaiting callback
    PENDING = "pending"
    # Vendor confirmed signature complete
    COMPLETED = "completed"
    # Vendor rejected / user declined
    FAILED = "failed"


@dataclass(frozen=True)
class SigningResult:
    """Immutable result returned by provider.initiate_signing().

    Fields:
        status:         SigningStatus enum value.
        signature_ref:  Vendor-issued opaque reference (store in DB; use for callback lookup).
        session_url:    Optional URL for user to complete signing (if vendor uses redirect flow).
        error_message:  Present only when status == FAILED.
    """

    status: SigningStatus
    signature_ref: str
    session_url: Optional[str] = None
    error_message: Optional[str] = None


class DigitalSignatureProvider(ABC):
    """Abstract base class for digital signature providers.

    Implementing classes must be stateless (no instance-level caching of auth tokens).
    Provider instances are created per-request via get_provider().
    """

    @abstractmethod
    def is_configured(self) -> bool:
        """Return True if required credentials are present in Settings.

        Flutter UI uses this to show/hide the 'Digital POA' option (AC-55d).
        """

    @abstractmethod
    def initiate_signing(
        self,
        user_phone: str,
        document_bytes: bytes,
        document_name: str,
        *,
        metadata: Optional[dict] = None,
    ) -> SigningResult:
        """Initiate a signing session.

        Args:
            user_phone:     Legal rep's phone number (used for OTP / identity verification).
            document_bytes: Raw PDF bytes to be signed.
            document_name:  Human-readable document name (stored in vendor audit trail).
            metadata:       Optional dict with delegation_id, owner_name, etc.

        Returns:
            SigningResult — immutable; caller stores signature_ref in DB.

        Raises:
            DigitalSignatureError: Vendor returned non-retryable error.
        """

    @abstractmethod
    def verify_callback(
        self,
        payload: dict,
        vendor_signature: Optional[str] = None,
    ) -> SigningResult:
        """Verify and parse vendor callback webhook payload.

        Args:
            payload:          Raw parsed JSON body from vendor callback.
            vendor_signature: HMAC or vendor signature header value for verification.

        Returns:
            SigningResult — caller updates delegation/KYC row accordingly.

        Raises:
            DigitalSignatureError: Callback payload invalid or HMAC mismatch.
        """


class DigitalSignatureError(Exception):
    """Raised when vendor API returns a non-retryable error."""


# ---------------------------------------------------------------------------
# Stub provider — v0 implementation for dev/test
# ---------------------------------------------------------------------------


class StubSignatureProvider(DigitalSignatureProvider):
    """Stub digital signature provider for v0 (no vendor contract).

    Returns deterministic mock signature_ref derived from document hash.
    Status is always SIGNED_STUB so callers can distinguish from real completions.

    Pre-launch gate AS-14: replace with FastCAProvider once contract is signed.
    """

    def is_configured(self) -> bool:
        # Stub is always 'configured' — it never needs credentials.
        return True

    def initiate_signing(
        self,
        user_phone: str,
        document_bytes: bytes,
        document_name: str,
        *,
        metadata: Optional[dict] = None,
    ) -> SigningResult:
        # Deterministic ref: SHA256 of (phone + doc_name + doc hash)
        doc_hash = hashlib.sha256(document_bytes).hexdigest()[:16]
        phone_norm = "".join(c for c in user_phone if c.isdigit())[-9:]
        ref = f"stub-{phone_norm}-{doc_hash}"

        logger.info(
            "digital_signature stub: initiate_signing doc=%s ref=%s",
            document_name,
            ref,
        )
        return SigningResult(
            status=SigningStatus.SIGNED_STUB,
            signature_ref=ref,
            session_url=None,
            error_message=None,
        )

    def verify_callback(
        self,
        payload: dict,
        vendor_signature: Optional[str] = None,
    ) -> SigningResult:
        # Stub callback: accept any payload that contains signature_ref
        ref = payload.get("signature_ref") or payload.get("ref", "stub-callback-unknown")
        logger.info("digital_signature stub: verify_callback ref=%s", ref)
        return SigningResult(
            status=SigningStatus.SIGNED_STUB,
            signature_ref=str(ref),
        )
