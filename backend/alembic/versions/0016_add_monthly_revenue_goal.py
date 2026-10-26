"""add_monthly_revenue_goal

Phase 04 analytics — thêm monthly_revenue_goal vào host_profiles.

Đặt tại host_profiles (không phải users) vì:
  - 1:1 với HostProfile (host business metadata, không phải auth info)
  - Cùng với CCCD, bank info, KYC — không làm users table nặng thêm
  - Per Q5 decision: không cần audit trail, host có thể tự sửa (no ChangeLog)

NULL = host chưa đặt mục tiêu (hiển thị placeholder trong UI).

Revision ID: 0016_add_monthly_revenue_goal
Revises: 0015_add_commission_columns
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0016_add_monthly_revenue_goal"
down_revision: Union[str, Sequence[str], None] = "0015_add_commission_columns"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "host_profiles",
        sa.Column("monthly_revenue_goal", sa.Float(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("host_profiles", "monthly_revenue_goal")
