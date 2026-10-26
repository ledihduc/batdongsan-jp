"""ĐẶT PHÒNG NGẮN HẠN — lưu SỐ KHÁCH trên đơn (16/09/2026).

Màn đặt phòng mới hỏi "mấy người ở" như màn đặt lịch xem hỏi "mấy người đi
xem": phòng đơn tối đa 1 khách, quầy lễ tân cần biết chuẩn bị mấy bộ khăn và
có đúng người trên CCCD không. Trước đây con số này không có chỗ nào để lưu.

Cho phép RỖNG: đơn cũ và ca vãng lai tại quầy không có dữ liệu này.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0116_dat_phong_so_khach"
down_revision = "0115_lich_xem_doi_gio"
branch_labels = None
depends_on = None


def _cot() -> set[str]:
    insp = sa.inspect(op.get_bind())
    if "reservations" not in insp.get_table_names():
        return set()
    return {c["name"] for c in insp.get_columns("reservations")}


def upgrade() -> None:
    co = _cot()
    if co and "so_khach" not in co:
        op.add_column("reservations", sa.Column("so_khach", sa.Integer(), nullable=True))


def downgrade() -> None:
    if "so_khach" in _cot():
        op.drop_column("reservations", "so_khach")
