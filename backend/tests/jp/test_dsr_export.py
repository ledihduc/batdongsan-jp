"""Tests for real DSR cross-domain exporter.

Tests the collect() aggregator function.
All DB calls are mocked — no real DB required.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest


class TestDsrCollect:
    """Tests for privacy.dsr_exporter.collect()."""

    def _make_db_with_profile(self, user_id=42, email="test@example.com"):
        db = MagicMock()

        def execute_side(query, params=None):
            result = MagicMock()
            sql_str = str(query)

            if "FROM users" in sql_str:
                row = [user_id, email, "09011112222", "太郎", "山田",
                       datetime(2025, 1, 1, tzinfo=timezone.utc),
                       datetime(2025, 6, 1, tzinfo=timezone.utc), None]
                result.fetchone.return_value = row
            else:
                result.fetchall.return_value = []
                result.fetchone.return_value = None

            return result

        db.execute.side_effect = execute_side
        return db

    def test_collect_returns_all_sections(self):
        from app.services.privacy.dsr_exporter import collect

        db = self._make_db_with_profile()

        with patch("app.services.privacy.dsr_exporter._collect_consents", return_value=[]):
            with patch("app.services.privacy.dsr_exporter._collect_viewings", return_value=[]):
                with patch("app.services.privacy.dsr_exporter._collect_applications", return_value=[]):
                    with patch("app.services.privacy.dsr_exporter._collect_payments", return_value=[]):
                        with patch("app.services.privacy.dsr_exporter._collect_owned_listings", return_value=[]):
                            result = collect(user_id=42, org_id="org-abc", db=db)

        assert "profile" in result
        assert "consents" in result
        assert "viewings" in result
        assert "applications" in result
        assert "payments" in result
        assert "listings" in result
        assert "metadata" in result

    def test_metadata_has_correct_fields(self):
        from app.services.privacy.dsr_exporter import collect

        db = self._make_db_with_profile()

        with patch("app.services.privacy.dsr_exporter._collect_consents", return_value=[]):
            with patch("app.services.privacy.dsr_exporter._collect_viewings", return_value=[]):
                with patch("app.services.privacy.dsr_exporter._collect_applications", return_value=[]):
                    with patch("app.services.privacy.dsr_exporter._collect_payments", return_value=[]):
                        with patch("app.services.privacy.dsr_exporter._collect_owned_listings", return_value=[]):
                            result = collect(user_id=42, org_id="org-abc", db=db)

        meta = result["metadata"]
        assert meta["user_id"] == 42
        assert meta["org_id"] == "org-abc"
        assert meta["format_version"] == "2.0"
        assert meta["appi_retention_years"] == 2
        assert "export_generated_at" in meta

    def test_profile_section_has_email(self):
        from app.services.privacy.dsr_exporter import _collect_profile

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [
            42, "test@example.com", "09011112222", "太郎", "山田",
            datetime(2025, 1, 1, tzinfo=timezone.utc),
            datetime(2025, 6, 1, tzinfo=timezone.utc), None,
        ]
        db.execute.return_value = mock_result

        profile = _collect_profile(42, db)
        assert profile["email"] == "test@example.com"
        assert profile["user_id"] == 42

    def test_profile_not_found_returns_not_found(self):
        from app.services.privacy.dsr_exporter import _collect_profile

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = None
        db.execute.return_value = mock_result

        profile = _collect_profile(999, db)
        assert profile["found"] is False

    def test_iso_helper_handles_none(self):
        from app.services.privacy.dsr_exporter import _iso

        assert _iso(None) is None

    def test_iso_helper_handles_datetime(self):
        from app.services.privacy.dsr_exporter import _iso

        dt = datetime(2026, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
        result = _iso(dt)
        assert "2026-01-01" in result

    def test_section_error_returns_empty_list(self):
        """If a section query fails, return empty list (not crash)."""
        from app.services.privacy.dsr_exporter import _collect_viewings

        db = MagicMock()
        db.execute.side_effect = Exception("DB error")

        result = _collect_viewings(42, "org-abc", datetime.now(timezone.utc), db)
        assert result == []
