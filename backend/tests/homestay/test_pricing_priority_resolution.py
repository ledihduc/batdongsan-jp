"""Phase 07 AC2 — pricing rule resolution by priority.

base < weekend < holiday < manual. The highest priority rule that *applies*
on the given date wins. A rule "applies" iff its date range covers the day
AND (for weekend rules) the weekday bit is set.
"""

from __future__ import annotations

import os
from datetime import date

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_base_price_on_weekday(pg_session, seeded_homestay):
    """Tuesday 2026-07-07 → no weekend, no holiday, no manual → base 500K."""
    from app import models
    from app.services import pricing_service

    room = pg_session.get(models.Room, seeded_homestay["room_id"])
    price = pricing_service.resolve_price(
        pg_session, seeded_homestay["host_id"], room, date(2026, 7, 7)
    )
    assert price == 500_000


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_weekend_price_on_friday(pg_session, seeded_homestay):
    """Friday 2026-07-10 → weekend rule wins (priority 200) → 700K."""
    from app import models
    from app.services import pricing_service

    room = pg_session.get(models.Room, seeded_homestay["room_id"])
    # 2026-07-10 is a Friday.
    assert date(2026, 7, 10).weekday() == 4  # sanity
    price = pricing_service.resolve_price(
        pg_session, seeded_homestay["host_id"], room, date(2026, 7, 10)
    )
    assert price == 700_000


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_manual_overrides_holiday_overrides_weekend(pg_session, seeded_homestay):
    """2026-07-04 is Saturday + holiday + manual override → manual wins (1.5M)."""
    from app import models
    from app.services import pricing_service

    room = pg_session.get(models.Room, seeded_homestay["room_id"])
    # Sanity: 2026-07-04 is a Saturday.
    assert date(2026, 7, 4).weekday() == 5
    price = pricing_service.resolve_price(
        pg_session, seeded_homestay["host_id"], room, date(2026, 7, 4)
    )
    assert price == 1_500_000
