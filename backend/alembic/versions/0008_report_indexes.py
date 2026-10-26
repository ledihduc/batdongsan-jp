"""report_indexes

Phase 06 — add composite indexes to keep revenue / occupancy / dashboard
queries under the 2s SLA for hosts with ~100 rooms.

Revision ID: 0008_report_indexes
Revises: 0007_khai_bao_tam_tru
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op

revision: str = "0008_report_indexes"
down_revision: Union[str, Sequence[str], None] = "0007_khai_bao_tam_tru"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Revenue queries: filter by host + period prefix on Invoice.period_start.
    op.create_index(
        "ix_invoices_host_period_start",
        "invoices",
        ["host_id", "period_start"],
    )
    # Dashboard "expiring contracts": filter Contract.host_id + Contract.end_date.
    op.create_index(
        "ix_contracts_host_end_date",
        "contracts",
        ["host_id", "end_date"],
    )
    # Khai báo overdue dashboard scan.
    op.create_index(
        "ix_khai_bao_host_check_in_at",
        "khai_bao_tam_tru",
        ["host_id", "check_in_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_khai_bao_host_check_in_at", table_name="khai_bao_tam_tru")
    op.drop_index("ix_contracts_host_end_date", table_name="contracts")
    op.drop_index("ix_invoices_host_period_start", table_name="invoices")
