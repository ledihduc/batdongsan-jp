"""Chỉ số điện nước có ẢNH và có bước DUYỆT.

## Vấn đề

`meter_readings` chỉ có số: `electricity_kwh`, `water_m3`, `reading_date`. Chủ nhà
tự đi ghi rồi tự nhập. Không có ảnh công tơ để đối chiếu, không có trạng thái,
không có ai gửi.

Nên luồng thật của nhà trọ dài hạn — **người thuê chụp công tơ gửi lên, chủ nhà
xem ảnh rồi duyệt** — không diễn tả được. Mà đó là luồng chủ dự án yêu cầu
(màn "Điện nước dài hạn": Tenant gửi chỉ số → Chủ nhà duyệt → Hoàn tất).

## Vì sao dòng CŨ là `da_duyet`

8 chỉ số đang có đều do CHỦ NHÀ tự nhập. Người nhập chính là người duyệt, nên
chúng đã được duyệt từ lúc sinh ra. Để `cho_duyet` là bắt chủ nhà duyệt lại chính
con số mình vừa gõ — và hoá đơn tháng đó sẽ đứng chờ vô cớ.

## `can_chup_lai` là một trạng thái, không phải xoá

Ảnh mờ / chụp nhầm công tơ phòng bên → chủ nhà bấm "Yêu cầu chụp lại". Giữ dòng
kèm lý do thay vì xoá: người thuê cần biết VÌ SAO bị trả về, và lịch sử cho thấy
phòng nào hay gửi sai.

Bất biến: additive · nullable/có mặc định · idempotent · có downgrade.

Revision ID: 0106_chi_so_co_anh_va_duyet
Revises: 0105_short_stays
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0106_chi_so_co_anh_va_duyet"
down_revision = "0105_short_stays"
branch_labels = None
depends_on = None


def _cot() -> set[str]:
    insp = sa.inspect(op.get_bind())
    if "meter_readings" not in insp.get_table_names():
        return set()
    return {c["name"] for c in insp.get_columns("meter_readings")}


def upgrade() -> None:
    cot = _cot()
    if not cot:
        return
    if "anh_dien" not in cot:
        op.add_column("meter_readings", sa.Column("anh_dien", sa.String(500), nullable=True))
    if "anh_nuoc" not in cot:
        op.add_column("meter_readings", sa.Column("anh_nuoc", sa.String(500), nullable=True))
    if "trang_thai" not in cot:
        # 'cho_duyet' | 'da_duyet' | 'can_chup_lai'
        op.add_column(
            "meter_readings",
            sa.Column(
                "trang_thai",
                sa.String(20),
                nullable=False,
                server_default="da_duyet",
            ),
        )
        op.create_index(
            "ix_meter_readings_trang_thai", "meter_readings", ["trang_thai"]
        )
    if "nguoi_gui_id" not in cot:
        # NULL = chủ nhà tự nhập. Có số = người thuê gửi qua app.
        op.add_column("meter_readings", sa.Column("nguoi_gui_id", sa.Integer(), nullable=True))
    if "duyet_luc" not in cot:
        op.add_column("meter_readings", sa.Column("duyet_luc", sa.DateTime(), nullable=True))
    if "duyet_boi" not in cot:
        op.add_column("meter_readings", sa.Column("duyet_boi", sa.Integer(), nullable=True))
    if "ly_do_tra_ve" not in cot:
        op.add_column("meter_readings", sa.Column("ly_do_tra_ve", sa.Text(), nullable=True))


def downgrade() -> None:
    cot = _cot()
    if "trang_thai" in cot:
        op.drop_index("ix_meter_readings_trang_thai", table_name="meter_readings")
    for ten in (
        "ly_do_tra_ve",
        "duyet_boi",
        "duyet_luc",
        "nguoi_gui_id",
        "trang_thai",
        "anh_nuoc",
        "anh_dien",
    ):
        if ten in cot:
            op.drop_column("meter_readings", ten)
