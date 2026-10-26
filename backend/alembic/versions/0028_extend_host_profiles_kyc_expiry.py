"""extend host_profiles with operator KYC expiry fields

Revision ID: 0028_extend_host_profiles_kyc_expiry
Revises: 0027_extend_users_for_delegation
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-50: operator individual KYC expiry alerts (30-day advance warning)
  - AC-50: re-KYC 30-day grace period (delegation paused → grace window open)
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0028_extend_host_profiles_kyc_expiry"
down_revision = "0027_extend_users_for_delegation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("host_profiles") as batch_op:
        # AC-50: operator individual KYC expiry (drives 30-day expiry alerts)
        batch_op.add_column(
            sa.Column("kyc_expires_at", sa.DateTime, nullable=True)
        )
        # AC-50: 30-day grace window after KYC expiry (delegation paused during this time)
        batch_op.add_column(
            sa.Column("kyc_grace_period_until", sa.DateTime, nullable=True)
        )


def downgrade() -> None:
    with op.batch_alter_table("host_profiles") as batch_op:
        batch_op.drop_column("kyc_grace_period_until")
        batch_op.drop_column("kyc_expires_at")
