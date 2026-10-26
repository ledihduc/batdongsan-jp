"""Bốn PIPELINE khai thác — thêm `mat_bang` và TRẠNG THÁI vòng đời cho từng kênh.

## Vấn đề

`room_kenh` (mig 0092) trả lời được "phòng này bán trên kênh nào, giá bao nhiêu"
nhưng KHÔNG trả lời được "**đang tới đâu rồi**". Mỗi kênh có vòng đời riêng:

    ngan_han : đang rao → có đơn → đang ở → trả phòng
    dai_han  : đang rao → đã cho thuê → hết hạn → rao lại
    mat_bang : như dài hạn, thêm kỳ miễn tiền sửa chữa
    ban      : đang rao → giữ chỗ → đã cọc → ĐÃ BÁN

Hậu quả đo được: ba sale cùng rao một phòng, một người bán được, **hai người
kia vẫn đang rao** — không có chỗ nào ghi "đã bán" để mà dừng lại.

## Vì sao trạng thái đặt trên KÊNH, không đặt trên PHÒNG

Một phòng đang cho thuê dài hạn vẫn có thể đang được rao bán (bán kèm khách
thuê). Hai trạng thái đó chạy song song. Nhét vào một cột trên `rooms` là ép
chọn một, và lại đẻ ra đúng loại lỗi "một cột mang nhiều nghĩa" mà `base_price`
đã gây ra.

## `mat_bang` là kênh thứ tư

Đơn vị giá `m2_thang` đã có sẵn trong mig 0092 nhưng chưa kênh nào dùng tới.
Mặt bằng thương lượng theo m²/tháng, kỳ hạn năm — không phải phòng trọ điền sẵn.

Bất biến: additive · có mặc định · idempotent · có downgrade.

Revision ID: 0098_pipeline_khai_thac
Revises: 0097_dang_nhap_bang_sdt
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0098_pipeline_khai_thac"
down_revision = "0097_dang_nhap_bang_sdt"
branch_labels = None
depends_on = None


def _insp():
    return sa.inspect(op.get_bind())


def _co_bang(ten: str) -> bool:
    return ten in _insp().get_table_names()


def _cot(bang: str) -> set[str]:
    if not _co_bang(bang):
        return set()
    return {c["name"] for c in _insp().get_columns(bang)}


def _co_index(bang: str, ten: str) -> bool:
    if not _co_bang(bang):
        return False
    return any(i["name"] == ten for i in _insp().get_indexes(bang))


def upgrade() -> None:
    if not _co_bang("room_kenh"):
        return

    cot = _cot("room_kenh")

    if "trang_thai" not in cot:
        # 'dang_rao' — mặc định, đúng với mọi dòng đang có.
        # 'giu_cho' | 'da_coc' | 'da_ban'        (kênh ban)
        # 'da_cho_thue'                          (kênh dai_han · mat_bang)
        op.add_column(
            "room_kenh",
            sa.Column(
                "trang_thai",
                sa.String(20),
                nullable=False,
                server_default="dang_rao",
            ),
        )
        op.create_index("ix_room_kenh_trang_thai", "room_kenh", ["trang_thai"])

    if "chot_luc" not in cot:
        # Mốc chuyển sang trạng thái kết thúc (đã bán / đã cho thuê). Không có
        # nó thì không phân biệt được "bán tháng trước" với "bán năm ngoái".
        op.add_column("room_kenh", sa.Column("chot_luc", sa.DateTime, nullable=True))

    if "chot_boi" not in cot:
        op.add_column("room_kenh", sa.Column("chot_boi", sa.Integer, nullable=True))

    # Mặt bằng: kỳ MIỄN TIỀN THUÊ để bên thuê sửa chữa. Là điều khoản chuẩn của
    # thuê thương mại và luôn được thương lượng — không có ô này thì nó nằm
    # trong ghi chú tự do, tức là không thống kê được, không nhắc hạn được.
    if "mien_phi_thang" not in cot:
        op.add_column(
            "room_kenh", sa.Column("mien_phi_thang", sa.Integer, nullable=True)
        )

    # ── Đồng bộ `rooms.status` đang có sang trạng thái kênh dài hạn ──────────
    # Phòng đang `occupied` nghĩa là đã có khách thuê; kênh dài hạn của nó phải
    # nói đúng điều đó, không thì màn "đang rao" hiện cả phòng đã kín.
    op.execute(
        sa.text(
            """
            UPDATE room_kenh k SET trang_thai = 'da_cho_thue'
            FROM rooms r
            WHERE k.room_id = r.id
              AND k.kenh IN ('dai_han', 'mat_bang')
              AND k.trang_thai = 'dang_rao'
              AND r.status = 'occupied'
            """
        )
    )


def downgrade() -> None:
    if not _co_bang("room_kenh"):
        return
    cot = _cot("room_kenh")
    if _co_index("room_kenh", "ix_room_kenh_trang_thai"):
        op.drop_index("ix_room_kenh_trang_thai", table_name="room_kenh")
    for ten in ("mien_phi_thang", "chot_boi", "chot_luc", "trang_thai"):
        if ten in cot:
            op.drop_column("room_kenh", ten)
