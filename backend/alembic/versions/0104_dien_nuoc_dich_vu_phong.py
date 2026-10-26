"""Giá ĐIỆN · NƯỚC · DỊCH VỤ cho toà và phòng, kèm hai danh sách tiện ích.

## Vấn đề

Đơn giá điện/nước KHÔNG được lưu ở đâu cả. Nó chỉ tồn tại như tham số của
`GenerateBatchRequest` với hằng số cứng:

    electricity_unit_price: float = 3500   # VND/kWh
    water_unit_price: float = 15000        # VND/m3

Hậu quả: mỗi lần chốt tiền tháng chủ nhà phải gõ lại, và **cả lô dùng chung một
giá** — phòng có điều hoà tính điện cao hơn thì không diễn tả được. Grep toàn
repo `gia_dien|electricity_price|don_gia_dien` trả về 0 kết quả trước migration
này.

## Vì sao giá nằm ở HAI cấp

Đúng mức cho gần như mọi trường hợp là **toà**: 20 phòng xài chung công tơ tổng,
cùng một giá. Bắt gõ 20 lần là bắt gõ sai 20 lần. Nhưng luôn có phòng ngoại lệ,
nên phòng ghi đè được.

**`NULL` ≠ `0`.** `0` nghĩa là MIỄN PHÍ (rất nhiều nhà trọ bao nước); `NULL`
nghĩa là chưa khai, lấy theo toà. Gộp hai thứ vào `0` thì vĩnh viễn không khai
được "phòng này bao nước mà điện vẫn theo toà". Thứ tự giải quyết nằm ở ĐÚNG một
chỗ: `app/services/gia_tien_ich.py`.

## Hai danh sách, cố ý không gộp

    dich_vu_gom      phí dịch vụ hàng tháng BAO GỒM gì (gửi xe, rác, internet)
    do_trong_phong   phòng có sẵn ĐỒ gì, không tính tiền (giường, tủ, điều hoà)

Gộp làm một thì không trả lời được câu "trả tiền dịch vụ để lấy cái gì". Lưu
KEY chứ không lưu nhãn — đổi nhãn tiếng Việt thì dữ liệu cũ không hỏng.

Không dùng bảng `amenities` đang có: nó chỉ có `id/name/icon`, không nhóm, không
`is_active`, và `houses.amenities` lưu TÊN chứ không lưu id — nối vào cũng không
dùng lại được gì.

Bất biến: additive · nullable/có mặc định · idempotent · có downgrade.

Revision ID: 0104_dien_nuoc_dich_vu_phong
Revises: 0103_ma_moi_sale
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0104_dien_nuoc_dich_vu_phong"
down_revision = "0103_ma_moi_sale"
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


#: Giá tiện ích — nullable, KHÔNG có server_default. Mặc định `0` sẽ biến mọi
#: dòng đang có thành "miễn phí" thay vì "chưa khai".
_GIA = ("gia_dien", "gia_nuoc", "phi_dich_vu")


def upgrade() -> None:
    for bang in ("buildings", "rooms"):
        if not _co_bang(bang):
            continue
        cot = _cot(bang)
        for ten in _GIA:
            if ten not in cot:
                op.add_column(bang, sa.Column(ten, sa.Float, nullable=True))

    if _co_bang("rooms"):
        cot = _cot("rooms")
        # JSONList lưu TEXT JSON (xem `app/models/_shared.py`) — chạy được cả
        # SQLite trong test, không cần kiểu JSON riêng của Postgres.
        for ten in ("dich_vu_gom", "do_trong_phong"):
            if ten not in cot:
                op.add_column(
                    bang,
                    sa.Column(ten, sa.Text, nullable=False, server_default="[]"),
                )


def downgrade() -> None:
    if _co_bang("rooms"):
        cot = _cot("rooms")
        for ten in ("do_trong_phong", "dich_vu_gom", *_GIA):
            if ten in cot:
                op.drop_column("rooms", ten)

    if _co_bang("buildings"):
        cot = _cot("buildings")
        for ten in _GIA:
            if ten in cot:
                op.drop_column("buildings", ten)
