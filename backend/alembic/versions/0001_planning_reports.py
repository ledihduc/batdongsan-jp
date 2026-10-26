"""
Tạo bảng planning.reports — lưu báo cáo dữ liệu sai từ người dùng (US-08).

Revision ID: 0001_planning_reports
Revises: (none — revision đầu tiên)
Create Date: 2026-06-21
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

# revision identifiers
revision: str = "0001_planning_reports"
down_revision: str | None = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Schema 'planning' phải tồn tại trước (tạo ở main.py startup qua _ensure_planning_schema)
    op.create_table(
        "reports",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("parcel_id", sa.String(100), nullable=False),
        sa.Column("user_id", sa.Integer, nullable=False),
        sa.Column("reason", sa.String(500), nullable=False),
        sa.Column("image_url", sa.String(2000), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="new"),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("NOW()"),
            nullable=False,
        ),
        schema="planning",
    )
    # Index để admin query theo parcel_id + status
    op.create_index(
        "reports_parcel_id_idx",
        "reports",
        ["parcel_id"],
        schema="planning",
    )
    op.create_index(
        "reports_status_idx",
        "reports",
        ["status"],
        schema="planning",
    )


def downgrade() -> None:
    op.drop_index("reports_status_idx", table_name="reports", schema="planning")
    op.drop_index("reports_parcel_id_idx", table_name="reports", schema="planning")
    op.drop_table("reports", schema="planning")
