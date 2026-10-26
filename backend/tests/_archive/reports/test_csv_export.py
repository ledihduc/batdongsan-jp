"""Phase 06 AC3 — CSV export streams correctly-formatted rows."""

from __future__ import annotations

import csv
import io
import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_export_invoices_csv_streams_header_and_rows(pg_session, seeded_reports):
    from app.services import report_service

    chunks = list(
        report_service.export_invoices_csv(
            pg_session, seeded_reports["host_id"], "2026-07"
        )
    )
    # Header + at least 3 invoices in July
    assert len(chunks) >= 4
    full = "".join(chunks)
    reader = csv.reader(io.StringIO(full))
    rows = list(reader)
    header = rows[0]
    assert header[0] == "Invoice #"
    assert "Total" in header
    assert "Status" in header
    # Body rows have same column count as header
    for row in rows[1:]:
        assert len(row) == len(header)


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_export_invoices_csv_unicode_safe(pg_session, seeded_reports):
    """Vietnamese tenant names with diacritics must round-trip through CSV."""
    from app import models
    from app.services import report_service

    # Add a tenant with diacritics on contract A
    tenant = models.Tenant(
        host_id=seeded_reports["host_id"],
        full_name="Lê Thị Đào",
        phone="0901112222",
        created_at=__import__("datetime").datetime.utcnow(),
    )
    pg_session.add(tenant)
    pg_session.flush()
    pg_session.add(
        models.ContractTenant(
            contract_id=seeded_reports["contract_ids"][0],
            tenant_id=tenant.id,
            is_primary=True,
        )
    )
    pg_session.flush()

    chunks = list(
        report_service.export_invoices_csv(
            pg_session, seeded_reports["host_id"], "2026-07"
        )
    )
    assert any("Lê Thị Đào" in c for c in chunks)
