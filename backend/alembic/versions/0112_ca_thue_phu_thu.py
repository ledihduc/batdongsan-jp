"""PHỤ THU và TIỀN ĐÃ THU của một ca thuê ngắn hạn.

## Vấn đề

Vòng đời một ca thuê giờ ở khách sạn/homestay không chỉ có tiền phòng: khách
uống nước trong phòng, gọi giặt là, ở lố giờ, làm mất thẻ từ. Lúc trả phòng lễ
tân phải cộng hết những thứ đó rồi trừ tiền cọc — hôm nay app không có chỗ nào
ghi, nên người ta tính nhẩm ra giấy và số liệu không về tới sổ sách.

Cũng không có chỗ ghi TIỀN ĐÃ THU: `reservations.deposit_paid` chỉ là cọc. Thu
thêm lúc nhận phòng, hoàn lại lúc trả phòng — hai việc xảy ra hằng ngày — không
có dấu vết.

## Cách làm — hai bảng, hai khái niệm, đừng trộn

* `reservation_phu_thu` = món LÀM TĂNG số phải thu (minibar · dịch vụ · quá giờ
  · bồi thường). Giữ đơn giá × số lượng để in phiếu ra khách đọc hiểu, không chỉ
  một cục tiền.
* `reservation_thanh_toan` = lần TIỀN ĐỔI TAY (thu tại quầy, hoàn cọc), có hình
  thức (tiền mặt / chuyển khoản) và mốc giờ.

Trộn hai thứ vào một bảng "giao dịch" thì mọi phép cộng đều phải nhớ dấu, và
một ngày nào đó có người quên.

`deposit_paid` GIỮ NGUYÊN là cọc đã nhận — không chép sang bảng mới, để dữ liệu
cũ không phải di cư; công thức "đã thu" cộng cả hai nguồn ở một chỗ duy nhất
(`ca_thue_service`).

Bất biến: additive · nullable · idempotent · có downgrade.

Revision ID: 0112_ca_thue_phu_thu
Revises: 0111_loai_phong
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0112_ca_thue_phu_thu"
down_revision = "0111_loai_phong"
branch_labels = None
depends_on = None


def _co(ten: str) -> bool:
    return ten in sa.inspect(op.get_bind()).get_table_names()


def upgrade() -> None:
    if not _co("reservation_phu_thu"):
        op.create_table(
            "reservation_phu_thu",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "reservation_id",
                sa.Integer(),
                sa.ForeignKey("reservations.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            #: minibar | dich_vu | qua_gio | boi_thuong | khac
            sa.Column("loai", sa.String(20), nullable=False, server_default="dich_vu"),
            sa.Column("ten", sa.String(200), nullable=False),
            sa.Column("don_gia", sa.Float(), nullable=False, server_default="0"),
            sa.Column("so_luong", sa.Float(), nullable=False, server_default="1"),
            sa.Column("thanh_tien", sa.Float(), nullable=False, server_default="0"),
            sa.Column("ghi_chu", sa.Text(), nullable=True),
            sa.Column("nguoi_ghi", sa.Integer(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )
    if not _co("reservation_thanh_toan"):
        op.create_table(
            "reservation_thanh_toan",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "reservation_id",
                sa.Integer(),
                sa.ForeignKey("reservations.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            #: thu = tiền nhận của khách · hoan = trả lại khách.
            sa.Column("loai", sa.String(10), nullable=False, server_default="thu"),
            sa.Column("so_tien", sa.Float(), nullable=False, server_default="0"),
            #: tien_mat | chuyen_khoan
            sa.Column(
                "hinh_thuc", sa.String(20), nullable=False, server_default="tien_mat"
            ),
            sa.Column("ghi_chu", sa.Text(), nullable=True),
            sa.Column("nguoi_ghi", sa.Integer(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )


    # Ghi chú kiểm phòng lúc trả: "ga dính vết mực", "thiếu 1 khăn". Nằm trên
    # chính ca thuê vì nó mô tả CA đó, không phải một dòng tiền.
    insp = sa.inspect(op.get_bind())
    if "reservations" in insp.get_table_names():
        cot = {c["name"] for c in insp.get_columns("reservations")}
        if "ghi_chu_kiem_phong" not in cot:
            op.add_column(
                "reservations", sa.Column("ghi_chu_kiem_phong", sa.Text(), nullable=True)
            )


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    if "reservations" in insp.get_table_names():
        cot = {c["name"] for c in insp.get_columns("reservations")}
        if "ghi_chu_kiem_phong" in cot:
            op.drop_column("reservations", "ghi_chu_kiem_phong")
    for ten in ("reservation_thanh_toan", "reservation_phu_thu"):
        if _co(ten):
            op.drop_table(ten)
