"""ĐƠN ĐẶT PHÒNG PHẢI ĐI QUA SALE — lưu sale và tin đã dẫn khách về.

Luật chủ dự án (14/09/2026): khách KHÔNG đặt thẳng với chủ nhà. Đường vào là
tin đăng của sale, hoặc trang toà nhà của sale → chọn phòng → đặt.

Trước đây đơn chỉ ghi `source='marketplace'`: không biết khách đến qua ai, nên
không tính được công cho sale và thông báo gửi theo "sale đang phụ trách phòng"
lúc báo chứ không phải lúc đặt. Hai cột mới là ẢNH CHỤP tại thời điểm đặt —
sale đổi về sau thì công của đơn cũ vẫn thuộc người dẫn khách.

Cả hai cho phép RỖNG: đơn cũ không có dữ liệu này, và ca vãng lai chủ nhà tự
ghi tại quầy cũng không qua sale nào.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0113_dat_phong_qua_sale"
down_revision = "0112_ca_thue_phu_thu"
branch_labels = None
depends_on = None


def _cot(bang: str) -> set[str]:
    insp = sa.inspect(op.get_bind())
    if bang not in insp.get_table_names():
        return set()
    return {c["name"] for c in insp.get_columns(bang)}


def upgrade() -> None:
    co = _cot("reservations")
    if not co:
        return
    if "sale_id" not in co:
        op.add_column(
            "reservations",
            sa.Column(
                "sale_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )
        op.create_index("ix_reservations_sale_id", "reservations", ["sale_id"])
    if "house_id" not in co:
        op.add_column(
            "reservations",
            sa.Column(
                "house_id",
                sa.Integer(),
                sa.ForeignKey("houses.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )


def downgrade() -> None:
    co = _cot("reservations")
    if "house_id" in co:
        op.drop_column("reservations", "house_id")
    if "sale_id" in co:
        insp = sa.inspect(op.get_bind())
        if any(i["name"] == "ix_reservations_sale_id" for i in insp.get_indexes("reservations")):
            op.drop_index("ix_reservations_sale_id", table_name="reservations")
        op.drop_column("reservations", "sale_id")
