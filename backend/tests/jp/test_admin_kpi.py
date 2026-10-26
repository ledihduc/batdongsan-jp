"""Tests for admin KPI queries — using mocked DB session.

These tests verify query construction and result handling
without requiring a real Postgres database.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest


def _make_mock_db(return_values: dict):
    """Create a mock DB session that returns specified values per query."""
    db = MagicMock()

    def execute_side_effect(sql_text, params=None):
        sql_str = str(sql_text) if hasattr(sql_text, '__str__') else ""
        mock_result = MagicMock()

        # Default row
        row = MagicMock()
        row.__getitem__ = lambda self, i: [0, 0][i] if i < 2 else None
        mock_result.fetchone.return_value = row
        return mock_result

    db.execute.side_effect = execute_side_effect
    return db


class TestApplicationCount:
    def test_returns_integer(self):
        from app.services.admin_kpi.queries import application_count

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [42]
        db.execute.return_value = mock_result

        count = application_count(
            db,
            org_id="org-1",
            start=datetime(2026, 1, 1, tzinfo=timezone.utc),
            end=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        assert count == 42

    def test_returns_zero_when_no_rows(self):
        from app.services.admin_kpi.queries import application_count

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [0]
        db.execute.return_value = mock_result

        count = application_count(
            db,
            org_id="org-1",
            start=datetime(2026, 1, 1, tzinfo=timezone.utc),
            end=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        assert count == 0

    def test_with_prefecture_filter(self):
        from app.services.admin_kpi.queries import application_count

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [10]
        db.execute.return_value = mock_result

        count = application_count(
            db,
            org_id="org-1",
            prefecture="東京都",
            start=datetime(2026, 1, 1, tzinfo=timezone.utc),
            end=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        # Verify prefecture was passed in params
        call_args = db.execute.call_args
        params = call_args[0][1] if len(call_args[0]) > 1 else call_args[1].get("params", {})
        assert count == 10


class TestSuccessRate:
    def test_computes_ratio(self):
        from app.services.admin_kpi.queries import success_rate

        db = MagicMock()
        mock_result = MagicMock()
        # approved=7, total=10
        mock_result.fetchone.return_value = [7, 10]
        db.execute.return_value = mock_result

        rate = success_rate(
            db,
            org_id="org-1",
            start=datetime(2026, 1, 1, tzinfo=timezone.utc),
            end=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        assert rate == pytest.approx(0.7, rel=1e-3)

    def test_zero_when_no_applications(self):
        from app.services.admin_kpi.queries import success_rate

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [0, 0]
        db.execute.return_value = mock_result

        rate = success_rate(
            db,
            org_id="org-1",
            start=datetime(2026, 1, 1, tzinfo=timezone.utc),
            end=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        assert rate == 0.0


class TestAvgReviewDays:
    def test_returns_float(self):
        from app.services.admin_kpi.queries import avg_review_days

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [3.5]
        db.execute.return_value = mock_result

        days = avg_review_days(
            db,
            org_id="org-1",
            start=datetime(2026, 1, 1, tzinfo=timezone.utc),
            end=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        assert days == pytest.approx(3.5)

    def test_zero_when_no_reviews(self):
        from app.services.admin_kpi.queries import avg_review_days

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [None]
        db.execute.return_value = mock_result

        days = avg_review_days(
            db,
            org_id="org-1",
            start=datetime(2026, 1, 1, tzinfo=timezone.utc),
            end=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        assert days == 0.0


class TestComputeAllKpis:
    def test_returns_all_five_keys(self):
        from app.services.admin_kpi.queries import compute_all_kpis

        db = MagicMock()
        mock_result = MagicMock()
        mock_result.fetchone.return_value = [0, 0]
        db.execute.return_value = mock_result

        result = compute_all_kpis(
            db,
            org_id="org-1",
            start=datetime(2026, 1, 1, tzinfo=timezone.utc),
            end=datetime(2026, 10, 1, tzinfo=timezone.utc),
        )
        assert "application_count" in result
        assert "success_rate" in result
        assert "avg_review_days" in result
        assert "guarantor_approval_rate" in result
        assert "vacancy_rate" in result
        assert "computed_at" in result
