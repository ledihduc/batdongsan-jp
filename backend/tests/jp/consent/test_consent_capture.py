"""Tests for APPI consent capture and DSR services.

Uses mock repositories — no DB connection required.
"""

from __future__ import annotations

import os
from datetime import datetime
from unittest.mock import MagicMock, patch

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest

from app.services.consent.capture import (
    get_consent_status,
    record_consent,
    revoke_consent,
)


def _make_consent_row(**kwargs) -> MagicMock:
    row = MagicMock()
    row.purpose = kwargs.get("purpose", "service_use")
    row.consent_version = kwargs.get("consent_version", "1.0")
    row.granted_at = kwargs.get("granted_at", datetime.utcnow())
    row.revoked_at = kwargs.get("revoked_at", None)
    return row


class TestRecordConsent:
    """Tests for record_consent()."""

    def test_valid_purposes_succeed(self) -> None:
        db = MagicMock()
        with patch("app.services.consent.capture.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_row = _make_consent_row(purpose="service_use")
            mock_repo.get_active.return_value = None
            mock_repo.grant.return_value = mock_row
            MockRepo.return_value = mock_repo

            result = record_consent(
                user_id=1, purposes=["service_use"], db=db
            )
            assert len(result) == 1
            mock_repo.grant.assert_called_once_with(
                user_id=1,
                purpose="service_use",
                ip_address=None,
                user_agent=None,
                consent_version="1.0",
            )

    def test_invalid_purpose_raises_value_error(self) -> None:
        db = MagicMock()
        with pytest.raises(ValueError, match="Invalid consent purposes"):
            record_consent(
                user_id=1, purposes=["invalid_purpose"], db=db
            )

    def test_multiple_purposes_all_granted(self) -> None:
        db = MagicMock()
        with patch("app.services.consent.capture.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_repo.get_active.return_value = None
            mock_repo.grant.side_effect = [
                _make_consent_row(purpose="service_use"),
                _make_consent_row(purpose="marketing"),
            ]
            MockRepo.return_value = mock_repo

            result = record_consent(
                user_id=1, purposes=["service_use", "marketing"], db=db
            )
            assert len(result) == 2
            assert mock_repo.grant.call_count == 2

    def test_existing_consent_is_revoked_before_re_grant(self) -> None:
        """Existing active consent should be revoked before re-granting."""
        db = MagicMock()
        existing = _make_consent_row(purpose="service_use")

        with patch("app.services.consent.capture.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_repo.get_active.return_value = existing
            mock_repo.grant.return_value = _make_consent_row(purpose="service_use")
            MockRepo.return_value = mock_repo

            record_consent(user_id=1, purposes=["service_use"], db=db)
            # existing.revoked_at should have been set
            assert existing.revoked_at is not None


class TestRevokeConsent:
    """Tests for revoke_consent()."""

    def test_revoke_valid_purpose(self) -> None:
        db = MagicMock()
        with patch("app.services.consent.capture.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_row = _make_consent_row(purpose="marketing")
            mock_repo.revoke.return_value = mock_row
            MockRepo.return_value = mock_repo

            result = revoke_consent(user_id=1, purpose="marketing", db=db)
            mock_repo.revoke.assert_called_once_with(1, "marketing")

    def test_revoke_invalid_purpose_raises(self) -> None:
        db = MagicMock()
        with pytest.raises(ValueError, match="Invalid consent purpose"):
            revoke_consent(user_id=1, purpose="nonexistent_purpose", db=db)

    def test_revoke_no_active_consent_returns_none(self) -> None:
        db = MagicMock()
        with patch("app.services.consent.capture.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_repo.revoke.return_value = None
            MockRepo.return_value = mock_repo

            result = revoke_consent(user_id=1, purpose="marketing", db=db)
            assert result is None


class TestGetConsentStatus:
    """Tests for get_consent_status()."""

    def test_active_consents_shown_as_true(self) -> None:
        db = MagicMock()
        with patch("app.services.consent.capture.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_repo.list_active_for_user.return_value = [
                _make_consent_row(purpose="service_use"),
                _make_consent_row(purpose="marketing"),
            ]
            MockRepo.return_value = mock_repo

            status = get_consent_status(user_id=1, db=db)
            assert status["service_use"] is True
            assert status["marketing"] is True
            assert status["analytics"] is False

    def test_all_false_when_no_consents(self) -> None:
        db = MagicMock()
        with patch("app.services.consent.capture.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_repo.list_active_for_user.return_value = []
            MockRepo.return_value = mock_repo

            status = get_consent_status(user_id=1, db=db)
            assert all(v is False for v in status.values())


class TestDataSubjectRights:
    """Tests for DSR export and deletion scheduling."""

    def test_export_returns_zip_bytes(self) -> None:
        from app.services.consent.dsr import export_user_data
        db = MagicMock()
        with patch("app.services.consent.dsr.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_repo.list_all_for_user.return_value = []
            MockRepo.return_value = mock_repo

            result = export_user_data(user_id=42, db=db)
            assert result.job_id.startswith("dsr-export-")
            assert len(result.zip_bytes) > 0
            assert result.expires_at != ""

    def test_export_zip_contains_expected_files(self) -> None:
        import io
        import zipfile

        from app.services.consent.dsr import export_user_data
        db = MagicMock()
        with patch("app.services.consent.dsr.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_repo.list_all_for_user.return_value = []
            MockRepo.return_value = mock_repo

            result = export_user_data(user_id=42, db=db)
            with zipfile.ZipFile(io.BytesIO(result.zip_bytes)) as zf:
                names = zf.namelist()
            assert "consents.json" in names
            assert "metadata.json" in names
            assert "profile.json" in names

    def test_deletion_sets_legal_hold_on_consents(self) -> None:
        from app.services.consent.dsr import request_user_deletion
        db = MagicMock()
        consent_row = MagicMock()
        consent_row.legal_hold = False

        with patch("app.services.consent.dsr.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_repo.list_all_for_user.return_value = [consent_row]
            MockRepo.return_value = mock_repo

            result = request_user_deletion(user_id=42, db=db)
            assert consent_row.legal_hold is True
            # Message should mention financial record retention
            assert "7 year" in result.message or "tax" in result.message.lower()

    def test_deletion_schedule_is_30_days_from_now(self) -> None:
        from app.services.consent.dsr import _DELETION_GRACE_DAYS, request_user_deletion
        db = MagicMock()
        with patch("app.services.consent.dsr.JpUserConsentRepository") as MockRepo:
            mock_repo = MagicMock()
            mock_repo.list_all_for_user.return_value = []
            MockRepo.return_value = mock_repo

            result = request_user_deletion(user_id=42, db=db)
            assert _DELETION_GRACE_DAYS == 30
            # Verify the ISO string is in the future (roughly 30 days)
            from datetime import datetime, timezone
            scheduled = datetime.fromisoformat(result.scheduled_purge_at)
            now = datetime.now(timezone.utc)
            diff = scheduled - now
            # Should be between 29 and 31 days (allow for test execution time)
            assert 28 <= diff.days <= 31
