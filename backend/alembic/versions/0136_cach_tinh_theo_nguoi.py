"""Cách tính dịch vụ / nước: THEO ĐƠN GIÁ hoặc THEO NGƯỜI + số người ở.

Chủ dự án (07/10/2026): dịch vụ không tính "theo lượt"; có hai cách —
theo đơn giá (như điện: đơn giá × chỉ số / một khoản cố định) hoặc theo
người (đơn giá × số người đang ở phòng). Nước nhà trọ VN hay thu theo đầu
người thay vì theo công tơ.

  * service_fees.cach_tinh   'don_gia' | 'theo_nguoi'   (NULL = don_gia)
  * rooms.nuoc_theo_nguoi    TRUE = nước tính theo người (NULL/FALSE = chỉ số)
  * contracts.so_nguoi_o     số người ở thực tế (NULL = đếm người trên HĐ)

Additive, nullable, idempotent.

Revision ID: 0136_cach_tinh_theo_nguoi
Revises: 0135_luot_xem_tin_theo_ngay
"""

from alembic import op
import sqlalchemy as sa

revision = "0136_cach_tinh_theo_nguoi"
down_revision = "0135_luot_xem_tin_theo_ngay"
branch_labels = None
depends_on = None

_COT = (
    ("service_fees", sa.Column("cach_tinh", sa.String(20), nullable=True)),
    ("rooms", sa.Column("nuoc_theo_nguoi", sa.Boolean(), nullable=True)),
    ("contracts", sa.Column("so_nguoi_o", sa.Integer(), nullable=True)),
)


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    for bang, cot in _COT:
        if cot.name not in {c["name"] for c in insp.get_columns(bang)}:
            op.add_column(bang, cot)


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    for bang, cot in _COT:
        if cot.name in {c["name"] for c in insp.get_columns(bang)}:
            op.drop_column(bang, cot.name)
