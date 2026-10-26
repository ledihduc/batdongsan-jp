"""Gỡ nhóm "Mua bán & pháp lý" và dịch vụ "Xây dựng" trùng lặp.

Hai quyết định của chủ sản phẩm:

1. **"Xây dựng" trùng với "Thi công trọn gói"** — cùng một việc, để cả hai thì
   khách phải đoán chúng khác nhau chỗ nào rồi chọn bừa. Giữ `turnkey` vì tên
   nó nói rõ phạm vi.

2. **Bỏ hẳn khu "Mua bán & pháp lý"** (định giá · sang tên · vay vốn · kiểm
   định). `fengshui` KHÔNG bị gỡ — nó chuyển sang khu "Thiết kế & Thi công",
   vì xem hướng, xem tuổi là việc làm TRƯỚC KHI xây và sửa, cùng lúc với thiết
   kế, chứ không phải lúc sang tên sổ. Việc chuyển nhóm nằm ở app (danh sách
   `_cacKhu`), không ở đây.

TẮT chứ không XOÁ hàng: `service_requests` cũ vẫn trỏ tới các slug này. Xoá
hàng là đơn cũ mất tên dịch vụ, còn lại một mã trơ trong lịch sử của khách.

GHI CẢ HAI BẢNG, cùng lý do migration 0080 đã nêu: `construction_services` là
bảng bản đang chạy đọc, `services` là bảng của 0079. Sửa một bảng thì hoặc
dịch vụ vẫn hiện bây giờ, hoặc hiện lại sau khi deploy bản mới.

Bất biến: idempotent · có downgrade.

Revision ID: 0091_go_dich_vu_trung_lap
Revises: 0090_tin_dang_xa_hoi
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0091_go_dich_vu_trung_lap"
down_revision = "0090_tin_dang_xa_hoi"
branch_labels = None
depends_on = None

_TAT = ("build", "valuation", "legal_transfer", "home_loan", "inspection")
_BANG = ("construction_services", "services")


def _co_bang(ten: str) -> bool:
    return ten in sa.inspect(op.get_bind()).get_table_names()


def _dat(gia_tri: bool) -> None:
    bind = op.get_bind()
    for bang in _BANG:
        if not _co_bang(bang):
            continue
        bind.execute(
            sa.text(
                f"UPDATE {bang} SET is_active = :v WHERE slug IN :slugs"  # noqa: S608
            ).bindparams(sa.bindparam("slugs", expanding=True)),
            {"v": gia_tri, "slugs": list(_TAT)},
        )


def upgrade() -> None:
    _dat(False)


def downgrade() -> None:
    _dat(True)
