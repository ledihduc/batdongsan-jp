"""Phase 06 reports tests — shared seed helpers."""

from __future__ import annotations

import os
import random
from datetime import datetime, timedelta

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


def _rand() -> str:
    return os.urandom(4).hex()


@pytest.fixture
def seeded_reports(pg_session):
    """Host with 1 building, 5 rooms (3 occupied / 1 vacant / 1 maintenance),
    3 active contracts, 4 invoices (2 paid in 2026-07, 1 overdue, 1 sent)."""
    from app import auth, models

    now = datetime.utcnow()
    host = models.User(
        name=f"Host {_rand()}",
        email=f"host_rpt_{_rand()}@test.com",
        password_hash=auth.hash_password("pass"),
        role="host",
        is_active=True,
        created_at=now,
    )
    pg_session.add(host)
    pg_session.flush()

    building = models.Building(
        host_id=host.id, name="Block A",
        address="1 Lê Lợi", city="HCM", district="Q1", ward="Bến Nghé",
        created_at=now, updated_at=now,
    )
    pg_session.add(building)
    pg_session.flush()

    rooms = []
    for i, status in enumerate(["occupied", "occupied", "occupied", "vacant", "maintenance"]):
        r = models.Room(
            building_id=building.id,
            code=f"P{i:02d}",
            base_price=3000000,
            capacity=2,
            status=status,
            maintenance_start="2026-07-10" if status == "maintenance" else None,
            maintenance_end="2026-07-25" if status == "maintenance" else None,
            created_at=now, updated_at=now,
        )
        pg_session.add(r)
        rooms.append(r)
    pg_session.flush()

    # 3 active contracts on the 3 occupied rooms; first one expires soon.
    from app.services import source_service
    src_id = source_service.resolve_default_source_id(pg_session, host.id, "manual")
    contracts = []
    for i in range(3):
        end_date = "2026-07-15" if i == 0 else "2027-12-31"
        c = models.Contract(
            host_id=host.id,
            room_id=rooms[i].id,
            start_date="2026-01-01",
            end_date=end_date,
            monthly_rent=3000000,
            deposit=3000000,
            status="active",
            source_id=src_id,
            created_at=now, updated_at=now,
        )
        pg_session.add(c)
        contracts.append(c)
    pg_session.flush()

    # 4 invoices: 2 paid in 2026-07, 1 overdue (past due), 1 sent (future due).
    today = datetime.utcnow().date()
    past = (today - timedelta(days=10)).isoformat()
    future = (today + timedelta(days=10)).isoformat()
    invoices = [
        # paid #1
        models.Invoice(
            host_id=host.id, contract_id=contracts[0].id,
            invoice_number=f"INV-A-{_rand()}", period_start="2026-07-01",
            period_end="2026-07-31", issued_date="2026-07-01", due_date="2026-07-15",
            status="paid", total_amount=4000000, paid_amount=4000000,
            paid_at=now, created_at=now, updated_at=now,
        ),
        # paid #2
        models.Invoice(
            host_id=host.id, contract_id=contracts[1].id,
            invoice_number=f"INV-B-{_rand()}", period_start="2026-07-01",
            period_end="2026-07-31", issued_date="2026-07-01", due_date="2026-07-15",
            status="paid", total_amount=3500000, paid_amount=3500000,
            paid_at=now, created_at=now, updated_at=now,
        ),
        # overdue
        models.Invoice(
            host_id=host.id, contract_id=contracts[2].id,
            invoice_number=f"INV-C-{_rand()}", period_start="2026-07-01",
            period_end="2026-07-31", issued_date="2026-07-01", due_date=past,
            status="sent", total_amount=3000000, paid_amount=0,
            created_at=now, updated_at=now,
        ),
        # sent, not overdue yet
        models.Invoice(
            host_id=host.id, contract_id=contracts[0].id,
            invoice_number=f"INV-D-{_rand()}", period_start="2026-08-01",
            period_end="2026-08-31", issued_date="2026-08-01", due_date=future,
            status="sent", total_amount=3000000, paid_amount=0,
            created_at=now, updated_at=now,
        ),
    ]
    for inv in invoices:
        pg_session.add(inv)
    pg_session.flush()

    # Add line items for the two paid invoices: 2 lines each (rent + electricity).
    for inv in invoices[:2]:
        pg_session.add(
            models.InvoiceLineItem(
                invoice_id=inv.id, category="rent", description="Tiền thuê",
                quantity=1, unit_price=3000000, amount=3000000, sort_order=0,
            )
        )
        pg_session.add(
            models.InvoiceLineItem(
                invoice_id=inv.id, category="electricity", description="Điện",
                quantity=1, unit_price=inv.total_amount - 3000000,
                amount=inv.total_amount - 3000000, sort_order=1,
            )
        )
    pg_session.flush()

    return {
        "host_id": host.id,
        "building_id": building.id,
        "room_ids": [r.id for r in rooms],
        "contract_ids": [c.id for c in contracts],
        "invoice_ids": [i.id for i in invoices],
    }
