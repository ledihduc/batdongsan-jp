"""Phase 08 marketplace tests — shared seed helpers.

`seeded_marketplace` builds: host + 1 building + 2 rooms (one vacant
boarding_house, one is_homestay=True) + a guest User. Tests create their
own viewing_appointment / reservation as needed.
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
def seeded_marketplace(pg_session):
    from app import auth, models

    now = datetime.utcnow()
    host = models.User(
        name=f"Host {_rand()}",
        email=f"host_mp_{_rand()}@test.com",
        password_hash=auth.hash_password("pass"),
        role="host",
        is_active=True,
        created_at=now,
    )
    guest = models.User(
        name="Khách Marketplace",
        email=f"guest_mp_{_rand()}@test.com",
        password_hash=auth.hash_password("pass"),
        role="guest",
        phone="0911000222",
        is_active=True,
        created_at=now,
    )
    pg_session.add_all([host, guest])
    pg_session.flush()

    building = models.Building(
        host_id=host.id,
        name="Khu A",
        address="12 Hùng Vương",
        city="Đà Nẵng",
        district="Hải Châu",
        ward="Thạch Thang",
        created_at=now,
        updated_at=now,
    )
    pg_session.add(building)
    pg_session.flush()

    room_bh = models.Room(
        building_id=building.id,
        code="P101",
        base_price=3_500_000,
        capacity=2,
        status="vacant",
        images=["/uploads/p101_a.jpg"],
        is_homestay=False,
        created_at=now,
        updated_at=now,
    )
    room_hs = models.Room(
        building_id=building.id,
        code="HS01",
        base_price=600_000,
        capacity=2,
        status="vacant",
        is_homestay=True,
        created_at=now,
        updated_at=now,
    )
    pg_session.add_all([room_bh, room_hs])
    pg_session.flush()

    return {
        "host_id": host.id,
        "guest_id": guest.id,
        "building_id": building.id,
        "room_bh_id": room_bh.id,
        "room_hs_id": room_hs.id,
    }


def make_appointment(pg_session, *, house_id: int, guest_id: int, status: str = "pending"):
    from app import models

    appt = models.ViewingAppointment(
        house_id=house_id,
        guest_id=guest_id,
        booking_date="2026-07-10",
        booking_time="10:00",
        message="Mong xem phòng",
        status=status,
    )
    pg_session.add(appt)
    pg_session.flush()
    return appt


def make_reservation(
    pg_session,
    *,
    host_id: int,
    room_id: int,
    source: str = "marketplace",
    status: str = "pending",
    check_in: str = "2026-08-10",
    check_out: str = "2026-08-12",
    total: float = 1_200_000,
    guest_name: str = "Khách MP",
    guest_phone: str = "0911000222",
):
    from app import models
    from app.services import source_service

    src_id = source_service.resolve_default_source_id(pg_session, host_id, source)
    res = models.Reservation(
        host_id=host_id,
        room_id=room_id,
        guest_name=guest_name,
        guest_phone=guest_phone,
        check_in_date=check_in,
        check_out_date=check_out,
        nights=2,
        total_amount=total,
        status=status,
        source=source,
        source_id=src_id,
    )
    pg_session.add(res)
    pg_session.flush()
    return res
