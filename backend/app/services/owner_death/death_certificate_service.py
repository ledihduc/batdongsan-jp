"""Death certificate service — report, verify, reject (AC-58, US-A6, US-A7).

Responsibilities:
  - report_death()   : heir/admin/operator submits death notice → pending_verification
  - verify_death()   : admin verifies certificate → triggers 7-day delegation pause
  - reject_death()   : admin rejects (insufficient evidence)
  - get_certificate(): look up certificate by owner_user_id (IDOR-guarded at route layer)

Design:
  - One active certificate per owner (UNIQUE owner_user_id enforced by DB + service).
  - Verification SLA tracked via created_at vs verified_at (24h business-hours per US-A7).
  - File paths for death cert / notarized POA are validated to stay within upload dir
    (path-traversal prevention; mirrors existing upload pattern).
  - Caller commits transaction; this service only flushes.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.owner_death import OwnerDeathCertificate

logger = logging.getLogger(__name__)

# Upload subdirectory for death-related sensitive docs
_DEATH_DOC_SUBDIR = "death_certificates"

# Valid in-flight policy values (AC-58d)
_VALID_IN_FLIGHT_POLICIES = frozenset(["auto_reject", "executor_may_decide"])


class DeathCertificateError(Exception):
    """Base for death certificate domain errors."""


class DuplicateCertificateError(DeathCertificateError):
    """Owner already has an active death certificate record."""

    def __init__(self, existing_id: str) -> None:
        self.existing_id = existing_id
        super().__init__(
            f"Owner already has a death certificate record: {existing_id}. "
            "Use the existing record to track verification progress."
        )


class CertificateNotFoundError(DeathCertificateError):
    """Certificate not found."""


class InvalidVerificationStateError(DeathCertificateError):
    """Certificate is not in the correct state for the requested transition."""


class DeathCertificateService:
    """CRUD + state machine for owner_death_certificates.

    Injected with DB session; caller (route) manages commits.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # report_death — heir/operator/admin reports owner's death
    # ------------------------------------------------------------------

    def report_death(
        self,
        owner_user_id: int,
        death_certificate_path: str,
        submitted_by_user_id: Optional[int] = None,
        notarized_poa_path: Optional[str] = None,
        executor_user_id: Optional[int] = None,
    ) -> OwnerDeathCertificate:
        """AC-58: Create a pending death certificate record.

        Enforces UNIQUE owner_user_id: raises DuplicateCertificateError if a
        record already exists for this owner.

        Args:
            owner_user_id: the deceased owner's user ID.
            death_certificate_path: validated upload path (sanitized by caller).
            submitted_by_user_id: user submitting this report (heir / admin / operator).
            notarized_poa_path: optional POA path (may be added later).
            executor_user_id: optional designated executor (may be added after verify).

        Returns: newly flushed OwnerDeathCertificate with status='pending'.
        """
        # Guard: one record per owner
        existing = (
            self.db.query(OwnerDeathCertificate)
            .filter(OwnerDeathCertificate.owner_user_id == owner_user_id)
            .first()
        )
        if existing is not None:
            raise DuplicateCertificateError(existing_id=str(existing.id))

        # Validate file paths are not traversal attempts
        _validate_upload_path(death_certificate_path)
        if notarized_poa_path:
            _validate_upload_path(notarized_poa_path)

        cert = OwnerDeathCertificate(
            owner_user_id=owner_user_id,
            death_certificate_path=death_certificate_path,
            notarized_poa_path=notarized_poa_path,
            submitted_by_user_id=submitted_by_user_id,
            executor_user_id=executor_user_id,
            verification_status="pending",
            verified_at=None,
            verified_by_admin_id=None,
        )
        self.db.add(cert)
        self.db.flush()

        logger.info(
            "[DEATH_CERT] Created pending certificate id=%s owner=%d submitted_by=%s",
            cert.id,
            owner_user_id,
            submitted_by_user_id,
        )
        return cert

    # ------------------------------------------------------------------
    # verify_death — admin approves death certificate
    # ------------------------------------------------------------------

    def verify_death(
        self,
        cert_id: str,
        admin_user_id: int,
        notes: Optional[str] = None,
        in_flight_handling_policy: str = "auto_reject",
    ) -> OwnerDeathCertificate:
        """AC-58: Admin verifies death certificate → triggers delegation pause.

        After calling this method, caller MUST call DeathPauseService.pause_for_owner_death()
        to propagate the 7-day pause to all active delegations.

        Args:
            cert_id: certificate UUID.
            admin_user_id: the admin performing verification.
            notes: optional reviewer notes (stored in log for audit).
            in_flight_handling_policy: 'auto_reject' (default) or
                'executor_may_decide' (only if AC-58d gate O3 confirmed).

        Returns: updated certificate with status='verified'.
        """
        if in_flight_handling_policy not in _VALID_IN_FLIGHT_POLICIES:
            raise ValueError(
                f"Invalid in_flight_handling_policy '{in_flight_handling_policy}'. "
                f"Must be one of {sorted(_VALID_IN_FLIGHT_POLICIES)}"
            )

        cert = self._load_or_raise(cert_id)
        if cert.verification_status != "pending":
            raise InvalidVerificationStateError(
                f"Certificate {cert_id} is not pending (current: {cert.verification_status}). "
                "Only pending certificates can be verified."
            )

        now = datetime.utcnow()
        cert.verification_status = "verified"
        cert.verified_at = now
        cert.verified_by_admin_id = admin_user_id
        self.db.flush()

        # Compute and log SLA elapsed (US-A7: 24h business-hours target)
        sla_hours = _hours_since(cert.created_at, now)
        sla_status = "within_sla" if sla_hours <= 24 else "sla_exceeded"
        logger.info(
            "[DEATH_CERT] Verified id=%s owner=%d admin=%d sla_hours=%.1f sla_status=%s "
            "in_flight_policy=%s notes=%s",
            cert_id,
            cert.owner_user_id,
            admin_user_id,
            sla_hours,
            sla_status,
            in_flight_handling_policy,
            notes,
        )
        return cert

    # ------------------------------------------------------------------
    # reject_death — admin rejects death certificate
    # ------------------------------------------------------------------

    def reject_death(
        self,
        cert_id: str,
        admin_user_id: int,
        rejection_reason: str,
    ) -> OwnerDeathCertificate:
        """AC-58: Admin rejects death certificate (insufficient evidence).

        Args:
            cert_id: certificate UUID.
            admin_user_id: the admin performing the rejection.
            rejection_reason: free-text reason for audit trail.

        Returns: updated certificate with status='rejected'.
        """
        cert = self._load_or_raise(cert_id)
        if cert.verification_status != "pending":
            raise InvalidVerificationStateError(
                f"Certificate {cert_id} is not pending (current: {cert.verification_status}). "
                "Only pending certificates can be rejected."
            )

        now = datetime.utcnow()
        cert.verification_status = "rejected"
        cert.verified_at = now  # timestamp of decision (could be rejection_decided_at in v2)
        cert.verified_by_admin_id = admin_user_id
        self.db.flush()

        logger.info(
            "[DEATH_CERT] Rejected id=%s owner=%d admin=%d reason=%s",
            cert_id,
            cert.owner_user_id,
            admin_user_id,
            rejection_reason,
        )
        return cert

    # ------------------------------------------------------------------
    # get_certificate — retrieve by owner_user_id
    # ------------------------------------------------------------------

    def get_by_owner(self, owner_user_id: int) -> Optional[OwnerDeathCertificate]:
        """Retrieve certificate for owner. Returns None if not found."""
        return (
            self.db.query(OwnerDeathCertificate)
            .filter(OwnerDeathCertificate.owner_user_id == owner_user_id)
            .first()
        )

    def get_by_id(self, cert_id: str) -> Optional[OwnerDeathCertificate]:
        """Retrieve certificate by UUID. Returns None if not found."""
        return (
            self.db.query(OwnerDeathCertificate)
            .filter(OwnerDeathCertificate.id == cert_id)
            .first()
        )

    def list_pending(self, limit: int = 100) -> list[OwnerDeathCertificate]:
        """List certificates pending admin review (US-A6)."""
        return (
            self.db.query(OwnerDeathCertificate)
            .filter(OwnerDeathCertificate.verification_status == "pending")
            .order_by(OwnerDeathCertificate.created_at.asc())  # oldest first (FIFO for SLA)
            .limit(limit)
            .all()
        )

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _load_or_raise(self, cert_id: str) -> OwnerDeathCertificate:
        cert = (
            self.db.query(OwnerDeathCertificate)
            .filter(OwnerDeathCertificate.id == cert_id)
            .with_for_update()
            .first()
        )
        if cert is None:
            raise CertificateNotFoundError(f"Death certificate {cert_id} not found")
        return cert


# ---------------------------------------------------------------------------
# Path-traversal guard
# ---------------------------------------------------------------------------


def _validate_upload_path(path: str) -> None:
    """Prevent path traversal: path must not escape its directory prefix.

    Accepts relative paths (will be joined to upload dir by file service).
    Raises ValueError on traversal attempts.
    """
    # Normalize to remove ./ and ../
    normalized = os.path.normpath(path)
    # Detect traversal: normalized path must not start with ..
    if normalized.startswith("..") or "\x00" in path:
        raise ValueError(f"Invalid file path — potential traversal detected: {path!r}")


def _hours_since(start: datetime, end: datetime) -> float:
    """Return hours elapsed between two UTC datetimes."""
    if start is None:
        return 0.0
    return (end - start).total_seconds() / 3600.0
