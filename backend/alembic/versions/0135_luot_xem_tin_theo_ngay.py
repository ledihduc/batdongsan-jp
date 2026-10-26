"""Lượt xem tin theo ngày — biểu đồ "Hiệu quả bài đăng" của sale.

`houses.view_count` chỉ là tổng dồn; màn Báo cáo của sale (mockup 05/10/2026)
cần lượt xem từng ngày. Bảng mới, một dòng cho mỗi (tin, ngày giờ VN).

Additive: bảng mới, không đụng bảng cũ. Không có số liệu trước ngày deploy —
tổng dồn cũ không chia lại được theo ngày.

Revision ID: 0135_luot_xem_tin_theo_ngay
Revises: 0134_yeu_cau_tu_lich_xem
"""

from alembic import op
import sqlalchemy as sa

revision = "0135_luot_xem_tin_theo_ngay"
down_revision = "0134_yeu_cau_tu_lich_xem"
branch_labels = None
depends_on = None

_BANG = "house_view_days"


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    if _BANG in set(insp.get_table_names()):
        return
    op.create_table(
        _BANG,
        sa.Column(
            "house_id",
            sa.Integer(),
            sa.ForeignKey("houses.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("ngay", sa.Date(), primary_key=True),
        sa.Column("so_luot", sa.Integer(), nullable=False, server_default="0"),
    )
    # Báo cáo đọc theo khoảng ngày của MỘT nhóm tin.
    op.create_index("ix_house_view_days_ngay", _BANG, ["ngay"])


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    if _BANG in set(insp.get_table_names()):
        op.drop_index("ix_house_view_days_ngay", table_name=_BANG)
        op.drop_table(_BANG)
