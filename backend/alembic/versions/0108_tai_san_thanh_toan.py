"""Hồ sơ phòng đủ như mockup: TÀI SẢN BÀN GIAO, KỲ THANH TOÁN, CỌC ĐÃ THU, đuôi CCCD.

## Vấn đề

Mockup "Hồ sơ phòng P101" (chủ dự án gửi lại 11/09/2026, dặn "làm y hệt") có
bốn thứ hệ thống chưa ghi nhận ở đâu:

* "Tiền cọc giữ chỗ — ✓ Đã đóng đủ": hợp đồng chỉ có SỐ tiền cọc phải đóng,
  không biết đã thu được bao nhiêu.
* "Kỳ thanh toán — Ngày 05 hàng tháng — Chuyển khoản / Tiền mặt": không có
  ngày thu tiền cố định; hạn hoá đơn luôn là ngày lập + 5 ngày.
* "Tài sản & Nội thất bàn giao — Điều hòa Daikin 12000 BTU • Inverter ● tốt":
  `rooms.do_trong_phong` chỉ là danh sách key (có điều hoà hay không), không có
  hãng, thông số, tình trạng hao mòn từng món.
* "CCCD: 001201029xxx": số CCCD người thuê gõ ở form hợp đồng bị bỏ rơi
  (schema không nhận), `tenants.cccd_number_hash` chưa từng được ghi.

## Vì sao chỉ lưu 3 số CUỐI của CCCD

Mockup che 3 số cuối và hiện 9 số đầu. Lưu 9 số đầu cạnh bcrypt hash thì chỉ
còn 1.000 khả năng — dò lại cả số trong vài phút. Lưu 3 số cuối thì phần còn
lại vẫn là 10^9 khả năng sau bcrypt.

## NULL khác 0

`coc_da_thu = NULL` là "chưa ghi nhận", `0` là "đã kiểm, chưa thu đồng nào".
`ngay_thanh_toan = NULL` là "chưa khai" — hoá đơn giữ hạn cũ.

Bất biến: additive · nullable/có mặc định · idempotent · có downgrade.

Revision ID: 0108_tai_san_thanh_toan
Revises: 0107_ho_so_phong
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0108_tai_san_thanh_toan"
down_revision = "0107_ho_so_phong"
branch_labels = None
depends_on = None


def _bang() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


def _cot(bang: str) -> set[str]:
    insp = sa.inspect(op.get_bind())
    if bang not in insp.get_table_names():
        return set()
    return {c["name"] for c in insp.get_columns(bang)}


def upgrade() -> None:
    cot = _cot("contracts")
    if cot:
        if "ngay_thanh_toan" not in cot:
            op.add_column("contracts", sa.Column("ngay_thanh_toan", sa.Integer(), nullable=True))
        if "hinh_thuc_thanh_toan" not in cot:
            # 'chuyen_khoan' | 'tien_mat' | 'ca_hai'
            op.add_column(
                "contracts", sa.Column("hinh_thuc_thanh_toan", sa.String(20), nullable=True)
            )
        if "coc_da_thu" not in cot:
            op.add_column("contracts", sa.Column("coc_da_thu", sa.Float(), nullable=True))

    cot = _cot("tenants")
    if cot and "cccd_duoi" not in cot:
        op.add_column("tenants", sa.Column("cccd_duoi", sa.String(4), nullable=True))

    if _cot("rooms") and "room_tai_san" not in _bang():
        op.create_table(
            "room_tai_san",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "room_id",
                sa.Integer(),
                sa.ForeignKey("rooms.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("host_id", sa.Integer(), nullable=False),
            # key của `do_trong_phong` (dieu_hoa, tu_lanh…) để vẽ biểu tượng; NULL = khác
            sa.Column("loai", sa.String(30), nullable=True),
            sa.Column("ten", sa.String(120), nullable=False),
            sa.Column("thong_so", sa.String(200), nullable=True),
            # 'tot' | 'hao_mon' | 'hong'
            sa.Column("tinh_trang", sa.String(20), nullable=False, server_default="tot"),
            sa.Column("ghi_chu", sa.Text(), nullable=True),
            sa.Column("created_by", sa.Integer(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.Column("updated_at", sa.DateTime(), nullable=True),
        )
        op.create_index("ix_room_tai_san_room_id", "room_tai_san", ["room_id"])
        op.create_index("ix_room_tai_san_host_id", "room_tai_san", ["host_id"])


def downgrade() -> None:
    if "room_tai_san" in _bang():
        op.drop_index("ix_room_tai_san_host_id", table_name="room_tai_san")
        op.drop_index("ix_room_tai_san_room_id", table_name="room_tai_san")
        op.drop_table("room_tai_san")
    if "cccd_duoi" in _cot("tenants"):
        op.drop_column("tenants", "cccd_duoi")
    cot = _cot("contracts")
    for ten in ("coc_da_thu", "hinh_thuc_thanh_toan", "ngay_thanh_toan"):
        if ten in cot:
            op.drop_column("contracts", ten)
