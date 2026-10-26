"""Phase 08 AC6 — placeholder Tenant: from-booking flag + dedupe by phone."""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from tests.marketplace.conftest import make_appointment  # noqa: E402


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_placeholder_tenant_records_booking_origin(pg_session, seeded_marketplace):
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    guest_id = seeded_marketplace["guest_id"]
    room_id = seeded_marketplace["room_bh_id"]

    house, _ = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    appt = make_appointment(pg_session, house_id=house.id, guest_id=guest_id)

    _, tenant, placeholder = (
        marketplace_sync_service.create_contract_from_appointment(
            pg_session, host_id=host_id, appointment_id=appt.id, actor_id=host_id
        )
    )

    assert placeholder is True
    assert tenant.is_placeholder is True
    assert tenant.created_from_booking_type == "viewing_appointment"
    assert tenant.created_from_booking_id == appt.id


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_duplicate_phone_reuses_existing_tenant(pg_session, seeded_marketplace):
    """Two bookings same guest phone → 1 Tenant row, not 2."""
    from app import models
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    guest_id = seeded_marketplace["guest_id"]
    room_id = seeded_marketplace["room_bh_id"]

    house, _ = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    appt1 = make_appointment(pg_session, house_id=house.id, guest_id=guest_id)
    _, tenant1, _ = marketplace_sync_service.create_contract_from_appointment(
        pg_session, host_id=host_id, appointment_id=appt1.id, actor_id=host_id
    )
    pg_session.flush()

    # Free the room then create another appointment + contract.
    room = pg_session.get(models.Room, room_id)
    room.status = "vacant"
    pg_session.flush()

    appt2 = make_appointment(pg_session, house_id=house.id, guest_id=guest_id)
    _, tenant2, _ = marketplace_sync_service.create_contract_from_appointment(
        pg_session, host_id=host_id, appointment_id=appt2.id, actor_id=host_id
    )
    pg_session.flush()

    assert tenant1.id == tenant2.id
    same_phone_tenants = (
        pg_session.query(models.Tenant)
        .filter(
            models.Tenant.host_id == host_id, models.Tenant.phone == "0911000222"
        )
        .count()
    )
    assert same_phone_tenants == 1
