"""Huy hiệu phải có PHÉP ĐO thật đứng sau.

Đo trên staging 05/09/2026: `host_profiles.avg_response_hours` có ở 1.053/1.054
hồ sơ, trong khi bảng `viewing_appointments` **rỗng hoàn toàn**. Cột đó lẽ ra do
`helpers.recompute_host_reputation` tính từ thời gian chủ nhà phản hồi lịch hẹn
— không có lịch hẹn nào thì con số ấy do seed ghi thẳng. Tương tự, 1.025 đánh
giá hiện có đều vào từ thời cổng `review_requires_stay` còn TẮT, tức bất kỳ ai
đăng nhập cũng chấm được bất kỳ tin nào.

Cách chữa: không xoá dữ liệu, mà **đếm cỡ mẫu** rồi để tầng hiển thị ẩn huy
hiệu khi mẫu quá nhỏ.

  - `reviews.verified_relationship` — đánh giá này có bằng chứng quan hệ thật
    (đã xem nhà / đã chốt giao dịch / đã ở) hay không. Toàn bộ dòng cũ = false.
  - `host_profiles.verified_review_count` — đếm sẵn, để `is_trusted_host` không
    phải biến từ hàm thuần thành hàm truy vấn (nó được gọi trong vòng lặp dựng
    danh sách tin).
  - `host_profiles.response_sample` — số lịch hẹn ĐÃ phản hồi, tức mẫu mà
    `avg_response_hours` dựa vào.

Revision ID: 0087_do_that
Revises: 0086_deals
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0087_do_that"
down_revision = "0086_deals"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "reviews",
        sa.Column(
            "verified_relationship",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "host_profiles",
        sa.Column(
            "verified_review_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "host_profiles",
        sa.Column(
            "response_sample", sa.Integer(), nullable=False, server_default="0"
        ),
    )

    # Backfill `response_sample` từ dữ liệu THẬT. Hiện là 0 với mọi hồ sơ vì
    # chưa có lịch hẹn nào — đó chính là điều cần lộ ra.
    op.execute(
        """
        UPDATE host_profiles hp SET response_sample = COALESCE(s.n, 0)
        FROM (
            SELECT h.host_id, COUNT(*) AS n
            FROM viewing_appointments va
            JOIN houses h ON h.id = va.house_id
            WHERE va.responded_at IS NOT NULL
            GROUP BY h.host_id
        ) s
        WHERE s.host_id = hp.user_id
        """
    )
    # `verified_review_count` để nguyên 0: không dòng nào trong 1.025 đánh giá
    # cũ chứng minh được quan hệ thật.


def downgrade() -> None:
    op.drop_column("host_profiles", "response_sample")
    op.drop_column("host_profiles", "verified_review_count")
    op.drop_column("reviews", "verified_relationship")
