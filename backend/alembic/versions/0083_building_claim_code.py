"""Mã bàn giao toà nhà (sale tạo trước, chủ nhà nhập mã nhận sau).

Sale dựng dự án và đăng phòng khi chưa tìm được chủ nhà. Mỗi toà sinh một
`claim_code` để sale đưa cho chủ nhà; chủ nhà tạo tài khoản, nhập mã, rồi tiếp
quản phần vận hành (điện nước, hoá đơn).

Additive hoàn toàn: cột nullable, không đụng dữ liệu cũ.

Revision ID: 0083_building_claim_code
Revises: 0082_listing_albums
"""

from __future__ import annotations

import secrets
import string

import sqlalchemy as sa
from alembic import op

revision = "0083_building_claim_code"
down_revision = "0082_listing_albums"
branch_labels = None
depends_on = None

# Bỏ 0/O/1/I/L — đọc qua điện thoại rất dễ nghe nhầm, mà mã này chính là thứ
# sale đọc cho chủ nhà nghe.
BANG_CHU = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"


def _sinh_ma() -> str:
    return "".join(secrets.choice(BANG_CHU) for _ in range(8))


def upgrade() -> None:
    op.add_column("buildings", sa.Column("claim_code", sa.String(10), nullable=True))
    op.add_column("buildings", sa.Column("claimed_at", sa.DateTime(), nullable=True))
    op.add_column(
        "buildings",
        sa.Column(
            "created_by_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_unique_constraint("uq_buildings_claim_code", "buildings", ["claim_code"])
    op.create_index("ix_buildings_claim_code", "buildings", ["claim_code"])

    # Toà đã có từ trước cũng cần mã — nếu không, chủ nhà của chúng vĩnh viễn
    # không có đường nhận bàn giao.
    conn = op.get_bind()
    ids = [r[0] for r in conn.execute(sa.text("SELECT id FROM buildings")).fetchall()]
    da_dung: set[str] = set()
    for bid in ids:
        ma = _sinh_ma()
        while ma in da_dung:
            ma = _sinh_ma()
        da_dung.add(ma)
        conn.execute(
            sa.text("UPDATE buildings SET claim_code = :m WHERE id = :i"),
            {"m": ma, "i": bid},
        )


def downgrade() -> None:
    op.drop_index("ix_buildings_claim_code", table_name="buildings")
    op.drop_constraint("uq_buildings_claim_code", "buildings", type_="unique")
    op.drop_column("buildings", "created_by_user_id")
    op.drop_column("buildings", "claimed_at")
    op.drop_column("buildings", "claim_code")
