"""Phase 07 AC4 — BA D10 rigid 24h cancel policy.

>24h before check-in → 100% refund
0–24h before check-in → 50% refund
After check-in → 0% refund
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from tests.homestay.conftest import make_reservation  # noqa: E402


def _check_in_iso(now: datetime, hours_ahead: float) -> str:
    return (now + timedelta(hours=hours_ahead)).date().isoformat()


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cancel_more_than_24h_before_full_refund(pg_session, seeded_homestay):
    """Cancel when check-in is 48h away → refund 100% of total."""
    from app.services import reservation_service

    # Reservation 2026-07-15 → 2026-07-17, cancelled at 2026-07-13 00:00:00 (48h before).
    res = make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-15",
        check_out="2026-07-17",
        status="approved",
        total=2_000_000,
    )
    now = datetime(2026, 7, 13, 0, 0, 0)  # exactly 48h before 2026-07-15 00:00
    res = reservation_service.cancel(
        pg_session,
        host_id=seeded_homestay["host_id"],
        reservation_id=res.id,
        actor_id=seeded_homestay["host_id"],
        now=now,
    )
    assert res.status == "cancelled"
    assert res.refund_amount == 2_000_000.0


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cancel_within_24h_half_refund(pg_session, seeded_homestay):
    """Cancel when check-in is 12h away → refund 50%."""
    from app.services import reservation_service

    res = make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-15",
        check_out="2026-07-17",
        status="approved",
        total=2_000_000,
    )
    now = datetime(2026, 7, 14, 12, 0, 0)  # 12h before 2026-07-15
    res = reservation_service.cancel(
        pg_session,
        host_id=seeded_homestay["host_id"],
        reservation_id=res.id,
        actor_id=seeded_homestay["host_id"],
        now=now,
    )
    assert res.refund_amount == 1_000_000.0


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cancel_after_check_in_no_refund(pg_session, seeded_homestay):
    """Cancel once checked_in → 0% refund regardless of clock."""
    from app.services import reservation_service

    res = make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-15",
        check_out="2026-07-17",
        status="checked_in",
        total=2_000_000,
    )
    now = datetime(2026, 7, 15, 14, 0, 0)  # already after check-in
    res = reservation_service.cancel(
        pg_session,
        host_id=seeded_homestay["host_id"],
        reservation_id=res.id,
        actor_id=seeded_homestay["host_id"],
        now=now,
    )
    assert res.refund_amount == 0.0
