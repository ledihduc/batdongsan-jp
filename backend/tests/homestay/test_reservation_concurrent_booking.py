"""Phase 07 AC3 — concurrent-booking overlap rejection.

On SQLite/Postgres without the EXCLUDE constraint (Phase 01), the
app-level `find_overlapping` query inside `create_reservation` is the
only guard. This test documents the *intended* behaviour: a second
booking that overlaps an existing one in any active status raises 409.

NOTE: this test does NOT prove race-condition safety under true
concurrent writers — that requires the Postgres exclusion constraint
(deferred to Phase 01). It only verifies the in-transaction check.
"""

from __future__ import annotations

import os

import pytest
from fastapi import HTTPException

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from tests.homestay.conftest import make_reservation  # noqa: E402


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_overlap_with_pending_reservation_rejected(pg_session, seeded_homestay):
    """An overlapping booking against a pending reservation → HTTP 409."""
    from app.services import reservation_service

    make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-10",
        check_out="2026-07-12",
        status="pending",
    )

    payload = {
        "room_id": seeded_homestay["room_id"],
        "guest_name": "Khách B",
        "guest_phone": "0900000002",
        "check_in_date": "2026-07-11",   # overlaps existing [10,12)
        "check_out_date": "2026-07-13",
    }
    with pytest.raises(HTTPException) as ei:
        reservation_service.create_reservation(
            pg_session,
            host_id=seeded_homestay["host_id"],
            payload=payload,
            actor_id=seeded_homestay["host_id"],
        )
    assert ei.value.status_code == 409


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_adjacent_ranges_allowed(pg_session, seeded_homestay):
    """Check-out exclusive: [10,12) and [12,14) do NOT overlap."""
    from app.services import reservation_service

    make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-10",
        check_out="2026-07-12",
        status="approved",
    )

    payload = {
        "room_id": seeded_homestay["room_id"],
        "guest_name": "Khách C",
        "guest_phone": "0900000003",
        "check_in_date": "2026-07-12",
        "check_out_date": "2026-07-14",
    }
    res = reservation_service.create_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        payload=payload,
        actor_id=seeded_homestay["host_id"],
    )
    assert res.id is not None
    assert res.status == "pending"


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cancelled_reservation_does_not_block(pg_session, seeded_homestay):
    """A cancelled reservation should NOT block a new booking on same dates."""
    from app.services import reservation_service

    make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-10",
        check_out="2026-07-12",
        status="cancelled",
    )

    payload = {
        "room_id": seeded_homestay["room_id"],
        "guest_name": "Khách D",
        "guest_phone": "0900000004",
        "check_in_date": "2026-07-10",
        "check_out_date": "2026-07-12",
    }
    res = reservation_service.create_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        payload=payload,
        actor_id=seeded_homestay["host_id"],
    )
    assert res.status == "pending"
