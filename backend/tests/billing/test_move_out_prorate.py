"""Phase 04 AC8 — move-out invoice prorates rent by days/30."""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_terminate_midmonth_creates_prorated_invoice(pg_session, seeded):
    """Contract starts 2026-07-01, monthly_rent=3M, terminate 2026-07-15
    → final invoice rent ≈ (15/30) × 3M = 1.5M (15 days incl. start)."""
    from app import models
    from app.schemas.contract import TerminateContractRequest
    from app.services import contract_service

    payload = TerminateContractRequest(
        actual_end_date="2026-07-15",
        deposit_refund_amount=3000000,
    )
    contract_service.terminate_contract(
        pg_session, seeded["contract_id"], payload, seeded["host_id"]
    )

    # Find the move-out invoice
    invoices = (
        pg_session.query(models.Invoice)
        .filter(models.Invoice.contract_id == seeded["contract_id"])
        .order_by(models.Invoice.created_at.desc())
        .all()
    )
    assert len(invoices) == 1
    inv = invoices[0]

    # Line items
    items = (
        pg_session.query(models.InvoiceLineItem)
        .filter(models.InvoiceLineItem.invoice_id == inv.id)
        .all()
    )
    rent_item = next((li for li in items if li.category == "rent"), None)
    refund_item = next((li for li in items if li.category == "deposit_refund"), None)

    assert rent_item is not None
    # 15 days × (3M / 30) = 1,500,000
    assert rent_item.amount == 1500000

    assert refund_item is not None
    assert refund_item.amount == -3000000

    # Total = 1.5M (rent) − 3M (refund) = -1.5M
    assert inv.total_amount == -1500000
    assert inv.status == "sent"
    assert inv.public_token is not None


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_move_out_full_month(pg_session, seeded):
    """End on last day of period → days=30 → full rent."""
    from app import models
    from app.schemas.contract import TerminateContractRequest
    from app.services import contract_service

    payload = TerminateContractRequest(
        actual_end_date="2026-07-30",  # 30 days from 07-01
        deposit_refund_amount=0,
    )
    contract_service.terminate_contract(
        pg_session, seeded["contract_id"], payload, seeded["host_id"]
    )

    inv = (
        pg_session.query(models.Invoice)
        .filter(models.Invoice.contract_id == seeded["contract_id"])
        .first()
    )
    assert inv is not None
    items = (
        pg_session.query(models.InvoiceLineItem)
        .filter(models.InvoiceLineItem.invoice_id == inv.id, models.InvoiceLineItem.category == "rent")
        .all()
    )
    # 30/30 days × 3M = 3M
    assert items[0].amount == 3000000
