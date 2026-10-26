"""Unit tests for JP compliance evidence service.

Tests verify query aggregation logic using mocked DB sessions.
No real DB required — uses MagicMock with controlled return values.

Pattern: same as test_admin_kpi.py — mock execute() return values per query.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock, call, patch

import pytest


def _make_mock_db(query_results: list) -> MagicMock:
    """Create a mock DB that returns results in order for each execute() call.

    Args:
        query_results: list of values returned by fetchone() per call, in order.
                       Each element is either a list/tuple row or None.
    """
    db = MagicMock()
    call_index = {"i": 0}

    def execute_side_effect(sql_text, params=None):
        idx = call_index["i"]
        call_index["i"] += 1
        mock_result = MagicMock()
        if idx < len(query_results):
            mock_result.fetchone.return_value = query_results[idx]
            mock_result.fetchall.return_value = (
                [query_results[idx]] if query_results[idx] else []
            )
        else:
            mock_result.fetchone.return_value = None
            mock_result.fetchall.return_value = []
        return mock_result

    db.execute.side_effect = execute_side_effect
    return db


class TestCountAppiConsentedUsers:
    def test_returns_count(self):
        from app.services.compliance.evidence import _count_appi_consented_users

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [99]
        db.execute.return_value = mock_result

        count = _count_appi_consented_users(db)
        assert count == 99

    def test_returns_zero_when_no_rows(self):
        from app.services.compliance.evidence import _count_appi_consented_users

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [0]
        db.execute.return_value = mock_result

        count = _count_appi_consented_users(db)
        assert count == 0

    def test_returns_zero_on_exception(self):
        from app.services.compliance.evidence import _count_appi_consented_users

        db = MagicMock()
        db.execute.side_effect = Exception("table missing")

        count = _count_appi_consented_users(db)
        assert count == 0


class TestGetLastDeletionCronInfo:
    def test_reads_from_cron_log_table(self):
        from app.services.compliance.evidence import _get_last_deletion_cron_info

        ran_at = datetime(2026, 10, 16, 18, 0, 0, tzinfo=timezone.utc)
        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = (ran_at, 5)
        db.execute.return_value = mock_result

        last_run, count = _get_last_deletion_cron_info(db)
        assert last_run is not None
        assert "2026-10-16" in last_run
        assert count == 5

    def test_returns_none_when_cron_log_missing_and_no_users(self):
        from app.services.compliance.evidence import _get_last_deletion_cron_info

        db = MagicMock()
        # Both queries fail or return None
        db.execute.side_effect = Exception("table missing")

        last_run, count = _get_last_deletion_cron_info(db)
        assert last_run is None
        assert count == 0

    def test_returns_zero_count_when_no_data(self):
        from app.services.compliance.evidence import _get_last_deletion_cron_info

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = None
        db.execute.return_value = mock_result

        last_run, count = _get_last_deletion_cron_info(db)
        assert count == 0


class TestGetPiiKeyRotationDate:
    def test_returns_date_string(self):
        from app.services.compliance.evidence import _get_pii_key_rotation_date

        rotated = datetime(2026, 9, 1, 12, 0, 0, tzinfo=timezone.utc)
        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = (rotated,)
        db.execute.return_value = mock_result

        date_str = _get_pii_key_rotation_date(db)
        assert date_str == "2026-09-01"

    def test_returns_none_when_no_rotations(self):
        from app.services.compliance.evidence import _get_pii_key_rotation_date

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = (None,)
        db.execute.return_value = mock_result

        date_str = _get_pii_key_rotation_date(db)
        assert date_str is None

    def test_returns_none_when_table_missing(self):
        from app.services.compliance.evidence import _get_pii_key_rotation_date

        db = MagicMock()
        db.execute.side_effect = Exception("table pii_key_rotation_log not found")

        date_str = _get_pii_key_rotation_date(db)
        assert date_str is None


class TestGetHmacRotationLedger:
    def test_returns_empty_when_both_tables_missing(self):
        from app.services.compliance.evidence import _get_hmac_rotation_ledger

        db = MagicMock()
        db.execute.side_effect = Exception("table missing")

        entries = _get_hmac_rotation_ledger(db)
        assert entries == []

    def test_returns_entries_from_rotation_table(self):
        from app.services.compliance.evidence import _get_hmac_rotation_ledger

        rotated = datetime(2026, 9, 15, 10, 0, 0, tzinfo=timezone.utc)
        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchall.return_value = [
            ("org-shinjuku-001", rotated, 2),
        ]
        db.execute.return_value = mock_result

        entries = _get_hmac_rotation_ledger(db)
        assert len(entries) == 1
        assert entries[0].org_id == "org-shinjuku-001"
        assert entries[0].rotation_count == 2
        assert "2026-09-15" in entries[0].rotated_at


class TestBuildComplianceEvidence:
    def test_returns_all_fields(self):
        from app.services.compliance.evidence import build_compliance_evidence

        db = MagicMock()
        # All queries return safe defaults
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [42]
        mock_result.fetchall.return_value = []
        db.execute.return_value = mock_result

        evidence = build_compliance_evidence(db)

        assert hasattr(evidence, "appi_consented_users_count")
        assert hasattr(evidence, "last_deletion_cron_run")
        assert hasattr(evidence, "last_deletion_purged_count")
        assert hasattr(evidence, "pii_key_rotation_date")
        assert hasattr(evidence, "hmac_rotation_ledger")
        assert hasattr(evidence, "generated_at")
        assert evidence.generated_at is not None

    def test_graceful_on_all_errors(self):
        """Evidence service must not raise even if all DB queries fail."""
        from app.services.compliance.evidence import build_compliance_evidence

        db = MagicMock()
        db.execute.side_effect = Exception("DB unavailable")

        # Should not raise — partial data with zeros/nulls is acceptable
        evidence = build_compliance_evidence(db)
        assert evidence.appi_consented_users_count == 0
        assert evidence.last_deletion_cron_run is None
        assert evidence.last_deletion_purged_count == 0

    def test_consent_count_nonzero_propagated(self):
        """Consent count from DB is reflected in response."""
        from app.services.compliance.evidence import build_compliance_evidence

        db = MagicMock()
        call_n = {"i": 0}

        def side_effect(sql, params=None):
            r = MagicMock()
            i = call_n["i"]
            call_n["i"] += 1
            if i == 0:
                # appi count query
                r.fetchone.return_value = [123]
            else:
                r.fetchone.return_value = None
            r.fetchall.return_value = []
            return r

        db.execute.side_effect = side_effect

        evidence = build_compliance_evidence(db)
        assert evidence.appi_consented_users_count == 123
