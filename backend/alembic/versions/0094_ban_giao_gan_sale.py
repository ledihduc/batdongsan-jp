"""Bàn giao gán SALE QUẢN LÝ và CHỦ PHÒNG cho từng phòng (đợt B — R6).

## Vấn đề

`deals` ghi công cho sale bằng `rooms.managed_by_sale_id`. Nhưng luồng bàn giao
(mã dự án → chủ nhà nhận toà) **không hề gán cột đó**: 10/22 phòng đang rỗng.
Nó vẫn chạy được là nhờ nhánh dự phòng rơi về `houses.host_id` — tức đúng một
cách TÌNH CỜ, và sai ngay khi chủ nhà tự đăng tin phòng của mình (lúc đó
`houses.host_id` là CHỦ NHÀ, và công của sale bị ghi cho chủ nhà).

Tương tự `rooms.owner_id`: sau bàn giao chủ phòng là người vừa nhận toà, nhưng
không ai ghi. `deals`/`reservation_service` phải đoán bằng `buildings.host_id`.

## Cách sửa

Backfill hai cột từ TOÀ — nguồn sự thật sau migration 0093:

    rooms.managed_by_sale_id ← buildings.sale_id
    rooms.owner_id           ← buildings.host_id  (chỉ toà ĐÃ bàn giao)

`owner_id` chỉ lấp cho toà đã bàn giao. Toà chưa bàn giao thì `host_id` vẫn là
SALE — lấp vào `owner_id` là ghi nhận sale làm chủ phòng, sai hẳn nghiệp vụ và
sẽ đẩy `deals.owner_id` sang nhầm người.

Không đụng phòng đã có giá trị: chủ phòng có thể khác chủ toà (một dự án chứa
phòng của nhiều chủ — xem docstring `rooms.owner_id`), ghi đè là xoá dữ liệu.

Bất biến: additive · idempotent · có downgrade (đánh dấu lại NULL đúng phần
migration này đã lấp, nhận diện qua chính điều kiện đã dùng).

Revision ID: 0094_ban_giao_gan_sale
Revises: 0093_sale_phu_trach_toa
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0094_ban_giao_gan_sale"
down_revision = "0093_sale_phu_trach_toa"
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
    if not (_co_bang("rooms") and _co_bang("buildings")):
        return

    if _co_cot("rooms", "managed_by_sale_id") and _co_cot("buildings", "sale_id"):
        op.execute(
            sa.text(
                """
                UPDATE rooms r SET managed_by_sale_id = b.sale_id
                FROM buildings b
                WHERE r.building_id = b.id
                  AND r.managed_by_sale_id IS NULL
                  AND b.sale_id IS NOT NULL
                """
            )
        )

    if _co_cot("rooms", "owner_id"):
        op.execute(
            sa.text(
                """
                UPDATE rooms r SET owner_id = b.host_id
                FROM buildings b
                WHERE r.building_id = b.id
                  AND r.owner_id IS NULL
                  AND b.claimed_at IS NOT NULL
                """
            )
        )


def downgrade() -> None:
    # Chỉ gỡ đúng phần migration này đặt: giá trị BẰNG với toà. Phòng được gán
    # tay sang người khác giữ nguyên — nó không phải do đây sinh ra.
    if not (_co_bang("rooms") and _co_bang("buildings")):
        return

    if _co_cot("rooms", "owner_id"):
        op.execute(
            sa.text(
                """
                UPDATE rooms r SET owner_id = NULL
                FROM buildings b
                WHERE r.building_id = b.id
                  AND r.owner_id = b.host_id
                  AND b.claimed_at IS NOT NULL
                """
            )
        )

    if _co_cot("rooms", "managed_by_sale_id") and _co_cot("buildings", "sale_id"):
        op.execute(
            sa.text(
                """
                UPDATE rooms r SET managed_by_sale_id = NULL
                FROM buildings b
                WHERE r.building_id = b.id
                  AND r.managed_by_sale_id = b.sale_id
                """
            )
        )
