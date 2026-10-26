"""SALE PHỤ TRÁCH của toà — bịt rò rỉ danh tính chủ nhà ra trang công khai.

## Vấn đề

`Building` chỉ có MỘT người: `host_id`. Nó mang hai nghĩa khác nhau tuỳ thời
điểm — "người dựng dự án" (khi sale tạo) và "chủ nhà" (sau khi bàn giao). Trước
bàn giao nó trỏ sale nên trang dự án công khai hiển thị đúng MỘT CÁCH TÌNH CỜ.

Bàn giao xong là lật sang chủ nhà, và `GET /api/buildings/{id}/public` (không
cần đăng nhập) trả thẳng `chu_id`/`chu_ten` = CHỦ NHÀ. App dựng nút "Nhắn cho
<tên chủ nhà>" trỏ vào hồ sơ họ. Bất kỳ ai cũng đọc được, bỏ qua sale hoàn toàn.

Điều đó phá luật xương sống của mô hình kinh doanh: **sale bỏ công tìm ra chủ
nhà, nên quan hệ đó là thứ họ sở hữu**. Sale khác và khách chỉ được liên hệ QUA
sale. Mất luật này là mất lý do sale ở lại nền tảng.

## Cách sửa

Toà cần HAI người, không phải một:

    host_id  ← chủ nhà: người VẬN HÀNH và sở hữu   (RIÊNG TƯ)
    sale_id  ← sale phụ trách: MẶT TIỀN công khai  (công khai)

Giá trị `sale_id` có sẵn ngay lúc bàn giao — nó chính là `host_id` TRƯỚC khi
đổi. `building_claim.py` đang tính đúng biến đó rồi nhưng chỉ trả về cho client
rồi vứt đi.

## Backfill

- Toà ĐÃ bàn giao (`claimed_at` khác NULL): lấy sale từ `sale_owner_links` của
  chủ nhà hiện tại.
- Toà CHƯA bàn giao: `sale_id = host_id` — sale tự dựng dự án, họ là cả hai.

Bất biến: additive · nullable · idempotent · có downgrade.

Revision ID: 0093_sale_phu_trach_toa
Revises: 0092_kenh_ban_cua_phong
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0093_sale_phu_trach_toa"
down_revision = "0092_kenh_ban_cua_phong"
branch_labels = None
depends_on = None


def _insp():
    return sa.inspect(op.get_bind())


def _co_bang(ten: str) -> bool:
    return ten in _insp().get_table_names()


def _co_cot(bang: str, cot: str) -> bool:
    if not _co_bang(bang):
        return False
    return cot in {c["name"] for c in _insp().get_columns(bang)}


def upgrade() -> None:
    if not _co_bang("buildings"):
        return

    if not _co_cot("buildings", "sale_id"):
        op.add_column(
            "buildings", sa.Column("sale_id", sa.Integer, nullable=True)
        )
        op.create_index("ix_buildings_sale_id", "buildings", ["sale_id"])

    # 1) Toà CHƯA bàn giao — sale tự dựng, họ vừa là sale vừa đứng tên toà.
    op.execute(
        sa.text(
            """
            UPDATE buildings SET sale_id = host_id
            WHERE sale_id IS NULL AND claimed_at IS NULL
            """
        )
    )

    # 2) Toà ĐÃ bàn giao — sale là người liên kết với chủ nhà hiện tại.
    #    Lấy liên kết CÒN HIỆU LỰC, mới nhất (một chủ có thể đã đổi sale).
    if _co_bang("sale_owner_links"):
        op.execute(
            sa.text(
                """
                UPDATE buildings b SET sale_id = (
                    SELECT l.sale_id FROM sale_owner_links l
                    WHERE l.owner_id = b.host_id AND l.status = 'active'
                    ORDER BY l.linked_at DESC LIMIT 1
                )
                WHERE b.sale_id IS NULL AND b.claimed_at IS NOT NULL
                """
            )
        )

    # Toà đã bàn giao mà chủ nhà KHÔNG có liên kết sale nào thì `sale_id` vẫn
    # NULL. Cố ý không lấp bừa bằng `host_id`: lấp thế là gán danh tính chủ nhà
    # vào ô công khai — đúng cái lỗi migration này sinh ra để bịt. API phải xử
    # lý được NULL (ẩn khối liên hệ) thay vì đoán.


def downgrade() -> None:
    if _co_cot("buildings", "sale_id"):
        op.drop_index("ix_buildings_sale_id", table_name="buildings")
        op.drop_column("buildings", "sale_id")
