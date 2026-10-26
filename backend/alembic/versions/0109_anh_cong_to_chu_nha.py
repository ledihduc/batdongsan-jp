"""Ảnh công tơ do CHỦ NHÀ tự chụp: mốc giờ, toạ độ, nguồn ảnh.

## Vấn đề

Ảnh công tơ tới giờ chỉ là một đường dẫn tệp. Ảnh lấy từ thư viện máy thì không
ai biết chụp lúc nào, ở đâu — có thể là ảnh công tơ tháng trước chụp lại, hoặc
ảnh công tơ phòng khác. Khi hai bên cãi nhau về số điện thì tấm ảnh đó không
chứng minh được gì.

Nay chủ nhà chụp THẲNG trong app (camera trực tiếp, không cho chọn ảnh có sẵn):
lưu mốc giờ máy chụp, toạ độ lúc chụp, ai chụp, và ảnh đến từ đường nào.

`nguon_anh`: 'chu_nha' = chủ nhà tự chụp · NULL hoặc 'nguoi_thue' = người thuê gửi.
Toạ độ NULL là hợp lệ — người dùng có quyền từ chối chia sẻ vị trí, và chặn chụp
vì thế thì họ quay lại ghi tay, mất luôn cả tấm ảnh.

Bất biến: additive · nullable · idempotent · có downgrade.

Revision ID: 0109_anh_cong_to_chu_nha
Revises: 0108_tai_san_thanh_toan
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0109_anh_cong_to_chu_nha"
down_revision = "0108_tai_san_thanh_toan"
branch_labels = None
depends_on = None

_COT = (
    ("chup_luc", sa.DateTime()),
    ("chup_lat", sa.Float()),
    ("chup_lng", sa.Float()),
    ("chup_boi", sa.Integer()),
    ("nguon_anh", sa.String(20)),
)


def _cot(bang: str) -> set[str]:
    insp = sa.inspect(op.get_bind())
    if bang not in insp.get_table_names():
        return set()
    return {c["name"] for c in insp.get_columns(bang)}


def upgrade() -> None:
    co = _cot("meter_readings")
    if not co:
        return
    for ten, kieu in _COT:
        if ten not in co:
            op.add_column("meter_readings", sa.Column(ten, kieu, nullable=True))


def downgrade() -> None:
    co = _cot("meter_readings")
    for ten, _ in reversed(_COT):
        if ten in co:
            op.drop_column("meter_readings", ten)
