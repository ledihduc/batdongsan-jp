"""Lịch xem khách tự đặt → yêu cầu trong pipeline của sale.

Khách đặt lịch xem phòng của toà sale phụ trách là LEAD dài hạn thật, nhưng
trước đây nó chỉ nằm ở hàng lịch xem — bảng "Yêu cầu" của sale không thấy,
không gắn được căn, không chốt ra hoa hồng. Cột này nối một yêu cầu với lịch
xem sinh ra nó; UNIQUE để một lịch chỉ đẻ đúng một yêu cầu dù đồng bộ chạy
bao nhiêu lần.

Additive + nullable; yêu cầu sale tự lập giữ NULL.

Revision ID: 0134_yeu_cau_tu_lich_xem
Revises: 0133_bo_buoc_gui_can
"""

from alembic import op
import sqlalchemy as sa

revision = "0134_yeu_cau_tu_lich_xem"
down_revision = "0133_bo_buoc_gui_can"
branch_labels = None
depends_on = None

_IDX = "uq_sale_yeu_cau_appointment"


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if "sale_yeu_cau" not in set(insp.get_table_names()):
        return
    cot = {c["name"] for c in insp.get_columns("sale_yeu_cau")}
    if "appointment_id" not in cot:
        op.add_column(
            "sale_yeu_cau",
            sa.Column(
                "appointment_id",
                sa.Integer(),
                sa.ForeignKey("viewing_appointments.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )
    if _IDX not in {i["name"] for i in insp.get_indexes("sale_yeu_cau")}:
        op.create_index(_IDX, "sale_yeu_cau", ["appointment_id"], unique=True)


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if "sale_yeu_cau" not in set(insp.get_table_names()):
        return
    if _IDX in {i["name"] for i in insp.get_indexes("sale_yeu_cau")}:
        op.drop_index(_IDX, table_name="sale_yeu_cau")
    if "appointment_id" in {c["name"] for c in insp.get_columns("sale_yeu_cau")}:
        op.drop_column("sale_yeu_cau", "appointment_id")
