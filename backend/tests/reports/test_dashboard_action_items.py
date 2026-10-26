"""Phase 06 AC4 — dashboard action_items returns 4 categories with counts."""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_action_items_four_categories(pg_session, seeded_reports):
    from app.services import dashboard_service

    result = dashboard_service.action_items(
        pg_session, seeded_reports["host_id"]
    )
    summary = result["summary"]
    # 1 contract expires 2026-07-15 (within 30d window)
    assert summary["expiring_count"] >= 1
    # 1 sent invoice with past due date
    assert summary["overdue_invoice_count"] == 1
    # 0 khai báo overdue yet (none seeded)
    assert summary["overdue_khai_bao_count"] == 0
    # 1 maintenance room
    assert summary["maintenance_count"] == 1


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_zalo_reminder_target_returns_link_payload(pg_session, seeded_reports):
    """Build a Zalo reminder link for an overdue invoice."""
    from app import models
    from app.services import dashboard_service
    from app.utils import zalo

    # Attach a tenant with phone to contract C of the overdue invoice
    contract_id = seeded_reports["contract_ids"][2]
    tenant = models.Tenant(
        host_id=seeded_reports["host_id"],
        full_name="Đặng Văn Quá Hạn",
        phone="0903999000",
        created_at=__import__("datetime").datetime.utcnow(),
    )
    pg_session.add(tenant)
    pg_session.flush()
    pg_session.add(
        models.ContractTenant(
            contract_id=contract_id,
            tenant_id=tenant.id,
            is_primary=True,
        )
    )
    pg_session.flush()

    overdue_inv_id = seeded_reports["invoice_ids"][2]
    target = dashboard_service.reminder_target(
        pg_session, seeded_reports["host_id"], overdue_inv_id
    )
    assert target is not None
    msg = zalo.template_invoice_reminder(
        tenant_name=target["tenant"].full_name,
        amount=float(target["invoice"].total_amount),
        due_date=target["invoice"].due_date,
    )
    link = zalo.build_zalo_share_link(target["tenant"].phone, msg)
    assert link.startswith("https://zalo.me/+84903999000?body=")
    assert "3.000.000 VND" in msg
