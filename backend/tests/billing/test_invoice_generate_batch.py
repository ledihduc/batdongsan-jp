"""Phase 04 AC1 — generate_batch creates N drafts; re-run idempotent.

Requires SMOKE_DATABASE_URL.
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
def test_generate_batch_creates_one_invoice_per_active_contract(pg_session, seeded):
    from app.schemas.invoice import GenerateBatchRequest
    from app.services import invoice_service

    payload = GenerateBatchRequest(
        building_id=seeded["building_id"],
        month="2026-07",
    )
    created = invoice_service.generate_batch(pg_session, payload, seeded["host_id"])
    assert len(created) == 1
    inv = created[0]
    assert inv.status == "draft"
    assert inv.contract_id == seeded["contract_id"]
    assert inv.total_amount == 3000000  # rent only (no meter readings yet)
    assert inv.period_start == "2026-07-01"
    assert inv.period_end == "2026-07-31"


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_generate_batch_idempotent(pg_session, seeded):
    """Re-running for same (contract, month) returns 0 new invoices."""
    from app.schemas.invoice import GenerateBatchRequest
    from app.services import invoice_service

    payload = GenerateBatchRequest(
        building_id=seeded["building_id"],
        month="2026-07",
    )
    first = invoice_service.generate_batch(pg_session, payload, seeded["host_id"])
    second = invoice_service.generate_batch(pg_session, payload, seeded["host_id"])
    assert len(first) == 1
    assert len(second) == 0  # already exists


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_generate_batch_includes_meter_diff(pg_session, seeded):
    """When 2 meter readings exist (prev + curr month), diff feeds line items."""
    from app import models
    from app.schemas.invoice import GenerateBatchRequest
    from app.services import invoice_service
    from datetime import datetime

    # Previous month reading
    pg_session.add(models.MeterReading(
        host_id=seeded["host_id"],
        room_id=seeded["room_id"],
        reading_date="2026-06-30",
        electricity_kwh=1000,
        water_m3=10,
        created_at=datetime.utcnow(),
    ))
    # Current month reading
    pg_session.add(models.MeterReading(
        host_id=seeded["host_id"],
        room_id=seeded["room_id"],
        reading_date="2026-07-30",
        electricity_kwh=1100,
        water_m3=15,
        created_at=datetime.utcnow(),
    ))
    pg_session.flush()

    payload = GenerateBatchRequest(
        building_id=seeded["building_id"],
        month="2026-07",
        electricity_unit_price=3500,
        water_unit_price=15000,
    )
    created = invoice_service.generate_batch(pg_session, payload, seeded["host_id"])
    assert len(created) == 1
    inv = created[0]
    # Rent 3M + 100 kWh × 3500 = 350K + 5 m3 × 15000 = 75K → total 3,425,000
    assert inv.total_amount == 3425000
