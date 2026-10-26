"""LOẠI PHÒNG (hạng phòng) cho lưu trú ngắn hạn.

## Vấn đề

Khách đặt homestay/khách sạn chọn **hạng phòng** ("Studio VIP", "Phòng đôi
hướng vườn"), không chọn số phòng — số phòng do lễ tân gán lúc nhận phòng. Hôm
nay hệ chỉ có `room_kenh.loai_phong` là một chuỗi TỰ DO gõ lại ở từng phòng:

  * mười phòng giống hệt nhau phải khai giá mười lần, sai một phòng không ai thấy;
  * gõ "Studio VIP" và "Studio Vip" ra hai hạng khác nhau trong mắt máy;
  * không trả lời được câu điều hành quan trọng nhất của mô hình này: "hạng này
    còn mấy phòng trống" — thứ quyết định có nhận khách hay không.

## Cách làm

`loai_phong` là một bảng THẬT thuộc TOÀ, giữ những gì chung của cả hạng: sức
chứa, diện tích, loại giường, ảnh, tiện nghi và GIÁ (giờ · qua đêm · ngày).
`rooms.loai_phong_id` nối phòng vào hạng — một phòng đúng một hạng, vì hạng là
thuộc tính vật lý của căn phòng, khác với KÊNH (cách bán) có thể nhiều.

Giá vẫn giải quyết ở MỘT chỗ: `room_kenh.gia_*` (riêng của phòng) ?? giá của
hạng. Phòng đặc biệt (góc, view đẹp) vẫn ghi đè được mà không phá cái chung —
đúng khuôn "phòng ghi đè toà" của giá điện nước (mig 0104).

KHÔNG bỏ `room_kenh.loai_phong`: dữ liệu cũ đang nằm đó và app cũ trong cache
vẫn đọc. Nó thành nhãn hiển thị, hạng mới là thứ để đếm và để tính tiền.

Bất biến: additive · nullable · idempotent · có downgrade.

Revision ID: 0111_loai_phong
Revises: 0110_cho_thue_ngoai_app
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0111_loai_phong"
down_revision = "0110_cho_thue_ngoai_app"
branch_labels = None
depends_on = None


def _co_bang(ten: str) -> bool:
    return ten in sa.inspect(op.get_bind()).get_table_names()


def _cot(bang: str) -> set[str]:
    insp = sa.inspect(op.get_bind())
    if bang not in insp.get_table_names():
        return set()
    return {c["name"] for c in insp.get_columns(bang)}


def upgrade() -> None:
    if not _co_bang("loai_phong"):
        op.create_table(
            "loai_phong",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "building_id",
                sa.Integer(),
                sa.ForeignKey("buildings.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            sa.Column("ten", sa.String(120), nullable=False),
            sa.Column("mo_ta", sa.Text(), nullable=True),
            sa.Column("suc_chua", sa.Integer(), nullable=False, server_default="2"),
            sa.Column("dien_tich", sa.Float(), nullable=True),
            #: "King 1m8", "2 giường đơn" — chữ, vì thị trường gọi đủ kiểu.
            sa.Column("giuong", sa.String(80), nullable=True),
            sa.Column("anh", sa.Text(), nullable=True),
            sa.Column("tien_nghi", sa.Text(), nullable=True),
            #: Giá CỦA HẠNG. NULL = hạng chưa khai hình thức đó (khác 0đ).
            sa.Column("gia_theo_gio", sa.Float(), nullable=True),
            sa.Column("gia_qua_dem", sa.Float(), nullable=True),
            sa.Column("gia_theo_ngay", sa.Float(), nullable=True),
            sa.Column("thu_tu", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("dang_ban", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )
        # Hai hạng trùng tên trong một toà là lỗi nhập liệu, không phải nghiệp vụ.
        op.create_index(
            "ux_loai_phong_toa_ten", "loai_phong", ["building_id", "ten"], unique=True
        )

    if "loai_phong_id" not in _cot("rooms"):
        op.add_column(
            "rooms",
            sa.Column(
                "loai_phong_id",
                sa.Integer(),
                sa.ForeignKey("loai_phong.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )
        op.create_index("ix_rooms_loai_phong_id", "rooms", ["loai_phong_id"])


def downgrade() -> None:
    if "loai_phong_id" in _cot("rooms"):
        op.drop_index("ix_rooms_loai_phong_id", table_name="rooms")
        op.drop_column("rooms", "loai_phong_id")
    if _co_bang("loai_phong"):
        op.drop_index("ux_loai_phong_toa_ten", table_name="loai_phong")
        op.drop_table("loai_phong")
