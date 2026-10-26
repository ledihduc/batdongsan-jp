"""extend buildings with district pre-file acceptance flag

Revision ID: 0029_extend_buildings_district_prefile
Revises: 0028_extend_host_profiles_kyc_expiry
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-55c: district_pre_file_accepted flag for KB04 pre-file workflow

Three-state semantics:
  NULL  = unknown (default 6h approve-then-file workflow applies)
  TRUE  = district confirmed acceptance (O1 pre-file fast-track enabled)
  FALSE = district explicitly rejected pre-file (always use 6h workflow)
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0029_extend_buildings_district_prefile"
down_revision = "0028_extend_host_profiles_kyc_expiry"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("buildings") as batch_op:
        # AC-55c: NULL = unknown; TRUE = accepted; FALSE = rejected
        batch_op.add_column(
            sa.Column("district_pre_file_accepted", sa.Boolean, nullable=True)
        )


def downgrade() -> None:
    with op.batch_alter_table("buildings") as batch_op:
        batch_op.drop_column("district_pre_file_accepted")
