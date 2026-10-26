"""Phase 08 AC4 + AC7 + AC8 — appointment → draft Contract (source=marketplace).

- AC4: contract draft created with source='marketplace', tenant linked.
- AC7: cannot create if room occupied (data integrity guard).
- AC8: appointment from House owned by another host → 403.
"""

from __future__ import annotations

import os

import pytest
from fastapi import HTTPException

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from tests.marketplace.conftest import make_appointment  # noqa: E402


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_appointment_to_draft_contract(pg_session, seeded_marketplace):
    from app import models
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    guest_id = seeded_marketplace["guest_id"]
    room_id = seeded_marketplace["room_bh_id"]

    # First sync Room → House so appointment can hit a marketplace listing.
    house, _ = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    pg_session.flush()
    appt = make_appointment(pg_session, house_id=house.id, guest_id=guest_id)

    contract, tenant, placeholder = (
        marketplace_sync_service.create_contract_from_appointment(
            pg_session, host_id=host_id, appointment_id=appt.id, actor_id=host_id
        )
    )
    pg_session.flush()

    assert contract.id is not None
    assert contract.status == "draft"
    assert contract.source == "marketplace"
    assert contract.room_id == room_id

    assert tenant.id is not None
    assert tenant.host_id == host_id
    assert tenant.phone == "0911000222"
    assert tenant.is_placeholder is True

    ct = (
        pg_session.query(models.ContractTenant)
        .filter(models.ContractTenant.contract_id == contract.id)
        .first()
    )
    assert ct is not None
    assert ct.tenant_id == tenant.id
    assert ct.is_primary is True

    pg_session.refresh(appt)
    assert appt.status == "approved"


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cannot_create_contract_when_room_occupied(pg_session, seeded_marketplace):
    from app import models
    from app.services import marketplace_sync_service

    host_id = seeded_marketplace["host_id"]
    guest_id = seeded_marketplace["guest_id"]
    room_id = seeded_marketplace["room_bh_id"]

    house, _ = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_id, room_id=room_id, actor_id=host_id
    )
    appt = make_appointment(pg_session, house_id=house.id, guest_id=guest_id)

    room = pg_session.get(models.Room, room_id)
    room.status = "occupied"
    pg_session.flush()

    with pytest.raises(HTTPException) as exc:
        marketplace_sync_service.create_contract_from_appointment(
            pg_session, host_id=host_id, appointment_id=appt.id, actor_id=host_id
        )
    assert exc.value.status_code == 409


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_cross_host_appointment_rejected(pg_session, seeded_marketplace):
    """Host B cannot create contract from Host A's appointment."""
    from app import auth, models
    from app.services import marketplace_sync_service
    from datetime import datetime

    host_a = seeded_marketplace["host_id"]
    guest_id = seeded_marketplace["guest_id"]
    room_id = seeded_marketplace["room_bh_id"]

    house, _ = marketplace_sync_service.sync_room_to_house(
        pg_session, host_id=host_a, room_id=room_id, actor_id=host_a
    )
    appt = make_appointment(pg_session, house_id=house.id, guest_id=guest_id)

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
        marketplace_sync_service.create_contract_from_appointment(
            pg_session, host_id=host_b.id, appointment_id=appt.id, actor_id=host_b.id
        )
    assert exc.value.status_code == 403
