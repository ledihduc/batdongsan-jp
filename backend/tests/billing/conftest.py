"""Phase 04 billing tests — shared seed helpers using pg_session.

All tests in this folder require SMOKE_DATABASE_URL → skip otherwise (handled by
the root conftest pg_smoke_engine fixture).
"""

from __future__ import annotations

import os
import random
from datetime import date, datetime, timedelta

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


def _rand() -> str:
    return os.urandom(4).hex()


@pytest.fixture
def seeded(pg_session):
    """Seed a host + building + room + contract for billing tests.

    Returns dict: { host_id, building_id, room_id, contract_id, tenant_id }
    """
    from app import models, auth

    now = datetime.utcnow()
    host = models.User(
        name=f"Host {_rand()}",
        email=f"host_{_rand()}@test.com",
        password_hash=auth.hash_password("pass"),
        role="host",
        is_active=True,
        created_at=now,
    )
    pg_session.add(host)
    pg_session.flush()

    building = models.Building(
        host_id=host.id,
        name="B1",
        address="",
        city="",
        district="",
        ward="",
        created_at=now,
        updated_at=now,
    )
    pg_session.add(building)
    pg_session.flush()

    room = models.Room(
        building_id=building.id,
        code=f"R{random.randint(100, 999)}",
        base_price=3000000,
        capacity=1,
        status="occupied",
        created_at=now,
        updated_at=now,
    )
    pg_session.add(room)
    pg_session.flush()

    tenant = models.Tenant(
        host_id=host.id,
        full_name="Nguyễn Văn A",
        phone="0901234567",
        created_at=now,
    )
    pg_session.add(tenant)
    pg_session.flush()

    from app.services import source_service
    src_id = source_service.resolve_default_source_id(pg_session, host.id, "manual")
    contract = models.Contract(
        host_id=host.id,
        room_id=room.id,
        start_date="2026-07-01",
        end_date="2027-06-30",
        monthly_rent=3000000,
        deposit=3000000,
        status="active",
        source_id=src_id,
        created_at=now,
        updated_at=now,
    )
    pg_session.add(contract)
    pg_session.flush()

    pg_session.add(models.ContractTenant(
        contract_id=contract.id,
        tenant_id=tenant.id,
        is_primary=True,
        joined_at=contract.start_date,
    ))
    pg_session.flush()

    return {
        "host_id": host.id,
        "building_id": building.id,
        "room_id": room.id,
        "contract_id": contract.id,
        "tenant_id": tenant.id,
    }
