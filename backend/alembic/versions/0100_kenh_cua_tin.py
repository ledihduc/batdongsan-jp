"""`houses.kenh` — TIN nói rõ mình thuộc pipeline nào, thôi đoán từ chuỗi.

## Vấn đề

`khai_thac_service.kenh_cua_tin` đang ĐOÁN:

    transaction_type == 'sale'          → ban
    'homestay' hoặc 'short' trong
      product_type (khớp CHUỖI CON)     → ngan_han
    còn lại                             → dai_han

Hai chỗ sai:
1. `product_type` là mã loại BĐS (`apartment`, `house`, `land`…), không phải
   kênh khai thác. Khớp chuỗi con trên nó là dựa vào việc ai đó đặt tên có chữ
   "homestay" — đổi tên danh mục là đổi luôn nghiệp vụ, âm thầm.
2. Không phân biệt được **mặt bằng** với **thuê dài hạn**. Mặt bằng rơi hết vào
   `dai_han`, nên chốt một mặt bằng sẽ đóng nhầm tin căn hộ cho thuê của cùng
   phòng, và ngược lại.

## Cách sửa

Cột `kenh` tường minh trên `houses`, backfill từ dữ liệu THẬT chứ không đoán:

    transaction_type='sale'                        → ban
    tin sinh từ phòng (`source_room_id`)           → kênh của phòng nếu suy
                                                     được duy nhất
    danh mục thuộc nhóm `stay_short`               → ngan_han
    danh mục thuộc nhóm `business`                 → mat_bang
    còn lại                                        → dai_han

`categories.group_key` là trục CÔNG NĂNG có thật trong hệ (`stay_short` ·
`stay_long` · `business`) và khách đã dùng nó để lọc — nó đáng tin hơn nhiều so
với khớp chuỗi con trên `product_type`.

Bất biến: additive · có mặc định · idempotent · có downgrade.

Revision ID: 0100_kenh_cua_tin
Revises: 0099_chan_ban_trung
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0100_kenh_cua_tin"
down_revision = "0099_chan_ban_trung"
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
    if not _co_bang("houses"):
        return

    if "kenh" not in _cot("houses"):
        op.add_column(
            "houses",
            sa.Column(
                "kenh", sa.String(20), nullable=False, server_default="dai_han"
            ),
        )
    if not _co_index("houses", "ix_houses_kenh"):
        op.create_index("ix_houses_kenh", "houses", ["kenh"])

    if op.get_bind().dialect.name != "postgresql":
        return

    # 1) Bán — trục giao dịch, chắc chắn nhất.
    op.execute(
        sa.text("UPDATE houses SET kenh = 'ban' WHERE transaction_type = 'sale'")
    )

    # 2) Tin sinh từ PHÒNG: mượn kênh của phòng khi phòng chỉ bật đúng một kênh
    #    thuê. Nhiều kênh thì không suy được — để bước 3 quyết theo danh mục.
    if _co_bang("room_kenh"):
        op.execute(
            sa.text(
                """
                UPDATE houses h SET kenh = k.kenh
                FROM (
                    SELECT room_id, min(kenh) AS kenh, count(*) AS n
                    FROM room_kenh
                    WHERE kenh <> 'ban'
                    GROUP BY room_id
                ) k
                WHERE h.source_room_id = k.room_id
                  AND k.n = 1
                  AND h.transaction_type <> 'sale'
                """
            )
        )

    # 3) Còn lại: theo NHÓM CÔNG NĂNG của danh mục — trục có thật, khách đã
    #    dùng để lọc, đáng tin hơn khớp chuỗi con trên `product_type`.
    if _co_bang("categories"):
        op.execute(
            sa.text(
                """
                UPDATE houses h SET kenh = CASE c.group_key
                        WHEN 'stay_short' THEN 'ngan_han'
                        WHEN 'business'   THEN 'mat_bang'
                        ELSE 'dai_han' END
                FROM categories c
                WHERE h.category_id = c.id
                  AND h.transaction_type <> 'sale'
                  AND h.kenh = 'dai_han'
                  AND c.group_key IN ('stay_short', 'business')
                """
            )
        )


def downgrade() -> None:
    if _co_index("houses", "ix_houses_kenh"):
        op.drop_index("ix_houses_kenh", table_name="houses")
    if "kenh" in _cot("houses"):
        op.drop_column("houses", "kenh")
