"""user_preferences

Khảo sát phân loại người dùng (redesign v2 P1): lưu sở thích/mục đích để cá nhân
hoá landing + feed. 1 dòng / user (user_id unique). Additive, cross-DB.

Revision ID: 0049_user_preferences
Revises: 0048_social_community
Create Date: 2026-07-12
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0049_user_preferences"
down_revision: Union[str, Sequence[str], None] = "0048_social_community"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_preferences",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        # JSONList (list[str] lưu TEXT JSON) — interests / provinces / service_slugs.
        sa.Column("interests", sa.Text(), nullable=True),
        sa.Column("provinces", sa.Text(), nullable=True),
        sa.Column("service_slugs", sa.Text(), nullable=True),
        sa.Column("default_world", sa.String(20), nullable=False, server_default="realestate"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_user_preferences_user", "user_preferences", ["user_id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_user_preferences_user", table_name="user_preferences")
    op.drop_table("user_preferences")
