"""Phase 08 AC5 — marketplace-sourced Reservation can be approved via shortcut.

Approve-from-booking endpoint validates source=='marketplace' and proxies to
reservation_service.approve.
"""

from __future__ import annotations

import os

import pytest
from fastapi import HTTPException

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from tests.marketplace.conftest import make_reservation  # noqa: E402


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_approve_marketplace_reservation(pg_session, seeded_marketplace):
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    room_id = seeded_marketplace["room_hs_id"]
    res = make_reservation(
        pg_session, host_id=host_id, room_id=room_id, source="marketplace"
    )

    approved = marketplace_sync_service.approve_reservation_from_booking(
        pg_session, host_id=host_id, reservation_id=res.id, actor_id=host_id
    )
    pg_session.flush()

    assert approved.status == "approved"
    assert approved.source == "marketplace"


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cannot_approve_manual_reservation_via_marketplace_endpoint(
    pg_session, seeded_marketplace
):
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    room_id = seeded_marketplace["room_hs_id"]
    res = make_reservation(
        pg_session, host_id=host_id, room_id=room_id, source="manual"
    )

    with pytest.raises(HTTPException) as exc:
        marketplace_sync_service.approve_reservation_from_booking(
            pg_session, host_id=host_id, reservation_id=res.id, actor_id=host_id
        )
    assert exc.value.status_code == 400
    assert "marketplace" in exc.value.detail.lower()


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cross_host_reservation_rejected(pg_session, seeded_marketplace):
    from app import auth, models
    from app.services import marketplace_sync_service
    from datetime import datetime

    host_a = seeded_marketplace["host_id"]
    room_id = seeded_marketplace["room_hs_id"]
    res = make_reservation(
        pg_session, host_id=host_a, room_id=room_id, source="marketplace"
    )

    host_b = models.User(
        name="Host B",
        email=f"host_b_{os.urandom(4).hex()}@test.com",
        password_hash=auth.hash_password("pass"),
        role="host",
        is_active=True,
        created_at=datetime.utcnow(),
    )
    pg_session.add(host_b)
    pg_session.flush()

    with pytest.raises(HTTPException) as exc:
        marketplace_sync_service.approve_reservation_from_booking(
            pg_session, host_id=host_b.id, reservation_id=res.id, actor_id=host_b.id
        )
    assert exc.value.status_code == 404
