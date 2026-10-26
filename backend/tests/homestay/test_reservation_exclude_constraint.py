"""Phase 01h — DB-level concurrency hardening.

These tests prove that the EXCLUDE USING gist constraint installed by
migration `0011_excl_reservation_overlap` rejects overlapping
reservations at the database layer, independent of the service-level
`find_overlapping` check inside `create_reservation`.

Approach:
    Use raw `INSERT INTO reservations ...` SQL to bypass the service
    layer's app-level guard. Wrap each second-insert in a SAVEPOINT so
    that an IntegrityError on the constraint does not corrupt the
    outer pg_session transaction (the fixture rolls that back at
    test end).

Skips cleanly when SMOKE_DATABASE_URL is unset (CI sets it).
"""

from __future__ import annotations

import os

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


CONSTRAINT_NAME = "excl_reservations_room_overlap"


def _raw_insert_reservation(
    session,
    *,
    host_id: int,
    room_id: int,
    check_in: str,
    check_out: str,
    status: str,
):
    """Bypass ORM + service overlap check — INSERT directly via SQL."""
    # source_id NOT NULL từ migration 0018 → resolve qua source_service.
    from app.services import source_service
    source_id = source_service.resolve_default_source_id(session, host_id, "direct")
    session.execute(
        text(
            """
            INSERT INTO reservations
                (host_id, room_id, guest_name, guest_phone,
                 check_in_date, check_out_date, nights, total_amount,
                 status, source_id, created_at, updated_at)
            VALUES
                (:host_id, :room_id, 'Raw Test', '0900000000',
                 :ci, :co, 1, 1000000,
                 :status, :source_id, NOW(), NOW())
            """
        ),
        {
            "host_id": host_id,
            "room_id": room_id,
            "ci": check_in,
            "co": check_out,
            "status": status,
            "source_id": source_id,
        },
    )


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_constraint_rejects_overlap_with_pending(pg_session, seeded_homestay):
    """Two overlapping pending reservations → DB rejects the second."""
    host_id = seeded_homestay["host_id"]
    room_id = seeded_homestay["room_id"]

    _raw_insert_reservation(
        pg_session,
        host_id=host_id, room_id=room_id,
        check_in="2026-07-10", check_out="2026-07-13",
        status="pending",
    )
    pg_session.flush()

    sp = pg_session.begin_nested()
    with pytest.raises(IntegrityError) as exc_info:
        _raw_insert_reservation(
            pg_session,
            host_id=host_id, room_id=room_id,
            check_in="2026-07-12", check_out="2026-07-15",
            status="pending",
        )
        pg_session.flush()
    sp.rollback()

    assert CONSTRAINT_NAME in str(exc_info.value).lower() \
        or "exclude" in str(exc_info.value).lower()


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_constraint_rejects_overlap_with_approved(pg_session, seeded_homestay):
    """Overlap with an approved reservation also rejected at DB layer."""
    host_id = seeded_homestay["host_id"]
    room_id = seeded_homestay["room_id"]

    _raw_insert_reservation(
        pg_session,
        host_id=host_id, room_id=room_id,
        check_in="2026-08-01", check_out="2026-08-05",
        status="approved",
    )
    pg_session.flush()

    sp = pg_session.begin_nested()
    with pytest.raises(IntegrityError):
        _raw_insert_reservation(
            pg_session,
            host_id=host_id, room_id=room_id,
            check_in="2026-08-04", check_out="2026-08-07",
            status="pending",
        )
        pg_session.flush()
    sp.rollback()


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_constraint_allows_overlap_when_existing_cancelled(
    pg_session, seeded_homestay,
):
    """Cancelled reservations are excluded from the predicate — overlap OK."""
    host_id = seeded_homestay["host_id"]
    room_id = seeded_homestay["room_id"]

    _raw_insert_reservation(
        pg_session,
        host_id=host_id, room_id=room_id,
        check_in="2026-09-10", check_out="2026-09-13",
        status="cancelled",
    )
    pg_session.flush()

    _raw_insert_reservation(
        pg_session,
        host_id=host_id, room_id=room_id,
        check_in="2026-09-12", check_out="2026-09-15",
        status="pending",
    )
    pg_session.flush()

    row_count = pg_session.execute(
        text("SELECT COUNT(*) FROM reservations WHERE room_id = :rid"),
        {"rid": room_id},
    ).scalar()
    assert row_count >= 2


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_constraint_allows_back_to_back_same_day(pg_session, seeded_homestay):
    """Range bound '[)' — guest A check-out = guest B check-in same day OK."""
    host_id = seeded_homestay["host_id"]
    room_id = seeded_homestay["room_id"]

    _raw_insert_reservation(
        pg_session,
        host_id=host_id, room_id=room_id,
        check_in="2026-10-01", check_out="2026-10-05",
        status="approved",
    )
    pg_session.flush()

    _raw_insert_reservation(
        pg_session,
        host_id=host_id, room_id=room_id,
        check_in="2026-10-05", check_out="2026-10-08",
        status="pending",
    )
    pg_session.flush()  # Should NOT raise.
