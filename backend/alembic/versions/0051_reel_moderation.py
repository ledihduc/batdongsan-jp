"""reel moderation (P0)

Duyệt-TRƯỚC cho reel: reel user đăng mặc định `pending`, admin duyệt mới hiện.
Thêm bảng `reel_reports` (báo cáo vi phạm) + cột kiểm duyệt trên `reels`.

Reel DEMO đã seed (status='published') được GIỮ NGUYÊN — chỉ đổi server_default
cho bản ghi mới, không backfill ngược.

Revision ID: 0051_reel_moderation
Revises: 0050_reels
Create Date: 2026-07-18
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0051_reel_moderation"
down_revision: Union[str, Sequence[str], None] = "0050_reels"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("reels", sa.Column("reviewed_by", sa.Integer(), nullable=True))
    op.add_column("reels", sa.Column("reviewed_at", sa.DateTime(), nullable=True))
    op.add_column(
        "reels", sa.Column("reject_reason", sa.String(length=300), nullable=True)
    )
    op.add_column(
        "reels",
        sa.Column("report_count", sa.Integer(), nullable=False, server_default="0"),
    )
    # Reel MỚI mặc định chờ duyệt (bản ghi cũ giữ nguyên status hiện có).
    op.alter_column("reels", "status", server_default="pending")

    op.create_table(
        "reel_reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("reel_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(length=50), nullable=False, server_default="other"),
        sa.Column("detail", sa.Text(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint("reel_id", "user_id", name="uq_reel_report_reel_user"),
    )
    op.create_index("ix_reel_reports_reel_id", "reel_reports", ["reel_id"])
    op.create_index("ix_reel_reports_user_id", "reel_reports", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_reel_reports_user_id", table_name="reel_reports")
    op.drop_index("ix_reel_reports_reel_id", table_name="reel_reports")
    op.drop_table("reel_reports")
    op.alter_column("reels", "status", server_default="published")
    op.drop_column("reels", "report_count")
    op.drop_column("reels", "reject_reason")
    op.drop_column("reels", "reviewed_at")
    op.drop_column("reels", "reviewed_by")
