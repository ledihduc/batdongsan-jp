"""Tin ngắn hạn neo vào HẠNG PHÒNG của toà, không neo vào một phòng lẻ.

Khách sạn/homestay bán HẠNG ("Deluxe", "Studio"), số phòng do lễ tân gán lúc
nhận — máy đặt theo hạng đã có từ 0111. Nhưng chợ vẫn neo tin vào
`houses.source_room_id`, nên mười phòng giống hệt nhau thành mười tin trùng.

Additive: cột mới nullable, tin cũ giữ nguyên `source_room_id`.

Revision ID: 0130_tin_ngan_han_theo_hang
Revises: 0129_sale_public_facebook
"""

import sqlalchemy as sa
from alembic import op

revision = "0130_tin_ngan_han_theo_hang"
down_revision = "0129_sale_public_facebook"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    cols = {c["name"] for c in sa.inspect(bind).get_columns("houses")}
    if "loai_phong_id" in cols:
        return
    op.add_column(
        "houses", sa.Column("loai_phong_id", sa.Integer(), nullable=True)
    )
    op.create_index(
        "ix_houses_loai_phong_id", "houses", ["loai_phong_id"], unique=False
    )
    op.create_foreign_key(
        "fk_houses_loai_phong_id",
        "houses",
        "loai_phong",
        ["loai_phong_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    bind = op.get_bind()
    cols = {c["name"] for c in sa.inspect(bind).get_columns("houses")}
    if "loai_phong_id" not in cols:
        return
    op.drop_constraint("fk_houses_loai_phong_id", "houses", type_="foreignkey")
    op.drop_index("ix_houses_loai_phong_id", table_name="houses")
    op.drop_column("houses", "loai_phong_id")
