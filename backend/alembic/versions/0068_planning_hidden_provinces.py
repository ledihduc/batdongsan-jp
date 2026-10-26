"""planning_hidden_provinces

Admin ẩn/hiện bản đồ quy hoạch theo tỉnh (slug). Có dòng = ẩn. Additive, cross-DB.

Revision ID: 0068_planning_hidden_provinces
Revises: 0067_contact_leads
Create Date: 2026-07-31
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0068_planning_hidden_provinces"
down_revision: Union[str, Sequence[str], None] = "0067_contact_leads"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "planning_hidden_provinces",
        sa.Column("slug", sa.String(80), primary_key=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("planning_hidden_provinces")
