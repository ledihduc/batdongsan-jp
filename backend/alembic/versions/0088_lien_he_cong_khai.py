"""Người bán tự quyết có cho khách gọi trực tiếp hay không.

Cả repo giữ bất biến "SĐT masked" — số điện thoại không bao giờ ra endpoint
công khai. Nhưng trang cá nhân sale thiếu đúng hai đường khách Việt dùng nhiều
nhất: gọi điện và Zalo.

Cách nới bất biến mà không phá nó: **mặc định TẮT**, người bán tự bật. Mở số là
quyết định của họ, không phải mặc định của hệ thống.

Đặt ở `host_profiles` chứ không phải `sale_profiles`: đây là bảng
`/api/hosts/{id}` đã nạp sẵn, và chủ nhà tự rao cũng cần nút gọi y như sale.

Revision ID: 0088_lien_he_cong_khai
Revises: 0087_do_that
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0088_lien_he_cong_khai"
down_revision = "0087_do_that"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "host_profiles",
        sa.Column(
            "show_phone",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "host_profiles", sa.Column("zalo", sa.String(50), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("host_profiles", "zalo")
    op.drop_column("host_profiles", "show_phone")
