"""Lịch xem neo được vào PHÒNG, và tách "xem" khỏi "hẹn chốt" (đợt C — R5+R7).

## Vấn đề 1 — R5 chưa từng chạy

Sơ đồ nghiệp vụ: yêu cầu xem phòng của khách phải **bắn thẳng vào lịch chủ
nhà**. Thực tế `ViewingAppointment` chỉ neo `house_id`, và chủ nhà lọc theo
`houses.host_id`. Nhưng bàn giao toà **không đổi** `houses.host_id` (cố ý — tin
là của người ĐĂNG, đổi đi là sale mất sạch hồ sơ uy tín). Nên sau bàn giao,
`houses.host_id` vẫn là SALE và **chủ nhà không thấy một yêu cầu nào**.

Thêm nữa: dự án dựng phòng TRƯỚC rồi gắn tin sau. Phòng chưa gắn tin thì không
tồn tại `house_id` nào để neo — khách không có đường đặt xem.

Cả hai đều tan khi lịch neo được vào `room_id`: phòng biết toà, toà biết chủ.

## Vấn đề 2 — R7 chưa có

Sơ đồ tách hai việc: **xem phòng** (không cần chủ nhà chốt) và **hẹn gặp để
chốt phòng** (mới là lúc ra quyết định). Một bảng đang gánh cả hai mà không
phân biệt được, nên "đã xem 5 lượt" và "đang chốt 5 phòng" là cùng một con số.

Thêm `loai`: 'xem' (mặc định — đúng với toàn bộ dữ liệu cũ) | 'chot'.

## Ghi chú kỹ thuật

- `house_id` bỏ NOT NULL. Lịch neo phòng-chưa-có-tin thì không có tin nào để
  chỉ tới; nhét 0 hay -1 vào là dựng thêm một giá trị canh-lề phải nhớ.
- Index chống trùng slot cũ nằm trên `(house_id, booking_date, booking_time)`.
  Hàng `house_id IS NULL` không bao giờ đụng nó (NULL trong Postgres luôn khác
  nhau), nên cần index song song cho nhánh phòng.
- Backfill `room_id` từ `houses.source_room_id`: lịch cũ đặt trên tin sinh từ
  phòng thì vốn ĐÃ là lịch của phòng đó, chỉ là chưa ai ghi ra.

Bất biến: additive · nullable · idempotent · có downgrade.

Revision ID: 0095_lich_xem_neo_phong
Revises: 0094_ban_giao_gan_sale
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0095_lich_xem_neo_phong"
down_revision = "0094_ban_giao_gan_sale"
branch_labels = None
depends_on = None

_BANG = "viewing_appointments"
_IDX_PHONG = "uq_lich_xem_phong_slot"
# Trùng ACTIVE_STATUSES của booking_slot_service. Hai nơi phải khớp nhau, và
# đây là chỗ khó đổi hơn nên nó là bản gốc.
_STATUS_GIU_SLOT = "('pending','approved','locked')"


def _insp():
    return sa.inspect(op.get_bind())


def _co_bang(ten: str) -> bool:
    return ten in _insp().get_table_names()


def _cot(bang: str) -> dict:
    return {c["name"]: c for c in _insp().get_columns(bang)}


def _co_index(bang: str, ten: str) -> bool:
    if not _co_bang(bang):
        return False
    return any(i["name"] == ten for i in _insp().get_indexes(bang))


def _la_postgres() -> bool:
    return op.get_bind().dialect.name == "postgresql"


def upgrade() -> None:
    if not _co_bang(_BANG):
        return

    cot = _cot(_BANG)

    if "room_id" not in cot:
        op.add_column(_BANG, sa.Column("room_id", sa.Integer, nullable=True))
        op.create_index(f"ix_{_BANG}_room_id", _BANG, ["room_id"])

    if "loai" not in cot:
        op.add_column(
            _BANG,
            sa.Column(
                "loai", sa.String(10), nullable=False, server_default="xem"
            ),
        )

    # `house_id` thôi bắt buộc — chỉ làm được trên Postgres không cần dựng lại
    # bảng. SQLite (test) tạo bảng thẳng từ model nên đã nullable sẵn.
    if _la_postgres() and cot.get("house_id", {}).get("nullable") is False:
        op.alter_column(_BANG, "house_id", existing_type=sa.Integer(), nullable=True)

    # Lịch cũ trên tin sinh từ phòng VỐN LÀ lịch của phòng đó.
    if _co_bang("houses"):
        op.execute(
            sa.text(
                f"""
                UPDATE {_BANG} v SET room_id = h.source_room_id
                FROM houses h
                WHERE v.house_id = h.id
                  AND v.room_id IS NULL
                  AND h.source_room_id IS NOT NULL
                """
            )
        )

    if _la_postgres() and not _co_index(_BANG, _IDX_PHONG):
        op.execute(
            sa.text(
                f"""
                CREATE UNIQUE INDEX {_IDX_PHONG}
                ON {_BANG} (room_id, booking_date, booking_time)
                WHERE room_id IS NOT NULL AND status IN {_STATUS_GIU_SLOT}
                """
            )
        )


def downgrade() -> None:
    if not _co_bang(_BANG):
        return

    if _co_index(_BANG, _IDX_PHONG):
        op.drop_index(_IDX_PHONG, table_name=_BANG)

    cot = _cot(_BANG)
    if "loai" in cot:
        op.drop_column(_BANG, "loai")
    if "room_id" in cot:
        op.drop_index(f"ix_{_BANG}_room_id", table_name=_BANG)
        op.drop_column(_BANG, "room_id")

    # KHÔNG dựng lại NOT NULL trên `house_id`: nếu đã có lịch neo phòng thuần
    # thì lệnh đó nổ giữa chừng và để lại DB dở dang. Thiếu một ràng buộc còn
    # hơn một downgrade không chạy được.
