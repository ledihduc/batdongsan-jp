"""Persist Activity deposit-policy snapshots on new transactions.

Revision ID: 0121_activity_deposit_policy_snapshots
Revises: 0120_sale_application_web_handoff
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op


revision = "0121_activity_deposit_policy_snapshots"
down_revision = "0120_sale_application_web_handoff"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Nullable intentionally: rows created before this release must retain
    # their existing 50/50 behaviour and must not be reinterpreted using the
    # Admin policy that happens to be active during deployment.
    op.add_column("rental_journeys", sa.Column("deposit_policy_version", sa.Integer(), nullable=True))
    op.add_column("rental_journeys", sa.Column("platform_deposit_bps", sa.Integer(), nullable=True))
    op.add_column("reservations", sa.Column("activity_deposit_policy_version", sa.Integer(), nullable=True))
    op.add_column("reservations", sa.Column("activity_primary_deposit_bps", sa.Integer(), nullable=True))
    op.add_column("reservations", sa.Column("activity_primary_deposit_amount", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("reservations", "activity_primary_deposit_amount")
    op.drop_column("reservations", "activity_primary_deposit_bps")
    op.drop_column("reservations", "activity_deposit_policy_version")
    op.drop_column("rental_journeys", "platform_deposit_bps")
    op.drop_column("rental_journeys", "deposit_policy_version")
