"""houses_rejection_reason

Thêm cột rejection_reason (Text, nullable) vào houses — lý do admin từ chối tin,
để host biết đường sửa. Cross-dialect (Text chạy cả SQLite lẫn Postgres).

Revision ID: 0038_houses_rejection_reason
Revises: 0037_houses_geo_search
Create Date: 2026-07-04
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0038_houses_rejection_reason"
down_revision: Union[str, Sequence[str], None] = "0037_houses_geo_search"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("houses", sa.Column("rejection_reason", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("houses", "rejection_reason")
