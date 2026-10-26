"""reels

Video reel ngắn (kiểu Facebook Reels) hiển thị ở đầu mọi feed + xem toàn màn
hình cuộn dọc. Additive, cross-DB (SQLite dev + Postgres prod).

Revision ID: 0050_reels
Revises: 0049_user_preferences
Create Date: 2026-07-14
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0050_reels"
down_revision: Union[str, Sequence[str], None] = "0049_user_preferences"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "reels",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("video_url", sa.String(length=500), nullable=False),
        sa.Column("thumbnail_url", sa.String(length=500), nullable=True),
        sa.Column("caption", sa.Text(), nullable=False, server_default=""),
        sa.Column(
            "category", sa.String(length=20), nullable=False, server_default="all"
        ),
        sa.Column("like_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("view_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "status", sa.String(length=20), nullable=False, server_default="published"
        ),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_reels_user_id", "reels", ["user_id"])
    op.create_index("ix_reels_category", "reels", ["category"])
    op.create_index("ix_reels_status", "reels", ["status"])
    op.create_index("ix_reels_created_at", "reels", ["created_at"])

    op.create_table(
        "reel_likes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("reel_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint("reel_id", "user_id", name="uq_reel_like_reel_user"),
    )
    op.create_index("ix_reel_likes_reel_id", "reel_likes", ["reel_id"])
    op.create_index("ix_reel_likes_user_id", "reel_likes", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_reel_likes_user_id", table_name="reel_likes")
    op.drop_index("ix_reel_likes_reel_id", table_name="reel_likes")
    op.drop_table("reel_likes")
    op.drop_index("ix_reels_created_at", table_name="reels")
    op.drop_index("ix_reels_status", table_name="reels")
    op.drop_index("ix_reels_category", table_name="reels")
    op.drop_index("ix_reels_user_id", table_name="reels")
    op.drop_table("reels")
