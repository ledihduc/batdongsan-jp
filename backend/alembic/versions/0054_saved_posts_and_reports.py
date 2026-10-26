"""Lưu bài viết + báo cáo nội dung (menu ⋯ trên mỗi bài đăng)

Revision ID: 0054_saved_posts_reports
Revises: 0053_reel_engagement

Chỉ THÊM bảng mới — không đụng bảng đang chạy, nên an toàn và rollback sạch.
"""

from alembic import op
import sqlalchemy as sa

revision = "0054_saved_posts_reports"
down_revision = "0053_reel_engagement"
branch_labels = None
depends_on = None


def _tables() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


def upgrade() -> None:
    tables = _tables()

    if "saved_posts" not in tables:
        op.create_table(
            "saved_posts",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), nullable=False, index=True),
            sa.Column("post_id", sa.Integer(), nullable=False, index=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.UniqueConstraint(
                "user_id", "post_id", name="uq_saved_post_user_post"
            ),
        )

    if "content_reports" not in tables:
        op.create_table(
            "content_reports",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("target_type", sa.String(length=20), nullable=False),
            sa.Column("target_id", sa.Integer(), nullable=False),
            sa.Column("reporter_id", sa.Integer(), nullable=False),
            sa.Column("reason", sa.String(length=30), nullable=False,
                      server_default="other"),
            sa.Column("detail", sa.Text(), nullable=False, server_default=""),
            sa.Column("status", sa.String(length=20), nullable=False,
                      server_default="pending"),
            sa.Column("reviewed_by", sa.Integer(), nullable=True),
            sa.Column("reviewed_at", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.UniqueConstraint(
                "target_type", "target_id", "reporter_id",
                name="uq_content_report_target_reporter",
            ),
        )
        # Hàng đợi admin luôn lọc theo status rồi sắp theo thời gian.
        op.create_index(
            "ix_content_reports_status_created",
            "content_reports", ["status", "created_at"],
        )
        # Đếm số báo cáo của một nội dung cụ thể.
        op.create_index(
            "ix_content_reports_target",
            "content_reports", ["target_type", "target_id"],
        )
        op.create_index(
            "ix_content_reports_reporter", "content_reports", ["reporter_id"]
        )


def downgrade() -> None:
    tables = _tables()
    if "content_reports" in tables:
        for idx in (
            "ix_content_reports_reporter",
            "ix_content_reports_target",
            "ix_content_reports_status_created",
        ):
            try:
                op.drop_index(idx, table_name="content_reports")
            except Exception:  # noqa: BLE001 — index có thể chưa tồn tại
                pass
        op.drop_table("content_reports")
    if "saved_posts" in tables:
        op.drop_table("saved_posts")
