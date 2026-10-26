"""Unit tests for DeathCertificateService — report, verify, reject (AC-58)."""

from __future__ import annotations

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

import app.models  # noqa: F401 — register User on Base.metadata before domain

from app.services.owner_death.death_certificate_service import (
    DeathCertificateService,
    DuplicateCertificateError,
    InvalidVerificationStateError,
    _hours_since,
    _validate_upload_path,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_cert(
    cert_id: str = "cert-uuid-123",
    owner_user_id: int = 10,
    verification_status: str = "pending",
    created_at: datetime | None = None,
) -> MagicMock:
    cert = MagicMock()
    cert.id = cert_id
    cert.owner_user_id = owner_user_id
    cert.verification_status = verification_status
    cert.verified_at = None
    cert.verified_by_admin_id = None
    cert.created_at = created_at or datetime(2026, 1, 1, 10, 0, 0)
    return cert


def _make_db(existing_cert: MagicMock | None = None) -> MagicMock:
    """Return a mock Session pre-configured for common queries."""
    db = MagicMock()
    # Configure query chain for OwnerDeathCertificate lookups
    query_mock = db.query.return_value
    filter_mock = query_mock.filter.return_value
    filter_mock.first.return_value = existing_cert
    filter_mock.with_for_update.return_value.first.return_value = existing_cert
    return db


# ---------------------------------------------------------------------------
# report_death
# ---------------------------------------------------------------------------


class TestReportDeath:
    def test_happy_path_creates_cert(self):
        db = _make_db(existing_cert=None)

        svc = DeathCertificateService(db)
        svc.report_death(
            owner_user_id=10,
            death_certificate_path="uploads/certs/cert.pdf",
            submitted_by_user_id=20,
        )

        db.add.assert_called_once()
        db.flush.assert_called_once()
        added_obj = db.add.call_args[0][0]
        assert added_obj.owner_user_id == 10
        assert added_obj.verification_status == "pending"
        assert added_obj.submitted_by_user_id == 20

    def test_duplicate_raises_409(self):
        existing = _make_cert()
        db = _make_db(existing_cert=existing)

        svc = DeathCertificateService(db)
        with pytest.raises(DuplicateCertificateError) as exc_info:
            svc.report_death(
                owner_user_id=10,
                death_certificate_path="uploads/certs/cert.pdf",
            )
        assert exc_info.value.existing_id == existing.id

    def test_path_traversal_rejected(self):
        db = _make_db(existing_cert=None)
        svc = DeathCertificateService(db)

        with pytest.raises(ValueError, match="traversal"):
            svc.report_death(
                owner_user_id=10,
                death_certificate_path="../../../etc/passwd",
            )

    def test_null_byte_in_path_rejected(self):
        db = _make_db(existing_cert=None)
        svc = DeathCertificateService(db)

        with pytest.raises(ValueError, match="traversal"):
            svc.report_death(
                owner_user_id=10,
                death_certificate_path="uploads/\x00evil.pdf",
            )


# ---------------------------------------------------------------------------
# verify_death
# ---------------------------------------------------------------------------


class TestVerifyDeath:
    def test_verify_pending_cert(self):
        cert = _make_cert(verification_status="pending")
        db = _make_db(existing_cert=cert)

        svc = DeathCertificateService(db)
        result = svc.verify_death(
            cert_id="cert-uuid-123",
            admin_user_id=99,
            notes="Reviewed and approved",
        )

        assert result.verification_status == "verified"
        assert result.verified_by_admin_id == 99
        assert result.verified_at is not None
        db.flush.assert_called_once()

    def test_verify_already_verified_raises(self):
        cert = _make_cert(verification_status="verified")
        db = _make_db(existing_cert=cert)

        svc = DeathCertificateService(db)
        with pytest.raises(InvalidVerificationStateError, match="not pending"):
            svc.verify_death(cert_id="cert-uuid-123", admin_user_id=99)

    def test_verify_rejected_raises(self):
        cert = _make_cert(verification_status="rejected")
        db = _make_db(existing_cert=cert)

        svc = DeathCertificateService(db)
        with pytest.raises(InvalidVerificationStateError):
            svc.verify_death(cert_id="cert-uuid-123", admin_user_id=99)

    def test_invalid_in_flight_policy_raises(self):
        cert = _make_cert(verification_status="pending")
        db = _make_db(existing_cert=cert)

        svc = DeathCertificateService(db)
        with pytest.raises(ValueError, match="Invalid in_flight_handling_policy"):
            svc.verify_death(
                cert_id="cert-uuid-123",
                admin_user_id=99,
                in_flight_handling_policy="invalid_policy",
            )

    def test_valid_executor_may_decide_policy(self):
        cert = _make_cert(verification_status="pending")
        db = _make_db(existing_cert=cert)

        svc = DeathCertificateService(db)
        # Should not raise
        result = svc.verify_death(
            cert_id="cert-uuid-123",
            admin_user_id=99,
            in_flight_handling_policy="executor_may_decide",
        )
        assert result.verification_status == "verified"


# ---------------------------------------------------------------------------
# reject_death
# ---------------------------------------------------------------------------


class TestRejectDeath:
    def test_reject_pending_cert(self):
        cert = _make_cert(verification_status="pending")
        db = _make_db(existing_cert=cert)

        svc = DeathCertificateService(db)
        result = svc.reject_death(
            cert_id="cert-uuid-123",
            admin_user_id=88,
            rejection_reason="Missing notarized POA",
        )

        assert result.verification_status == "rejected"
        assert result.verified_by_admin_id == 88
        db.flush.assert_called_once()

    def test_reject_already_verified_raises(self):
        cert = _make_cert(verification_status="verified")
        db = _make_db(existing_cert=cert)

        svc = DeathCertificateService(db)
        with pytest.raises(InvalidVerificationStateError):
            svc.reject_death(cert_id="cert-uuid-123", admin_user_id=88, rejection_reason="x")

    def test_cert_not_found_raises(self):
        db = _make_db(existing_cert=None)
        svc = DeathCertificateService(db)

        from app.services.owner_death.death_certificate_service import CertificateNotFoundError
        with pytest.raises(CertificateNotFoundError):
            svc.reject_death(cert_id="nonexistent", admin_user_id=88, rejection_reason="x")


# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------


class TestHelpers:
    def test_validate_upload_path_ok(self):
        # Should not raise
        _validate_upload_path("uploads/certs/death_cert.pdf")
        _validate_upload_path("storage/docs/poa.pdf")

    def test_validate_upload_path_traversal(self):
        with pytest.raises(ValueError):
            _validate_upload_path("../../etc/passwd")

    def test_validate_upload_path_null_byte(self):
        with pytest.raises(ValueError):
            _validate_upload_path("uploads/\x00evil")

    def test_hours_since(self):
        start = datetime(2026, 1, 1, 0, 0, 0)
        end = datetime(2026, 1, 1, 12, 30, 0)
        assert abs(_hours_since(start, end) - 12.5) < 0.01

    def test_hours_since_none_start(self):
        end = datetime(2026, 1, 1, 12, 0, 0)
        assert _hours_since(None, end) == 0.0  # type: ignore[arg-type]
