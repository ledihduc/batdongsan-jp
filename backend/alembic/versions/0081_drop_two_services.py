"""drop_two_services — bỏ 'chụp ảnh bán nhà' và 'dọn sửa để bán nhanh'

Hai dịch vụ này được thêm ở 0080 nhưng KHÔNG nằm trong phạm vi sản phẩm muốn
làm. Gỡ sớm khi chưa ai đặt còn hơn để đó rồi phải đỡ những yêu cầu không có
đơn vị nào nhận.

TẮT chứ không XOÁ (`is_active = false`): nếu về sau có yêu cầu thật trỏ tới
slug này, xoá dòng đi sẽ khiến yêu cầu đó mồ côi — không tra ngược ra tên dịch
vụ nữa. Route danh mục đã lọc `is_active`, nên tắt là đủ để chúng biến mất.

Bất biến: additive · idempotent · có downgrade.

Revision ID: 0081_drop_two_services
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0081_drop_two_services"
down_revision: Union[str, Sequence[str], None] = "0080_realestate_services"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_BO = ["photo_listing", "staging"]
_BANG = ("construction_services", "services")


def _dat(bind, insp, gia_tri: bool) -> None:
    co = set(insp.get_table_names())
    for bang in _BANG:
        if bang not in co:
            continue
        bind.execute(
            sa.text(
                f"UPDATE {bang} SET is_active = :v WHERE slug IN :slugs"
            ).bindparams(sa.bindparam("slugs", expanding=True)),
            {"v": gia_tri, "slugs": _BO},
        )


def upgrade() -> None:
    bind = op.get_bind()
    _dat(bind, sa.inspect(bind), False)


def downgrade() -> None:
    bind = op.get_bind()
    _dat(bind, sa.inspect(bind), True)
