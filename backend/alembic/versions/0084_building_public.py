"""Cho phép công khai dự án ra trang cá nhân (danh sách phòng kiểu Agoda).

`buildings` xưa nay là dữ liệu quản lý nội bộ của chủ nhà. Nay sale dùng nó để
rao, nên cần một công tắc: dự án nào được hiện ra ngoài kèm bảng giá từng phòng.

Mặc định TRUE vì mục đích chính bây giờ là rao — bắt bật thủ công thì dự án vừa
tạo xong sẽ không hiện, người dùng tưởng hỏng. Chủ nhà không muốn lộ giá thì tắt.

Revision ID: 0084_building_public
Revises: 0083_building_claim_code
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0084_building_public"
down_revision = "0083_building_claim_code"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "buildings",
        sa.Column(
            "is_public",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
    )
    op.create_index("ix_buildings_is_public", "buildings", ["is_public"])


def downgrade() -> None:
    op.drop_index("ix_buildings_is_public", table_name="buildings")
    op.drop_column("buildings", "is_public")
