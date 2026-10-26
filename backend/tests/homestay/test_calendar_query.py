"""Phase 07 AC1 — calendar query yields one row per day with status + price.

July 2026 has 31 days. A reservation on 2026-07-20..22 occupies 2 nights
(20, 21) — the 22 is the check-out day and remains available. The price
must reflect base/weekend/holiday/manual resolution.
"""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from tests.homestay.conftest import make_reservation  # noqa: E402


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_calendar_yields_31_days_for_july(pg_session, seeded_homestay):
    from app.services import availability_service

    result = availability_service.get_calendar(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        month="2026-07",
    )
    assert result["month"] == "2026-07"
    assert len(result["days"]) == 31
    # Day 1 sanity
    first = result["days"][0]
    assert first["date"] == "2026-07-01"
    assert first["status"] == "available"
    assert first["price_per_night"] > 0


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_calendar_shows_reserved_nights(pg_session, seeded_homestay):
    """[20, 22) means days 20 and 21 are 'reserved'; day 22 is 'available'."""
    from app.services import availability_service

    res = make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-20",
        check_out="2026-07-22",
        status="approved",
    )

    result = availability_service.get_calendar(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        month="2026-07",
    )
    by_date = {d["date"]: d for d in result["days"]}
    assert by_date["2026-07-20"]["status"] == "reserved"
    assert by_date["2026-07-20"]["reservation_id"] == res.id
    assert by_date["2026-07-21"]["status"] == "reserved"
    assert by_date["2026-07-22"]["status"] == "available"


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_calendar_price_reflects_priority(pg_session, seeded_homestay):
    """2026-07-04 (Sat + holiday + manual override) → 1.5M per the seed."""
    from app.services import availability_service

    result = availability_service.get_calendar(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        month="2026-07",
    )
    by_date = {d["date"]: d for d in result["days"]}
    assert by_date["2026-07-04"]["price_per_night"] == 1_500_000
    # Tuesday 2026-07-07 → base only
    assert by_date["2026-07-07"]["price_per_night"] == 500_000
    # Friday 2026-07-10 → weekend
    assert by_date["2026-07-10"]["price_per_night"] == 700_000
