"""Phase 08 AC2 — re-publishing same Room updates existing House (no duplicate).

Two sequential sync calls must result in exactly 1 House row with the latest
synced fields, not 2 rows.
"""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_double_publish_yields_one_house(pg_session, seeded_marketplace):
    from app import models
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    room_id = seeded_marketplace["room_bh_id"]

    h1, created1 = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()
    h2, created2 = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()

    assert created1 is True
    assert created2 is False
    assert h1.id == h2.id

    count = (
        pg_session.query(models.House)
        .filter(models.House.source_room_id == room_id)
        .count()
    )
    assert count == 1


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_re_sync_picks_up_room_price_change(pg_session, seeded_marketplace):
    from app import models
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    room_id = seeded_marketplace["room_bh_id"]

    marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()

    room = pg_session.get(models.Room, room_id)
    room.base_price = 4_000_000
    pg_session.flush()

    h2, created = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()

    assert created is False
    assert h2.price == 4_000_000


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_re_publish_after_unpublish_returns_pending(pg_session, seeded_marketplace):
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    room_id = seeded_marketplace["room_bh_id"]

    marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()
    marketplace_sync_service.unpublish_room(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()
    house, created = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()

    assert created is False
    assert house.status == "pending"
