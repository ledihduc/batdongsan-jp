"""LỊCH XEM NHÀ — hình thức xem, số người đi cùng, tên/SĐT khách trên phiếu hẹn.

Màn đặt lịch mới (15/09/2026, mockup "Schedule Viewing") hỏi thêm ba thứ mà
trước đây không có chỗ lưu:

  * `hinh_thuc` — xem TRỰC TIẾP tại căn hộ hay qua VIDEO CALL. Sale chuẩn bị
    hai việc khác hẳn nhau (mang chìa khoá ra sảnh vs. gọi Zalo), nên phải biết
    trước chứ không hỏi lại qua điện thoại.
  * `so_nguoi` — để sale biết đón mấy người.
  * `ten_khach` / `sdt_khach` — người đi xem có khi không phải chủ tài khoản
    (đặt hộ bố mẹ), và SĐT nhận Zalo có khi khác SĐT đăng nhập.

Tất cả cho phép RỖNG: lịch cũ không có dữ liệu này và vẫn phải đọc được.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0114_lich_xem_hinh_thuc"
down_revision = "0113_dat_phong_qua_sale"
branch_labels = None
depends_on = None

_COT = (
    ("hinh_thuc", sa.String(20)),
    ("so_nguoi", sa.Integer()),
    ("ten_khach", sa.String(200)),
    ("sdt_khach", sa.String(30)),
)


def _cot() -> set[str]:
    insp = sa.inspect(op.get_bind())
    if "viewing_appointments" not in insp.get_table_names():
        return set()
    return {c["name"] for c in insp.get_columns("viewing_appointments")}


def upgrade() -> None:
    co = _cot()
    if not co:
        return
    for ten, kieu in _COT:
        if ten not in co:
            op.add_column("viewing_appointments", sa.Column(ten, kieu, nullable=True))


def downgrade() -> None:
    co = _cot()
    for ten, _kieu in reversed(_COT):
        if ten in co:
            op.drop_column("viewing_appointments", ten)
