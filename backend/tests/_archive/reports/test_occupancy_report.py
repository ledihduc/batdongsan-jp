"""Phase 06 AC2 — occupancy = occupied rooms / total rooms × 100."""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_occupancy_three_of_five_rooms_occupied(pg_session, seeded_reports):
    from app.services import report_service

    result = report_service.occupancy_report(
        pg_session, seeded_reports["host_id"], None, "2026-07"
    )
    assert result["month"] == "2026-07"
    assert result["room_count"] == 5
    # 3 occupied / 5 total = 60%
    assert result["building_avg_pct"] == 60.0
    occupied_rows = [r for r in result["by_room"] if r["status"] == "occupied"]
    assert len(occupied_rows) == 3
    assert all(r["occupied_pct"] == 100.0 for r in occupied_rows)


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_occupancy_invalid_month_raises(pg_session, seeded_reports):
    from app.services import report_service

    with pytest.raises(ValueError):
        report_service.occupancy_report(
            pg_session, seeded_reports["host_id"], None, "not-a-date"
        )


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_occupancy_building_filter(pg_session, seeded_reports):
    from app.services import report_service

    result = report_service.occupancy_report(
        pg_session, seeded_reports["host_id"], seeded_reports["building_id"], "2026-07"
    )
    assert result["room_count"] == 5
    # Filtering for an unrelated building → zero rooms.
    result_empty = report_service.occupancy_report(
        pg_session, seeded_reports["host_id"], 99999, "2026-07"
    )
    assert result_empty["room_count"] == 0
    assert result_empty["building_avg_pct"] == 0
