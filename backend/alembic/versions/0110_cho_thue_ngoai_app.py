"""Phòng cho thuê NGOÀI APP: hợp đồng ghi nhận nhẹ + ghi chú.

## Vấn đề

Chủ nhà tìm được khách bằng Facebook, Zalo, môi giới, người quen — phần lớn
khách thuê ở VN đến đường đó. Hôm nay app không có cách nào nói "phòng này đã
cho thuê rồi, tôi tự tìm khách": phòng vẫn nằm trên chợ, khách vẫn gọi vào tin
đã chết, và Sổ phòng vẫn đếm nó là phòng trống.

Không thêm trục "đang thuê" thứ ba. Sự thật "phòng có người" trong hệ này suy từ
HỢP ĐỒNG (dài hạn) hoặc LƯU TRÚ (ngắn hạn) — xem `services/so_phong.py`. Thêm
một cờ trên `rooms` là sinh ra câu trả lời thứ ba cho cùng một câu hỏi, và mọi
chỗ đếm phòng sẽ lệch nhau. Nên "cho thuê ngoài app" = một hợp đồng THẬT, gọn
(ngày bắt đầu · tiền thuê · tên khách), được đánh dấu `ngoai_luong=True`.

Dấu đó để làm gì, không phải để trang trí:
  * app biết người thuê này KHÔNG có tài khoản → đừng chờ họ gửi ảnh công tơ,
    chủ nhà tự chụp (xem `nguon_anh='chu_nha'`, mig 0109);
  * báo cáo tách được khách từ app và khách tự tìm — con số duy nhất trả lời
    "app có mang lại khách không";
  * bấm nhầm thì bỏ đánh dấu được, còn hợp đồng thật thì phải trả phòng đúng
    quy trình.

`ghi_chu`: chỗ ghi "thuê qua Facebook, chưa làm giấy tờ" — hợp đồng ngoài luồng
thường không có gì khác để tra.

Bất biến: additive · nullable (trừ cờ có server_default) · idempotent · có downgrade.

Revision ID: 0110_cho_thue_ngoai_app
Revises: 0109_anh_cong_to_chu_nha
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0110_cho_thue_ngoai_app"
down_revision = "0109_anh_cong_to_chu_nha"
branch_labels = None
depends_on = None


def _cot(bang: str) -> set[str]:
    insp = sa.inspect(op.get_bind())
    if bang not in insp.get_table_names():
        return set()
    return {c["name"] for c in insp.get_columns(bang)}


def upgrade() -> None:
    co = _cot("contracts")
    if not co:
        return
    if "ngoai_luong" not in co:
        op.add_column(
            "contracts",
            # server_default để hàng cũ thành False ngay, không cần UPDATE bảng;
            # nullable=False vì "không biết có phải ngoài luồng hay không" không
            # là một trạng thái có nghĩa.
            sa.Column(
                "ngoai_luong",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            ),
        )
    if "ghi_chu" not in co:
        op.add_column("contracts", sa.Column("ghi_chu", sa.Text(), nullable=True))


def downgrade() -> None:
    co = _cot("contracts")
    for ten in ("ghi_chu", "ngoai_luong"):
        if ten in co:
            op.drop_column("contracts", ten)
