"""listing_albums — gom tin đăng thành ALBUM (kiểu album ảnh Facebook)

Một sale ôm 20 căn cùng một toà thì trang cá nhân ra 20 bài rời rạc: khách
cuộn mỏi tay vẫn không thấy "anh này có nguyên toà", còn sale thì không có
chỗ nào quản lý theo toà.

VÌ SAO KHÔNG DÙNG LẠI `buildings`: bảng đó thuộc mảng vận hành cho thuê
(toà → phòng → hợp đồng → hoá đơn) của chính chủ. Album là lớp TRƯNG BÀY cho
tin đăng, có thể gồm cả tin bán lẫn cho thuê, cả nhà mình lẫn nhà bán hộ. Ép
chung một bảng là trộn hai nghiệp vụ, và mọi truy vấn của cả hai bên sẽ phải
mang thêm điều kiện "loại nào" mãi mãi.

VÌ SAO KHOÁ NGOẠI CHỨ KHÔNG BẢNG NỐI: nhu cầu thật là "căn này thuộc toà
nào" — một căn hộ chỉ nằm trong đúng một toà. Bảng nối nhiều-nhiều kéo theo
thứ tự, trùng lặp và câu hỏi "xoá album thì tin đi đâu", trả giá cho một khả
năng chưa ai cần.

`unit_label` đặt trên `houses` chứ không trên quan hệ: nó là thuộc tính của
CHÍNH căn đó ("Căn 1201"), còn nguyên nghĩa kể cả khi tin bị gỡ khỏi album.

XOÁ ALBUM KHÔNG XOÁ TIN — `ON DELETE SET NULL`. Album là cái kệ, không phải
cái hộp; đập kệ thì đồ vẫn còn.

Bất biến: additive · idempotent · có downgrade.

Revision ID: 0082_listing_albums
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0082_listing_albums"
down_revision: Union[str, Sequence[str], None] = "0081_drop_two_services"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if "listing_albums" not in insp.get_table_names():
        op.create_table(
            "listing_albums",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("owner_id", sa.Integer(), nullable=False, index=True),
            sa.Column("name", sa.String(length=200), nullable=False),
            sa.Column("description", sa.Text(), nullable=False, server_default=""),
            # Ảnh bìa lấy từ một tin trong album. Tin đó bị xoá → về NULL, album
            # tự rơi về ảnh của tin đầu tiên còn lại.
            sa.Column("cover_house_id", sa.Integer(), nullable=True),
            sa.Column("address", sa.String(length=300), nullable=False, server_default=""),
            sa.Column("city", sa.String(length=100), nullable=False, server_default=""),
            sa.Column("district", sa.String(length=100), nullable=False, server_default=""),
            sa.Column(
                "is_public", sa.Boolean(), nullable=False, server_default=sa.true()
            ),
            sa.Column(
                "created_at",
                sa.DateTime(),
                nullable=False,
                server_default=sa.func.now(),
            ),
        )

    cot = {c["name"] for c in insp.get_columns("houses")}
    if "album_id" not in cot:
        op.add_column("houses", sa.Column("album_id", sa.Integer(), nullable=True))
        op.create_index("ix_houses_album_id", "houses", ["album_id"])
        # SET NULL: xoá album không được kéo theo tin.
        op.create_foreign_key(
            "fk_houses_album_id",
            "houses",
            "listing_albums",
            ["album_id"],
            ["id"],
            ondelete="SET NULL",
        )
    if "unit_label" not in cot:
        op.add_column(
            "houses",
            sa.Column(
                "unit_label", sa.String(length=50), nullable=False, server_default=""
            ),
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    cot = {c["name"] for c in insp.get_columns("houses")}
    if "album_id" in cot:
        op.drop_constraint("fk_houses_album_id", "houses", type_="foreignkey")
        op.drop_index("ix_houses_album_id", table_name="houses")
        op.drop_column("houses", "album_id")
    if "unit_label" in cot:
        op.drop_column("houses", "unit_label")

    if "listing_albums" in insp.get_table_names():
        op.drop_table("listing_albums")
