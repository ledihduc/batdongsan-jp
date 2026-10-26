"""Phase 04 AC5 — paid invoice rejects further payments."""

from __future__ import annotations

import os

import pytest
from fastapi import HTTPException

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_full_payment_locks_invoice(pg_session, seeded):
    from app.schemas.invoice import GenerateBatchRequest, RecordPaymentRequest
    from app.services import invoice_service

    created = invoice_service.generate_batch(
        pg_session,
        GenerateBatchRequest(building_id=seeded["building_id"], month="2026-07"),
        seeded["host_id"],
    )
    invoice_service.send_invoice(pg_session, created[0].id, seeded["host_id"])

    inv, payment = invoice_service.record_payment(
        pg_session,
        created[0].id,
        RecordPaymentRequest(amount=3000000, method="cash"),
        seeded["host_id"],
    )
    assert inv.status == "paid"
    assert inv.paid_at is not None
    assert payment.amount == 3000000

    # 2nd payment must be rejected
    with pytest.raises(HTTPException) as exc:
        invoice_service.record_payment(
            pg_session,
            created[0].id,
            RecordPaymentRequest(amount=100, method="cash"),
            seeded["host_id"],
        )
    assert exc.value.status_code == 400


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_partial_payment_keeps_invoice_open(pg_session, seeded):
    from app.schemas.invoice import GenerateBatchRequest, RecordPaymentRequest
    from app.services import invoice_service

    created = invoice_service.generate_batch(
        pg_session,
        GenerateBatchRequest(building_id=seeded["building_id"], month="2026-07"),
        seeded["host_id"],
    )
    invoice_service.send_invoice(pg_session, created[0].id, seeded["host_id"])

    inv, _ = invoice_service.record_payment(
        pg_session,
        created[0].id,
        RecordPaymentRequest(amount=1500000, method="cash"),
        seeded["host_id"],
    )
    assert inv.status == "sent"
    assert inv.paid_amount == 1500000

    # 2nd partial payment to close
    inv2, _ = invoice_service.record_payment(
        pg_session,
        created[0].id,
        RecordPaymentRequest(amount=1500000, method="bank_transfer"),
        seeded["host_id"],
    )
    assert inv2.status == "paid"
    assert inv2.paid_amount == 3000000
