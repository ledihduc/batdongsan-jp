"""`buildings.ma_moi_sale` — chủ nhà tự tạo mã để MỜI sale, chiều ngược của claim.

## Vì sao KHÔNG dùng lại `claim_code`

Hai mã làm hai việc ngược nhau, và nhầm lẫn thì mất toà:

    claim_code    sale tạo toà  →  CHỦ NHÀ nhập  →  host_id chuyển sang họ
    ma_moi_sale   chủ nhà tạo   →  SALE nhập     →  sale_id trỏ về sale đó

Nếu chủ nhà đưa nhầm `claim_code` cho sale, sale nhập vào là **thành chủ sở
hữu toà** — chủ nhà mất trắng tài sản của mình bằng một cú bấm. Đó là lý do
đây là cột riêng chứ không phải "dùng lại cho tiện".

## Luồng

Chủ nhà tự tạo toà (không có sale nào), rồi sinh mã và đưa cho sale mình muốn
làm việc cùng. Sale nhập mã → được gán phụ trách toà, và quan hệ NGƯỜI–NGƯỜI
(`sale_owner_links`) cũng mở ra để sale hỗ trợ đăng tin.

Mã dùng MỘT LẦN. Muốn mời người thứ hai thì sinh mã mới — mã còn hiệu lực mãi
là một chìa khoá lang thang trong tin nhắn Zalo.

Bất biến: additive · nullable · idempotent · có downgrade.

Revision ID: 0103_ma_moi_sale
Revises: 0102_building_sale_links
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

# Nối SAU 0102_building_sale_links: hai migration cùng nhận cha 0101 nên
# alembic có hai head và từ chối `upgrade head`. Việc của hai bên không đụng
# nhau (bên kia phạm vi hoá `sale_owner_links` theo toà, bên này thêm cột trên
# `buildings`), nên chỉ cần xếp thành chuỗi.
revision = "0103_ma_moi_sale"
down_revision = "0102_building_sale_links"
branch_labels = None
depends_on = None


def _insp():
    return sa.inspect(op.get_bind())


def _co_bang(ten: str) -> bool:
    return ten in _insp().get_table_names()


def _cot(bang: str) -> set[str]:
    if not _co_bang(bang):
        return set()
    return {c["name"] for c in _insp().get_columns(bang)}


def _co_index(bang: str, ten: str) -> bool:
    if not _co_bang(bang):
        return False
    return any(i["name"] == ten for i in _insp().get_indexes(bang))


def upgrade() -> None:
    if not _co_bang("buildings"):
        return
    if "ma_moi_sale" not in _cot("buildings"):
        op.add_column(
            "buildings", sa.Column("ma_moi_sale", sa.String(10), nullable=True)
        )
    if op.get_bind().dialect.name == "postgresql" and not _co_index(
        "buildings", "uq_buildings_ma_moi_sale"
    ):
        # UNIQUE MỘT PHẦN: `NULL` là "chưa mời ai" và phải trùng được thoải mái.
        op.execute(
            sa.text(
                "CREATE UNIQUE INDEX uq_buildings_ma_moi_sale "
                "ON buildings (ma_moi_sale) WHERE ma_moi_sale IS NOT NULL"
            )
        )


def downgrade() -> None:
    if _co_index("buildings", "uq_buildings_ma_moi_sale"):
        op.drop_index("uq_buildings_ma_moi_sale", table_name="buildings")
    if "ma_moi_sale" in _cot("buildings"):
        op.drop_column("buildings", "ma_moi_sale")
