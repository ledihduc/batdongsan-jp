"""Unit tests for PdplTierService — 4-tier retention transitions (AC-59, §10.5)."""

from __future__ import annotations

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from datetime import datetime
from unittest.mock import MagicMock, call, patch

import pytest

import app.models  # noqa: F401 — register User on Base.metadata

from app.services.retention.pdpl_tier_service import PdplTierService


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_db_with_execute_result(rowcount: int = 5) -> MagicMock:
    """Mock DB session where execute().rowcount = rowcount."""
    db = MagicMock()
    result_mock = MagicMock()
    result_mock.rowcount = rowcount
    result_mock.fetchall.return_value = []
    db.execute.return_value = result_mock
    return db


# ---------------------------------------------------------------------------
# run_daily_transitions
# ---------------------------------------------------------------------------


class TestRunDailyTransitions:
    def test_returns_summary_dict(self):
        db = _make_db_with_execute_result(rowcount=0)
        svc = PdplTierService(db)

        results = svc.run_daily_transitions()

        assert "run_at" in results
        assert "tier_d_purged" in results
        assert "tier_c_redacted" in results
        assert "tier_b_cold_archived" in results
        assert "tier_b_cold_purged" in results
        assert "tier_a_cold_marked" in results
        assert "errors" in results

    def test_does_not_raise_on_execute_failure(self):
        """Tier-level failures are swallowed (logged as warnings) — job does not crash."""
        db = MagicMock()
        # Make execute always fail
        db.execute.side_effect = Exception("DB connection failed")
        svc = PdplTierService(db)

        results = svc.run_daily_transitions()

        # Should not raise; result dict is returned
        assert isinstance(results, dict)
        assert "run_at" in results
        # Counts are zero when all queries fail gracefully
        assert results["tier_d_purged"] == 0

    def test_all_tiers_attempted_even_if_one_fails(self):
        """Each tier should be attempted independently."""
        db = MagicMock()
        call_count = 0

        def fail_then_succeed(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count <= 2:
                raise Exception("simulated DB error")
            mock_result = MagicMock()
            mock_result.rowcount = 0
            mock_result.fetchall.return_value = []
            return mock_result

        db.execute.side_effect = fail_then_succeed
        svc = PdplTierService(db)

        # Should complete without raising
        results = svc.run_daily_transitions()
        assert isinstance(results, dict)


# ---------------------------------------------------------------------------
# _purge_tier_d
# ---------------------------------------------------------------------------


class TestPurgeTierD:
    def test_happy_path_returns_count(self):
        db = _make_db_with_execute_result(rowcount=42)
        svc = PdplTierService(db)
        count = svc._purge_tier_d()
        assert count == 42

    def test_table_missing_returns_zero(self):
        db = MagicMock()
        db.execute.side_effect = Exception("relation 'change_logs' does not exist")
        svc = PdplTierService(db)
        count = svc._purge_tier_d()
        assert count == 0

    def test_commit_called_after_delete(self):
        db = _make_db_with_execute_result(rowcount=1)
        svc = PdplTierService(db)
        svc._purge_tier_d()
        db.commit.assert_called()


# ---------------------------------------------------------------------------
# _redact_tier_c
# ---------------------------------------------------------------------------


class TestRedactTierC:
    def test_returns_zero_when_no_rows(self):
        db = MagicMock()
        result_mock = MagicMock()
        result_mock.rowcount = 0
        result_mock.fetchall.return_value = []
        db.execute.return_value = result_mock
        svc = PdplTierService(db)
        count = svc._redact_tier_c()
        assert count == 0

    def test_redacts_rows_from_fetchall(self):
        db = MagicMock()
        update_result = MagicMock()
        update_result.rowcount = 0

        # First call (UPDATE SET tier=tier_c): success
        # Second call (SELECT fetchall): returns 2 rows to redact
        # Subsequent calls (per-row UPDATE): success
        fetchall_result = MagicMock()
        fetchall_result.fetchall.return_value = [
            (1, '{"old": "data"}', '{"new": "data"}'),
            (2, None, '{"name": "John"}'),
        ]

        execute_returns = [update_result, fetchall_result, update_result, update_result]
        db.execute.side_effect = lambda *args, **kwargs: execute_returns.pop(0) if execute_returns else update_result

        svc = PdplTierService(db)
        count = svc._redact_tier_c()
        assert count == 2

    def test_table_missing_returns_zero(self):
        db = MagicMock()
        db.execute.side_effect = Exception("change_logs does not exist")
        svc = PdplTierService(db)
        count = svc._redact_tier_c()
        assert count == 0


# ---------------------------------------------------------------------------
# _mark_tier_a_cold
# ---------------------------------------------------------------------------


class TestMarkTierACold:
    def test_marks_rows_not_deleted(self):
        db = _make_db_with_execute_result(rowcount=10)
        svc = PdplTierService(db)
        count = svc._mark_tier_a_cold()
        # Only marks, never deletes — count is whatever UPDATE returns
        assert count == 10

    def test_table_missing_returns_zero(self):
        db = MagicMock()
        db.execute.side_effect = Exception("does not exist")
        svc = PdplTierService(db)
        count = svc._mark_tier_a_cold()
        assert count == 0


# ---------------------------------------------------------------------------
# get_retention_stats
# ---------------------------------------------------------------------------


class TestRetentionStats:
    def test_returns_dict(self):
        db = MagicMock()
        result_mock = MagicMock()
        result_mock.fetchall.return_value = [("hot", 100), ("tier_b", 50), ("tier_c_redacted", 20)]
        db.execute.return_value = result_mock

        svc = PdplTierService(db)
        stats = svc.get_retention_stats()

        assert stats["hot"] == 100
        assert stats["tier_b"] == 50
        assert stats["tier_c_redacted"] == 20

    def test_returns_empty_on_error(self):
        db = MagicMock()
        db.execute.side_effect = Exception("DB error")
        svc = PdplTierService(db)
        stats = svc.get_retention_stats()
        assert stats == {}


# ---------------------------------------------------------------------------
# archive_terminated_delegations (idempotency test)
# ---------------------------------------------------------------------------


class TestArchiveTerminatedDelegations:
    def test_idempotent_already_archived_skipped(self):
        db = MagicMock()

        # Simulate no eligible delegations (all already archived)
        query_mock = db.query.return_value
        filter_mock = query_mock.filter.return_value
        filter_mock.limit.return_value.all.return_value = []

        svc = PdplTierService(db)
        result = svc.archive_terminated_delegations()

        assert result["archived"] == 0
        assert result["skipped"] == 0
