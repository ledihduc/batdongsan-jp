"""Tin đăng có tim, bình luận, ghim, ẩn và đếm lượt xem.

Trước đây tin BĐS là một tờ rao: xem rồi đi. Trang cá nhân sale nay là nơi họ
gửi cho khách, nên bài đăng ở đó phải cư xử như một bài viết bình thường —
thích, bình luận, chia sẻ — và chủ bài phải ghim/ẩn/xem được số của chính mình.

Bốn cột trên `houses`:
  - `pinned_at`  : ghim lên đầu trang cá nhân. Dùng MỐC THỜI GIAN chứ không
                   phải cờ boolean, để nhiều tin ghim còn xếp được với nhau và
                   biết cái nào ghim sau.
  - `view_count` : đếm thật, tăng ở `GET /api/houses/{id}`. Bắt đầu từ 0 —
                   không backfill số ảo, vì "1.2k lượt xem" bịa ra là loại
                   khẳng định người dùng tin ngay mà không kiểm được.
  - `like_count`, `comment_count` : cache, tính lại từ bảng thật.

`social_post_likes` được nới thành đa hình y như `social_comments` đã làm cho
reel (migration 0053): thêm `target_type`, và ràng buộc duy nhất chuyển từ
(post_id, user_id) sang (target_type, post_id, user_id). Thiếu bước đổi ràng
buộc thì tim bài viết id=5 sẽ chặn mất tim tin nhà id=5.

Revision ID: 0090_tin_dang_xa_hoi
Revises: 0089_agency
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0090_tin_dang_xa_hoi"
down_revision = "0089_agency"
branch_labels = None
depends_on = None

_COT_HOUSES = (
    ("pinned_at", sa.Column("pinned_at", sa.DateTime(), nullable=True)),
    (
        "view_count",
        sa.Column(
            "view_count", sa.Integer(), nullable=False, server_default="0"
        ),
    ),
    (
        "like_count",
        sa.Column(
            "like_count", sa.Integer(), nullable=False, server_default="0"
        ),
    ),
    (
        "comment_count",
        sa.Column(
            "comment_count", sa.Integer(), nullable=False, server_default="0"
        ),
    ),
)


def _co_cot(ten_bang: str, ten_cot: str) -> bool:
    insp = sa.inspect(op.get_bind())
    return ten_cot in {c["name"] for c in insp.get_columns(ten_bang)}


def upgrade() -> None:
    for ten, cot in _COT_HOUSES:
        if not _co_cot("houses", ten):
            op.add_column("houses", cot)

    if not _co_cot("social_post_likes", "target_type"):
        op.add_column(
            "social_post_likes",
            sa.Column(
                "target_type",
                sa.String(10),
                nullable=False,
                server_default="post",
            ),
        )

    bind = op.get_bind()
    insp = sa.inspect(bind)
    ten_uq = {c["name"] for c in insp.get_unique_constraints("social_post_likes")}
    if "uq_social_like_post_user" in ten_uq:
        op.drop_constraint(
            "uq_social_like_post_user", "social_post_likes", type_="unique"
        )
    if "uq_social_like_target_user" not in ten_uq:
        op.create_unique_constraint(
            "uq_social_like_target_user",
            "social_post_likes",
            ["target_type", "post_id", "user_id"],
        )

    # Tin đang ghim đọc rất thường xuyên (mỗi lần mở trang cá nhân) và luôn
    # kèm host_id — chỉ mục ghép để không quét cả bảng tin.
    idx = {i["name"] for i in insp.get_indexes("houses")}
    if "ix_houses_host_pinned" not in idx:
        op.create_index(
            "ix_houses_host_pinned", "houses", ["host_id", "pinned_at"]
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if "ix_houses_host_pinned" in {i["name"] for i in insp.get_indexes("houses")}:
        op.drop_index("ix_houses_host_pinned", table_name="houses")

    ten_uq = {c["name"] for c in insp.get_unique_constraints("social_post_likes")}
    if "uq_social_like_target_user" in ten_uq:
        op.drop_constraint(
            "uq_social_like_target_user", "social_post_likes", type_="unique"
        )
    if "uq_social_like_post_user" not in ten_uq:
        op.create_unique_constraint(
            "uq_social_like_post_user",
            "social_post_likes",
            ["post_id", "user_id"],
        )
    if _co_cot("social_post_likes", "target_type"):
        op.drop_column("social_post_likes", "target_type")

    for ten, _ in reversed(_COT_HOUSES):
        if _co_cot("houses", ten):
            op.drop_column("houses", ten)
