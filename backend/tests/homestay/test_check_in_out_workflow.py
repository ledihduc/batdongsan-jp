"""Phase 07 AC5 — reservation state machine + khai báo auto-create.

Lifecycle:
    pending → approved → checked_in → checked_out
                ↓
            rejected | cancelled

Invalid transitions raise HTTP 400. check_in() must auto-create a
KhaiBaoTamTru row for the homestay guest.
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
def test_full_happy_path(pg_session, seeded_homestay):
    """pending → approved → checked_in → checked_out."""
    from app.services import reservation_service

    res = make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-20",
        check_out="2026-07-22",
        status="pending",
    )
    host_id = seeded_homestay["host_id"]

    res = reservation_service.approve(pg_session, host_id, res.id, actor_id=host_id)
    assert res.status == "approved"

    res = reservation_service.check_in(pg_session, host_id, res.id, actor_id=host_id)
    assert res.status == "checked_in"

    res = reservation_service.check_out(pg_session, host_id, res.id, actor_id=host_id)
    assert res.status == "checked_out"


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_check_in_creates_khai_bao(pg_session, seeded_homestay):
    """check_in() must auto-create a KhaiBaoTamTru row tied to reservation_id."""
    from app import models
    from app.services import reservation_service

    res = make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-20",
        check_out="2026-07-22",
        status="approved",
    )
    host_id = seeded_homestay["host_id"]

    reservation_service.check_in(pg_session, host_id, res.id, actor_id=host_id)

    kb = (
        pg_session.query(models.KhaiBaoTamTru)
        .filter(models.KhaiBaoTamTru.reservation_id == res.id)
        .first()
    )
    assert kb is not None
    assert kb.status == "pending"
    assert kb.public_token is not None


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cannot_check_in_pending(pg_session, seeded_homestay):
    """Only approved reservations can transition to checked_in."""
    from app.services import reservation_service

    res = make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-20",
        check_out="2026-07-22",
        status="pending",
    )
    host_id = seeded_homestay["host_id"]
    with pytest.raises(HTTPException) as ei:
        reservation_service.check_in(pg_session, host_id, res.id, actor_id=host_id)
    assert ei.value.status_code == 400


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cannot_approve_rejected(pg_session, seeded_homestay):
    """Approve only valid on pending — rejected is terminal."""
    from app.services import reservation_service

    res = make_reservation(
        pg_session,
        host_id=seeded_homestay["host_id"],
        room_id=seeded_homestay["room_id"],
        check_in="2026-07-20",
        check_out="2026-07-22",
        status="rejected",
    )
    host_id = seeded_homestay["host_id"]
    with pytest.raises(HTTPException) as ei:
        reservation_service.approve(pg_session, host_id, res.id, actor_id=host_id)
    assert ei.value.status_code == 400
