"""Bỏ bước "gửi căn phù hợp" khỏi pipeline của sale.

Hệ thống không gửi gì cho khách cả — sale gửi qua Zalo/gọi điện ngoài app —
nên vẽ nó thành một bước của tiến trình là hứa thứ mình không làm. Việc GẮN
CĂN vào yêu cầu vẫn giữ, nhưng là thao tác dữ liệu chứ không phải cái mốc.

Chỉ chuyển trạng thái; các dòng `sale_yeu_cau_moc.moc='da_gui_can'` GIỮ
NGUYÊN vì đó là lịch sử đã xảy ra thật — màn chi tiết chỉ đọc mốc theo danh
sách bước nên chúng tự ẩn.

Revision ID: 0133_bo_buoc_gui_can
Revises: 0132_sale_quan_ly_theo_yeu_cau
"""

from alembic import op
import sqlalchemy as sa

revision = "0133_bo_buoc_gui_can"
down_revision = "0132_sale_quan_ly_theo_yeu_cau"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    if "sale_yeu_cau" not in set(sa.inspect(bind).get_table_names()):
        return
    op.execute(
        sa.text(
            "UPDATE sale_yeu_cau SET trang_thai = 'da_lien_he' "
            "WHERE trang_thai = 'da_gui_can'"
        )
    )


def downgrade() -> None:
    # Không khôi phục được: 'da_lien_he' sau khi gộp không phân biệt được đơn
    # nào từng ở 'da_gui_can'. Mốc lịch sử vẫn còn để tra.
    pass
