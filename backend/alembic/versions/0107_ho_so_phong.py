"""Hồ sơ phòng: TẦNG + HƯỚNG của phòng, và SỔ SỬA CHỮA.

## Vấn đề

Màn "Hồ sơ phòng" (mockup 11/09/2026) ghi "An Cư Garden • Tầng 1", thẻ "Hướng:
Đông Nam" và mục "Lịch sử sửa chữa & sự cố". Bảng `rooms` không có tầng, không
có hướng (chỉ tin đăng `houses.direction` có), và không có chỗ nào ghi một lần
sửa chữa: bảo trì hiện chỉ là MỘT khoảng thời gian đang diễn ra trên chính phòng
— xong là mất dấu, không biết phòng hay hỏng gì, tốn bao nhiêu.

## Vì sao `huong` dùng slug của `houses.direction`

Phòng đăng lên chợ thành tin. Hai bộ từ vựng lệch nhau là hướng "Đông Nam" của
phòng không lọc được ở ô tìm theo hướng của tin.

## `tang` là chữ, không phải số

"Trệt", "Lửng", "Tum" — nhà trọ Việt đánh tầng bằng chữ nhiều như bằng số.

Bất biến: additive · nullable/có mặc định · idempotent · có downgrade.

Revision ID: 0107_ho_so_phong
Revises: 0106_chi_so_co_anh_va_duyet
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0107_ho_so_phong"
down_revision = "0106_chi_so_co_anh_va_duyet"
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
    cot = _cot("rooms")
    if not cot:
        return
    if "tang" not in cot:
        op.add_column("rooms", sa.Column("tang", sa.String(20), nullable=True))
    if "huong" not in cot:
        op.add_column("rooms", sa.Column("huong", sa.String(12), nullable=True))
    if "room_sua_chua" not in _bang():
        op.create_table(
            "room_sua_chua",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "room_id",
                sa.Integer(),
                sa.ForeignKey("rooms.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("host_id", sa.Integer(), nullable=False),
            sa.Column("tieu_de", sa.String(200), nullable=False),
            sa.Column("mo_ta", sa.Text(), nullable=True),
            sa.Column("ngay", sa.String(20), nullable=False),
            sa.Column("nguoi_thuc_hien", sa.String(200), nullable=True),
            sa.Column("chi_phi", sa.Float(), nullable=True),
            # 'dang_xu_ly' | 'da_xong'
            sa.Column(
                "trang_thai", sa.String(20), nullable=False, server_default="da_xong"
            ),
            sa.Column("created_by", sa.Integer(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )
        op.create_index("ix_room_sua_chua_room_id", "room_sua_chua", ["room_id"])
        op.create_index("ix_room_sua_chua_host_id", "room_sua_chua", ["host_id"])


def downgrade() -> None:
    if "room_sua_chua" in _bang():
        op.drop_index("ix_room_sua_chua_host_id", table_name="room_sua_chua")
        op.drop_index("ix_room_sua_chua_room_id", table_name="room_sua_chua")
        op.drop_table("room_sua_chua")
    cot = _cot("rooms")
    for ten in ("huong", "tang"):
        if ten in cot:
            op.drop_column("rooms", ten)
