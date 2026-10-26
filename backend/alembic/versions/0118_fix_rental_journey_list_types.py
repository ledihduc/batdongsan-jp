"""Align journey list columns with the existing JSONList TEXT convention.

Revision ID: 0118_fix_journey_lists
Revises: 0117_rental_journey
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0118_fix_journey_lists"
down_revision = "0117_rental_journey"
branch_labels = None
depends_on = None

_COLUMNS = (
    ("rental_journeys", "contract_urls"),
    ("rental_journey_payments", "proof_urls"),
    ("rental_journey_reports", "evidence_urls"),
)


def _type_name(table: str, column: str) -> str:
    inspector = sa.inspect(op.get_bind())
    for item in inspector.get_columns(table):
        if item["name"] == column:
            return str(item["type"]).lower()
    return ""


def upgrade() -> None:
    for table, column in _COLUMNS:
        if "json" not in _type_name(table, column):
            continue
        op.alter_column(
            table,
            column,
            existing_type=sa.JSON(),
            type_=sa.Text(),
            existing_nullable=False,
            postgresql_using=f"{column}::text",
            server_default="[]",
        )


def downgrade() -> None:
    for table, column in reversed(_COLUMNS):
        if "text" not in _type_name(table, column):
            continue
        op.alter_column(
            table,
            column,
            existing_type=sa.Text(),
            type_=sa.JSON(),
            existing_nullable=False,
            postgresql_using=f"{column}::json",
            server_default="[]",
        )
