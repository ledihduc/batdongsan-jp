"""demand_posts — tin NHU CẦU ("Cần thuê" / "Cần mua")

Bảng MỚI, không đụng `houses`. Lý do tách bảng: xem docstring
`app/domain/demand_post.py` (tóm tắt: `houses` bắt buộc address/area/price/ảnh
mà người đang TÌM nhà không có; tin nhu cầu nằm trong `houses` sẽ lọt vào bản
đồ + sitemap + bộ đếm "tin đang đăng" của hồ sơ; vòng đời cũng khác — nhu cầu
tự hết hạn 30 ngày).

Bất biến: additive (bảng mới, không sửa bảng cũ) + idempotent (kiểm tra bảng/
index đã tồn tại chưa) + có downgrade.

Revision ID: 0076_demand_posts
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0076_demand_posts"
down_revision: Union[str, Sequence[str], None] = "0075_listing_seller_type"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLE = "demand_posts"


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    if _TABLE not in insp.get_table_names():
        op.create_table(
            _TABLE,
            sa.Column("id", sa.Integer, primary_key=True),
            sa.Column(
                "user_id",
                sa.Integer,
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("kind", sa.String(10), nullable=False),
            sa.Column("province_code", sa.String(32), nullable=True),
            sa.Column("province_name", sa.String(100), nullable=True),
            sa.Column("ward_slugs", sa.JSON, nullable=True),
            sa.Column("area_label", sa.String(300), nullable=True),
            sa.Column("category_ids", sa.JSON, nullable=True),
            sa.Column("budget_min", sa.Float, nullable=True),
            sa.Column("budget_max", sa.Float, nullable=True),
            sa.Column("area_min", sa.Float, nullable=True),
            sa.Column("bedrooms_min", sa.Integer, nullable=True),
            sa.Column("move_in_date", sa.Date, nullable=True),
            sa.Column("duration_months", sa.Integer, nullable=True),
            sa.Column("occupants", sa.Integer, nullable=True),
            sa.Column("payment_method", sa.String(20), nullable=True),
            sa.Column("purpose", sa.String(20), nullable=True),
            sa.Column("legal_ok", sa.JSON, nullable=True),
            sa.Column("needs", sa.JSON, nullable=True),
            sa.Column("note", sa.Text, nullable=True),
            sa.Column(
                "status", sa.String(20), nullable=False, server_default="open"
            ),
            sa.Column("expires_at", sa.DateTime, nullable=False),
            sa.Column(
                "created_at",
                sa.DateTime,
                nullable=False,
                server_default=sa.func.now(),
            ),
        )

    idx = {i["name"] for i in insp.get_indexes(_TABLE)} if _TABLE in insp.get_table_names() else set()
    for name, cols in (
        ("ix_demand_posts_user_id", ["user_id"]),
        ("ix_demand_posts_kind", ["kind"]),
        ("ix_demand_posts_province_code", ["province_code"]),
        ("ix_demand_posts_status", ["status"]),
        ("ix_demand_posts_expires_at", ["expires_at"]),
        ("ix_demand_posts_created_at", ["created_at"]),
        # Truy vấn của màn danh sách: loại + khu vực + còn hạn.
        ("ix_demand_posts_feed", ["kind", "province_code", "status", "expires_at"]),
    ):
        if name not in idx:
            op.create_index(name, _TABLE, cols)


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    if _TABLE in insp.get_table_names():
        op.drop_table(_TABLE)
