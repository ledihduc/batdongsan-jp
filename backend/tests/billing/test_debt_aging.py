"""Phase 04 AC6 — debt aging buckets 0-30 / 30-60 / >60."""

from __future__ import annotations

import os
from datetime import date, datetime, timedelta

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_debt_aging_buckets(pg_session, seeded):
    """3 unpaid invoices with due_date 5d / 35d / 65d ago → each in its bucket."""
    from app import models
    from app.services import invoice_service

    today = date.today()
    now = datetime.utcnow()
    invoices_data = [
        {"days": 5, "amount": 1000000, "expected_bucket": "0-30"},
        {"days": 35, "amount": 2000000, "expected_bucket": "30-60"},
        {"days": 65, "amount": 3000000, "expected_bucket": ">60"},
    ]

    for i, data in enumerate(invoices_data):
        due = (today - timedelta(days=data["days"])).isoformat()
        issued = (today - timedelta(days=data["days"] + 7)).isoformat()
        pg_session.add(models.Invoice(
            host_id=seeded["host_id"],
            contract_id=seeded["contract_id"],
            invoice_number=f"INV-AGING-{i}",
            period_start=issued,
            period_end=due,
            issued_date=issued,
            due_date=due,
            status="sent",
            total_amount=data["amount"],
            paid_amount=0,
            created_at=now,
            updated_at=now,
        ))
    pg_session.flush()

    result = invoice_service.compute_debt_aging(pg_session, seeded["host_id"])
    buckets = {b["bucket"]: b for b in result["buckets"]}

    assert buckets["0-30"]["count"] == 1
    assert buckets["0-30"]["total_amount"] == 1000000

    assert buckets["30-60"]["count"] == 1
    assert buckets["30-60"]["total_amount"] == 2000000

    assert buckets[">60"]["count"] == 1
    assert buckets[">60"]["total_amount"] == 3000000

    assert result["total_unpaid"] == 6000000
