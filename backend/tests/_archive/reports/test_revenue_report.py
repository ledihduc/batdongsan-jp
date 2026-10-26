"""Phase 06 AC1 — revenue report sums paid invoice line items per category."""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_revenue_month_sums_paid_invoices(pg_session, seeded_reports):
    from app.services import report_service

    result = report_service.revenue_report(
        pg_session, seeded_reports["host_id"], "month", "2026-07"
    )
    assert result["period"] == "month"
    assert result["date"] == "2026-07"
    # Two paid invoices: 4M + 3.5M = 7.5M
    assert result["total"] == 7_500_000
    assert result["breakdown"]["rent"] == 6_000_000  # 2 × 3M
    assert result["breakdown"]["electricity"] == 1_500_000  # (4M-3M) + (3.5M-3M)
    # Building grouping returns at least 1 building
    assert len(result["by_building"]) == 1


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_revenue_month_with_no_paid_returns_zero(pg_session, seeded_reports):
    from app.services import report_service

    # March 2026 has no invoices in the seed
    result = report_service.revenue_report(
        pg_session, seeded_reports["host_id"], "month", "2026-03"
    )
    assert result["total"] == 0
    assert result["breakdown"] == {}


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_revenue_year_aggregates_months(pg_session, seeded_reports):
    from app.services import report_service

    result = report_service.revenue_report(
        pg_session, seeded_reports["host_id"], "year", "2026"
    )
    assert result["period"] == "year"
    # Same as month total for 2026 in our seed (only July has paid invoices)
    assert result["total"] == 7_500_000
