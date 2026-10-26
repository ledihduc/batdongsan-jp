"""listing_seller_type

Ai đang đăng tin này: CHỦ NHÀ tự đăng hay ĐĂNG HỘ / môi giới.

Vì sao đặt ở HOUSES chứ không ở host_profiles:
  * Cùng một người có thể tự bán nhà mình VÀ đăng hộ nhà người khác — đặt ở hồ
    sơ người dùng thì buộc phải chọn một, tức là ép dữ liệu nói dối.
  * Câu hỏi được hỏi ĐÚNG LÚC đăng tin (`houses.py` auto-nâng cấp lên host
    ngay tại đó), nên trả lời cũng nên nằm ở tin.
  * Nhãn hiển thị trên hồ sơ suy ra từ các tin, không cần cột thứ hai.

Giá trị: 'owner' (chủ nhà tự đăng) · 'broker' (đăng hộ / môi giới) · ''
(CHƯA KHAI — toàn bộ ~9.000 tin cũ). Rỗng KHÔNG được suy diễn thành 'owner':
app sẽ không hiển thị nhãn gì cả. Gán bừa "chính chủ" cho tin không biết còn
nguy hiểm hơn không nói gì, vì khách sẽ tin ở mức cao hơn thực tế.

CỐ Ý KHÔNG có xác minh giấy tờ ở bước này: đây là TỰ KHAI, nhãn hiển thị phải
ghi rõ "(tự khai)". Luồng nộp chứng chỉ hành nghề + admin duyệt để sau, khi có
môi giới thật yêu cầu.

Bất biến: additive + nullable-tương-đương (server_default '') + idempotent.

Revision ID: 0075_listing_seller_type
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0075_listing_seller_type"
down_revision: Union[str, Sequence[str], None] = "0074_category_groups"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_col(insp, table: str, col: str) -> bool:
    return col in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    if not _has_col(insp, "houses", "seller_type"):
        op.add_column(
            "houses",
            sa.Column(
                "seller_type", sa.String(10), nullable=False, server_default=""
            ),
        )
    idx = {i["name"] for i in insp.get_indexes("houses")}
    if "ix_houses_seller_type" not in idx:
        op.create_index("ix_houses_seller_type", "houses", ["seller_type"])


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    idx = {i["name"] for i in insp.get_indexes("houses")}
    if "ix_houses_seller_type" in idx:
        op.drop_index("ix_houses_seller_type", table_name="houses")
    if _has_col(insp, "houses", "seller_type"):
        op.drop_column("houses", "seller_type")
