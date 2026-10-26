"""social_feed

Mạng xã hội (Bảng tin) — feed kiểu Facebook:
- social_posts      : bài đăng (nội dung + ảnh JSON), like_count/comment_count
                      denormalized để render feed rẻ.
- social_post_likes : thích theo (post, user) — unique constraint chống thích trùng.
- social_comments   : bình luận.

Additive, cross-DB (Postgres prod / SQLite dev). Reversible.

Revision ID: 0047_social_feed
Revises: 0046_industrial_re_promote
Create Date: 2026-07-11
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0047_social_feed"
down_revision: Union[str, Sequence[str], None] = "0046_industrial_re_promote"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "social_posts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False, server_default=""),
        sa.Column("images", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("like_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("comment_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "status", sa.String(length=20), nullable=False, server_default="published"
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_social_posts_user_id", "social_posts", ["user_id"])
    op.create_index("ix_social_posts_status", "social_posts", ["status"])
    op.create_index("ix_social_posts_created_at", "social_posts", ["created_at"])

    op.create_table(
        "social_post_likes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("post_id", "user_id", name="uq_social_like_post_user"),
    )
    op.create_index("ix_social_post_likes_post_id", "social_post_likes", ["post_id"])
    op.create_index("ix_social_post_likes_user_id", "social_post_likes", ["user_id"])

    op.create_table(
        "social_comments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_social_comments_post_id", "social_comments", ["post_id"])
    op.create_index("ix_social_comments_user_id", "social_comments", ["user_id"])
    op.create_index(
        "ix_social_comments_created_at", "social_comments", ["created_at"]
    )


def downgrade() -> None:
    op.drop_table("social_comments")
    op.drop_table("social_post_likes")
    op.drop_table("social_posts")
