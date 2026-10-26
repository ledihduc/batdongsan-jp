"""`push_outbox` — hàng đợi gửi FCM, ghi CÙNG giao dịch nghiệp vụ.

## Vấn đề

Thông báo trong app đã lưu đúng (`notifications`), nhưng chưa có gì đẩy FCM.
Cách làm ngây thơ — gọi FCM ngay trong hàm xử lý — hỏng theo hai chiều:

  * FCM chậm hoặc lỗi → giao dịch nghiệp vụ chậm theo, hoặc bị kéo đổ. Bán một
    căn hộ mà thất bại vì Google trả 503 là vô lý.
  * Gọi TRƯỚC khi commit → có thể báo "phòng đã bán" rồi giao dịch rollback.
    Người dùng nhận tin về một việc chưa từng xảy ra.

## Mẫu outbox

Ghi ý định gửi vào bảng này, **trong cùng transaction** với dữ liệu nghiệp vụ.
Hai thứ cùng sống hoặc cùng chết — không có khe hở. Một tiến trình khác đọc
hàng đợi và gửi; gửi hỏng thì tăng `so_lan_thu` và thử lại sau, giao dịch gốc
không hề hay biết.

## Chống gửi trùng

`khoa_gom` = "loại sự kiện + đối tượng" (vd `tin_da_dong:phong-13`). Unique một
phần trên `(user_id, khoa_gom) WHERE gui_luc IS NULL`: một người bị đóng ba tin
cùng lúc chỉ nhận MỘT push. Chỉ chặn khi còn CHỜ GỬI — sự kiện tương tự tháng
sau vẫn gửi được.

Bất biến: additive · idempotent · có downgrade.

Revision ID: 0101_hang_doi_push
Revises: 0100_kenh_cua_tin
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0101_hang_doi_push"
down_revision = "0100_kenh_cua_tin"
branch_labels = None
depends_on = None

_BANG = "push_outbox"
_IDX = "uq_push_outbox_cho_gui"


def _insp():
    return sa.inspect(op.get_bind())


def _co_bang(ten: str) -> bool:
    return ten in _insp().get_table_names()


def _co_index(bang: str, ten: str) -> bool:
    if not _co_bang(bang):
        return False
    return any(i["name"] == ten for i in _insp().get_indexes(bang))


def upgrade() -> None:
    if not _co_bang(_BANG):
        op.create_table(
            _BANG,
            sa.Column("id", sa.Integer, primary_key=True),
            sa.Column(
                "user_id",
                sa.Integer,
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            sa.Column("title", sa.String(200), nullable=False),
            sa.Column("body", sa.Text, nullable=False),
            sa.Column("loai", sa.String(50), nullable=False),
            sa.Column("related_id", sa.Integer, nullable=True),
            #: "loại sự kiện + đối tượng" — chống gửi trùng khi một người bị
            #: ảnh hưởng bởi nhiều bản ghi trong cùng một hành động.
            sa.Column("khoa_gom", sa.String(100), nullable=False),
            sa.Column(
                "tao_luc", sa.DateTime, nullable=False, server_default=sa.func.now()
            ),
            #: NULL = còn chờ gửi. Đây cũng là điều kiện của unique một phần.
            sa.Column("gui_luc", sa.DateTime, nullable=True),
            sa.Column(
                "so_lan_thu", sa.Integer, nullable=False, server_default="0"
            ),
            sa.Column("loi_cuoi", sa.String(300), nullable=True),
        )
        op.create_index(f"ix_{_BANG}_cho_gui", _BANG, ["gui_luc", "tao_luc"])

    if op.get_bind().dialect.name == "postgresql" and not _co_index(_BANG, _IDX):
        op.execute(
            sa.text(
                f"""
                CREATE UNIQUE INDEX {_IDX} ON {_BANG} (user_id, khoa_gom)
                WHERE gui_luc IS NULL
                """
            )
        )


def downgrade() -> None:
    if _co_bang(_BANG):
        op.drop_table(_BANG)
