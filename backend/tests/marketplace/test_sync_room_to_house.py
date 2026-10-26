"""Phase 08 AC1 + AC3 — publish/unpublish Room → House.

- AC1: publish creates House with synced fields + Room.is_listed=true.
- AC3: unpublish sets House.status=hidden + Room.is_listed=false.
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
def test_publish_creates_house_with_synced_fields(pg_session, seeded_marketplace):
    from app import models
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    room_id = seeded_marketplace["room_bh_id"]

    house, created = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()

    assert created is True
    assert house.id is not None
    assert house.host_id == host_id
    assert house.source_room_id == room_id
    assert house.product_type == "boarding_house"
    assert house.price == 3_500_000
    assert house.status == "pending"
    assert "P101" in house.title
    assert house.last_synced_at is not None

    room = pg_session.get(models.Room, room_id)
    assert room.is_listed_on_marketplace is True
    assert room.marketplace_house_id == house.id


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_publish_homestay_room_derives_homestay_type(pg_session, seeded_marketplace):
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    room_id = seeded_marketplace["room_hs_id"]

    house, _ = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    assert house.product_type == "homestay"


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_unpublish_hides_listing(pg_session, seeded_marketplace):
    from app import models
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    room_id = seeded_marketplace["room_bh_id"]

    marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()

    house = marketplace_sync_service.unpublish_room(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()

    assert house.status == "hidden"
    room = pg_session.get(models.Room, room_id)
    assert room.is_listed_on_marketplace is False
