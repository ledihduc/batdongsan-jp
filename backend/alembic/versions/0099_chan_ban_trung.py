"""CHẶN BÁN TRÙNG — một phòng chỉ được MỘT giao dịch bán đã xác nhận.

## Vấn đề

`deals` là sổ cái, và luồng ba bên cho phép NHIỀU khách cùng gửi đề nghị chốt
cho cùng một phòng (đúng — họ đang tranh nhau). Nhưng khi chủ nhà bấm xác nhận,
không có gì ngăn họ bấm xác nhận **cái thứ hai**: hai người cùng "đã mua" một
căn hộ, hai sale cùng được ghi công, và không ai biết cho tới lúc bàn giao.

Kiểm ở tầng ứng dụng là chưa đủ: hai request đồng thời cùng đọc "chưa ai mua"
rồi cùng ghi. Chỉ DB mới chặn được đua nhau.

## Ràng buộc

    UNIQUE (room_id) WHERE status='confirmed' AND deal_type='sale'

Một phần, vì:
- `pending`/`rejected` phải được trùng — nhiều người cùng hỏi mua là chuyện
  bình thường, và đó chính là giá trị của sổ cái.
- `deal_type='rent'` được trùng theo thời gian: phòng cho thuê hết lượt này tới
  lượt khác, mỗi lượt một giao dịch.
- `room_id IS NULL` (giao dịch trên TIN lẻ, không thuộc dự án) không nằm trong
  phạm vi — NULL trong Postgres luôn khác nhau nên tự động được bỏ qua.

Đo trước khi thêm (09/09/2026): 4 giao dịch, **0 phòng trùng** → thêm được ngay,
không phải dọn dữ liệu.

Bất biến: additive · idempotent · có downgrade.

Revision ID: 0099_chan_ban_trung
Revises: 0098_pipeline_khai_thac
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0099_chan_ban_trung"
down_revision = "0098_pipeline_khai_thac"
branch_labels = None
depends_on = None

_IDX = "uq_deals_ban_da_xac_nhan"


def _insp():
    return sa.inspect(op.get_bind())


def _co_bang(ten: str) -> bool:
    return ten in _insp().get_table_names()


def _co_index(bang: str, ten: str) -> bool:
    if not _co_bang(bang):
        return False
    return any(i["name"] == ten for i in _insp().get_indexes(bang))


def _la_postgres() -> bool:
    return op.get_bind().dialect.name == "postgresql"


def upgrade() -> None:
    if not _co_bang("deals") or not _la_postgres():
        return
    if _co_index("deals", _IDX):
        return
    op.execute(
        sa.text(
            f"""
            CREATE UNIQUE INDEX {_IDX} ON deals (room_id)
            WHERE status = 'confirmed'
              AND deal_type = 'sale'
              AND room_id IS NOT NULL
            """
        )
    )


def downgrade() -> None:
    if _co_index("deals", _IDX):
        op.drop_index(_IDX, table_name="deals")
