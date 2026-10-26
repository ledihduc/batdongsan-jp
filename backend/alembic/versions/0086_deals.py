"""Giao dịch đã chốt — khách bấm chốt, chủ phòng xác nhận, sale được ghi công.

Vì sao cần bảng riêng thay vì đếm `contracts`: hợp đồng thuê là việc của chủ
phòng và chỉ phát sinh ở Giai đoạn 6. Con số "N giao dịch" trên trang sale cần
có ngay, và nó đo một thứ khác: **sale này dẫn được bao nhiêu deal về đích**.

Chống thổi phồng — điểm cốt lõi của thiết kế:
  - Sale KHÔNG tạo được bản ghi. Khách tạo, chủ phòng xác nhận.
  - `sale_id` do backend TỰ suy từ `rooms.managed_by_sale_id`, không nhận từ
    app gửi lên (spec mục 4).
  - Chỉ `status='confirmed'` mới được đếm.

Revision ID: 0086_deals
Revises: 0085_sale_owner
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0086_deals"
down_revision = "0085_sale_owner"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "deals",
        sa.Column("id", sa.Integer(), primary_key=True),
        # Chốt một PHÒNG (thuê) hoặc một TIN ĐĂNG (bán). Đúng một trong hai.
        sa.Column(
            "room_id",
            sa.Integer(),
            sa.ForeignKey("rooms.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "house_id",
            sa.Integer(),
            sa.ForeignKey("houses.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "owner_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # Sale được ghi công. NULL khi chủ tự rao, không qua ai.
        sa.Column(
            "sale_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "customer_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("deal_type", sa.String(10), nullable=False),  # rent | sale
        # Tiền lưu SỐ NGUYÊN đồng (spec mục 3) — float làm tròn sai ở hàng đơn vị.
        sa.Column("amount", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("note", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("confirmed_at", sa.DateTime(), nullable=True),
        sa.Column(
            "confirmed_by",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("reject_reason", sa.String(300), nullable=True),
    )
    op.create_index("ix_deals_owner_id", "deals", ["owner_id"])
    op.create_index("ix_deals_sale_id", "deals", ["sale_id"])
    op.create_index("ix_deals_customer_id", "deals", ["customer_id"])
    op.create_index("ix_deals_status", "deals", ["status"])
    # Một khách chỉ có MỘT đề nghị đang chờ trên cùng một phòng — bấm nhầm hai
    # lần không được đẻ ra hai giao dịch.
    op.create_index(
        "uq_deals_pending_room",
        "deals",
        ["customer_id", "room_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending' AND room_id IS NOT NULL"),
    )
    op.create_index(
        "uq_deals_pending_house",
        "deals",
        ["customer_id", "house_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending' AND house_id IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("uq_deals_pending_house", table_name="deals")
    op.drop_index("uq_deals_pending_room", table_name="deals")
    op.drop_index("ix_deals_status", table_name="deals")
    op.drop_index("ix_deals_customer_id", table_name="deals")
    op.drop_index("ix_deals_sale_id", table_name="deals")
    op.drop_index("ix_deals_owner_id", table_name="deals")
    op.drop_table("deals")
