"""Reel P2: bình luận dùng chung + lượt xem khử trùng

Revision ID: 0053_reel_engagement
Revises: 0052_reel_media_pipeline

Tất cả thay đổi đều THÊM MỚI (cột có server_default / bảng mới) nên an toàn với
dữ liệu đang chạy và rollback được.

Điểm quan trọng: `social_comments.target_type` mặc định 'post' → toàn bộ bình
luận cũ giữ nguyên ý nghĩa; reel dùng target_type='reel'.
"""

from alembic import op
import sqlalchemy as sa

revision = "0053_reel_engagement"
down_revision = "0052_reel_media_pipeline"
branch_labels = None
depends_on = None


def _cols(table: str) -> set[str]:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    return {c["name"] for c in insp.get_columns(table)}


def _tables() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


def upgrade() -> None:
    tables = _tables()

    if "social_comments" in tables and "target_type" not in _cols("social_comments"):
        op.add_column(
            "social_comments",
            sa.Column(
                "target_type",
                sa.String(length=10),
                nullable=False,
                server_default="post",
            ),
        )
        op.create_index(
            "ix_social_comments_target_type", "social_comments", ["target_type"]
        )
        # Truy vấn luôn là (target_type, post_id) → index ghép mới thực sự hữu ích.
        op.create_index(
            "ix_social_comments_target",
            "social_comments",
            ["target_type", "post_id"],
        )

    if "reels" in tables and "comment_count" not in _cols("reels"):
        op.add_column(
            "reels",
            sa.Column(
                "comment_count", sa.Integer(), nullable=False, server_default="0"
            ),
        )

    if "reel_views" not in tables:
        op.create_table(
            "reel_views",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("reel_id", sa.Integer(), nullable=False, index=True),
            sa.Column("viewer_key", sa.String(length=80), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=True, index=True),
            sa.Column(
                "watched_ms", sa.Integer(), nullable=False, server_default="0"
            ),
            sa.Column("created_at", sa.DateTime(), nullable=True, index=True),
            sa.UniqueConstraint(
                "reel_id", "viewer_key", name="uq_reel_view_reel_viewer"
            ),
        )
        op.create_index("ix_reel_views_viewer_key", "reel_views", ["viewer_key"])


def downgrade() -> None:
    tables = _tables()
    if "reel_views" in tables:
        op.drop_table("reel_views")
    if "reels" in tables and "comment_count" in _cols("reels"):
        op.drop_column("reels", "comment_count")
    if "social_comments" in tables and "target_type" in _cols("social_comments"):
        for idx in ("ix_social_comments_target", "ix_social_comments_target_type"):
            try:
                op.drop_index(idx, table_name="social_comments")
            except Exception:  # noqa: BLE001 — index có thể chưa tồn tại
                pass
        op.drop_column("social_comments", "target_type")
