"""extend contracts with KB04 pre-file fields

Revision ID: 0030_extend_contracts_kb04_form_data
Revises: 0029_extend_buildings_district_prefile
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-55b: CT01 form snapshot for pre-file audit trail
  - AC-55b: kb04_pre_filed marker for pre-file tracking

kb04_form_data_json stores the CT01 form payload at time of operator pre-file
submission. This snapshot ensures audit trail is preserved even if tenant/contract
data changes later. JSON type: Postgres → JSONB, SQLite → TEXT (cross-DB compatible).
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0030_extend_contracts_kb04_form_data"
down_revision = "0029_extend_buildings_district_prefile"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("contracts") as batch_op:
        # AC-55b: CT01 form data snapshot at pre-file submission time
        # JSON type: Postgres → JSONB, SQLite → TEXT
        batch_op.add_column(
            sa.Column("kb04_form_data_json", sa.JSON, nullable=True)
        )
        # AC-55b: marks this contract has had a pre-file submission
        batch_op.add_column(
            sa.Column(
                "kb04_pre_filed",
                sa.Boolean,
                nullable=False,
                server_default=sa.false(),
            )
        )


def downgrade() -> None:
    with op.batch_alter_table("contracts") as batch_op:
        batch_op.drop_column("kb04_pre_filed")
        batch_op.drop_column("kb04_form_data_json")
