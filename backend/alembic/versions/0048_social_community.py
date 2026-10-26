"""social_community

Mở rộng mạng xã hội thành "Cộng đồng" gắn với 6 khối chức năng:
- social_posts    : +category (nhãn khối, backfill 'lease'), +địa danh có cấu trúc
                    (province_code/district_code/ward_slug/location_text), +edited_at/edit_count.
- social_comments : +parent_id (bình luận lồng nhiều cấp), +status (tombstone),
                    +reply_count (denormalized).

Additive, cross-DB (Postgres prod / SQLite dev). Reversible. Không đổi dữ liệu
ngoài backfill category='lease' cho bài cũ.

Revision ID: 0048_social_community
Revises: 0047_social_feed
Create Date: 2026-07-11
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0048_social_community"
down_revision: Union[str, Sequence[str], None] = "0047_social_feed"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── social_posts ────────────────────────────────────────────────────────
    op.add_column(
        "social_posts",
        sa.Column(
            "category", sa.String(length=20), nullable=False, server_default="lease"
        ),
    )
    op.add_column(
        "social_posts",
        sa.Column("province_code", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "social_posts",
        sa.Column("district_code", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "social_posts", sa.Column("ward_slug", sa.String(length=80), nullable=True)
    )
    op.add_column(
        "social_posts",
        sa.Column("location_text", sa.String(length=200), nullable=True),
    )
    op.add_column(
        "social_posts", sa.Column("edited_at", sa.DateTime(), nullable=True)
    )
    op.add_column(
        "social_posts",
        sa.Column("edit_count", sa.Integer(), nullable=False, server_default="0"),
    )
    # Backfill tường minh (đề phòng DB không áp server_default cho row cũ).
    op.execute("UPDATE social_posts SET category = 'lease' WHERE category IS NULL")
    op.create_index("ix_social_posts_category", "social_posts", ["category"])
    op.create_index(
        "ix_social_posts_province_code", "social_posts", ["province_code"]
    )

    # ── social_comments ─────────────────────────────────────────────────────
    op.add_column(
        "social_comments", sa.Column("parent_id", sa.Integer(), nullable=True)
    )
    op.add_column(
        "social_comments",
        sa.Column(
            "status", sa.String(length=20), nullable=False, server_default="published"
        ),
    )
    op.add_column(
        "social_comments",
        sa.Column("reply_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_index(
        "ix_social_comments_parent_id", "social_comments", ["parent_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_social_comments_parent_id", table_name="social_comments")
    op.drop_column("social_comments", "reply_count")
    op.drop_column("social_comments", "status")
    op.drop_column("social_comments", "parent_id")

    op.drop_index("ix_social_posts_province_code", table_name="social_posts")
    op.drop_index("ix_social_posts_category", table_name="social_posts")
    op.drop_column("social_posts", "edit_count")
    op.drop_column("social_posts", "edited_at")
    op.drop_column("social_posts", "location_text")
    op.drop_column("social_posts", "ward_slug")
    op.drop_column("social_posts", "district_code")
    op.drop_column("social_posts", "province_code")
    op.drop_column("social_posts", "category")
