"""Phase 07 homestay tests — shared seed helpers.

The seeded_homestay fixture builds: host + 1 building + 1 homestay room
(base_price=500_000) + a starter set of pricing rules (base/weekend/holiday/manual).

Why no reservation in the base fixture: each test that needs a reservation
creates its own with the dates relevant to the scenario being tested.
"""

from __future__ import annotations

import os
from datetime import datetime

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


def _rand() -> str:
    return os.urandom(4).hex()


@pytest.fixture
def seeded_homestay(pg_session):
    """Host + building + 1 homestay room + 4 pricing rules covering 2026-07.

    Pricing structure (priority resolution):
        base    100 → 500_000 every day in 2026
        weekend 200 → 700_000 Fri/Sat (mask = (1<<4)|(1<<5))
        holiday 500 → 1_000_000 on 2026-07-04 only
        manual 1000 → 1_500_000 on 2026-07-04 only

    So 2026-07-04 (Saturday, July 4 → simulate holiday) yields 1.5M.
    """
    from app import auth, models

    now = datetime.utcnow()
    host = models.User(
        name=f"Host {_rand()}",
        email=f"host_hs_{_rand()}@test.com",
        password_hash=auth.hash_password("pass"),
        role="host",
        is_active=True,
        created_at=now,
    )
    pg_session.add(host)
    pg_session.flush()

    building = models.Building(
        host_id=host.id, name="Homestay Block",
        address="1 Trần Phú", city="Đà Nẵng", district="Hải Châu", ward="Thạch Thang",
        created_at=now, updated_at=now,
    )
    pg_session.add(building)
    pg_session.flush()

    room = models.Room(
        building_id=building.id,
        code="HS01",
        base_price=500_000,
        capacity=2,
        status="vacant",
        created_at=now, updated_at=now,
    )
    pg_session.add(room)
    pg_session.flush()

    # Pricing rules covering all of 2026-07.
    rules = [
        models.PricingRule(
            host_id=host.id, room_id=room.id, rule_type="base",
            start_date="2026-01-01", end_date="2026-12-31",
            price_per_night=500_000, priority=100,
        ),
        models.PricingRule(
            host_id=host.id, room_id=room.id, rule_type="weekend",
            start_date="2026-01-01", end_date="2026-12-31",
            price_per_night=700_000, priority=200,
            weekday_mask=(1 << 4) | (1 << 5),  # Fri + Sat
        ),
        models.PricingRule(
            host_id=host.id, room_id=room.id, rule_type="holiday",
            start_date="2026-07-04", end_date="2026-07-04",
            price_per_night=1_000_000, priority=500,
            holiday_name="Quốc khánh Mỹ (test)",
        ),
        models.PricingRule(
            host_id=host.id, room_id=room.id, rule_type="manual",
            start_date="2026-07-04", end_date="2026-07-04",
            price_per_night=1_500_000, priority=1000,
        ),
    ]
    for r in rules:
        pg_session.add(r)
    pg_session.flush()

    return {
        "host_id": host.id,
        "building_id": building.id,
        "room_id": room.id,
        "rule_ids": [r.id for r in rules],
    }


def make_reservation(
    pg_session,
    *,
    host_id: int,
    room_id: int,
    check_in: str,
    check_out: str,
    status: str = "pending",
    total: float = 1_000_000,
    guest_name: str = "Khách test",
    guest_phone: str = "0900000001",
):
    """Helper for tests that need a pre-existing reservation."""
    from app import models
    from app.services import source_service

    src_id = source_service.resolve_default_source_id(pg_session, host_id, "direct")
    res = models.Reservation(
        host_id=host_id,
        room_id=room_id,
        guest_name=guest_name,
        guest_phone=guest_phone,
        check_in_date=check_in,
        check_out_date=check_out,
        nights=1,
        total_amount=total,
        status=status,
        source_id=src_id,
    )
    pg_session.add(res)
    pg_session.flush()
    return res
