"""KÊNH BÁN của phòng + cho phép một phòng có NHIỀU tin đăng theo thời gian.

Hai vấn đề gốc, cùng một nguyên nhân: hệ thống coi phòng chỉ bán được MỘT kiểu,
và tin đăng là bản sao thường trực của phòng. Cả hai đều sai với cách vận hành
thật.

## 1. `room_kenh` — phòng bán trên kênh nào, giá bao nhiêu

Trước: `rooms.base_price` là một số trần mang BỐN nghĩa (giá/đêm · giá/tháng ·
giá/m²/tháng · tổng giá bán). Hậu quả đo được trên staging: một căn hộ cho thuê
5.500.000đ/THÁNG bấm vào ra màn đặt theo ĐÊM, 3 đêm = 16.500.000đ.

Không dùng enum đơn trị trên `rooms` vì **một phòng chạy được nhiều kênh cùng
lúc** — có khách thuê dài thì cho thuê dài, chưa có thì chạy theo đêm cho đỡ
trống. Mỗi kênh còn có tham số riêng (số đêm tối thiểu / số tháng tối thiểu /
cọc mấy tháng), nhét hết vào `rooms` là chục cột rỗng phần lớn thời gian.

`rooms.base_price` GIỮ NGUYÊN làm di sản — nhiều chỗ đang đọc nó. Migration này
chép nó sang kênh `dai_han` cho mọi phòng đang có.

## 2. Bỏ UNIQUE `houses.source_room_id`

Trước: một phòng chỉ được là nguồn của ĐÚNG MỘT tin, vĩnh viễn. Nhưng tin đăng
là QUẢNG CÁO có vòng đời: đăng → tìm được khách → đóng; hết hạn thuê thì rao
lại bằng tin MỚI. Ba lượt khách = ba tin, vẫn một phòng.

Thay bằng UNIQUE MỘT PHẦN: một phòng, một kênh, chỉ được MỘT tin ĐANG RAO. Tin
cũ đã đóng không tính. Đây đúng kỹ thuật đã dùng cho slot đặt xem.

Bất biến: additive · idempotent · có downgrade.

Revision ID: 0092_kenh_ban_cua_phong
Revises: 0091_go_dich_vu_trung_lap
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0092_kenh_ban_cua_phong"
down_revision = "0091_go_dich_vu_trung_lap"
branch_labels = None
depends_on = None

_UNIQUE_CU = "uq_houses_source_room_id"
_UNIQUE_MOI = "uq_tin_dang_rao"


def _insp():
    return sa.inspect(op.get_bind())


def _co_bang(ten: str) -> bool:
    return ten in _insp().get_table_names()


def _co_index(bang: str, ten: str) -> bool:
    if not _co_bang(bang):
        return False
    return any(i["name"] == ten for i in _insp().get_indexes(bang))


def _co_unique(bang: str, ten: str) -> bool:
    if not _co_bang(bang):
        return False
    return any(c["name"] == ten for c in _insp().get_unique_constraints(bang))


def _la_postgres() -> bool:
    return op.get_bind().dialect.name == "postgresql"


def upgrade() -> None:
    # ── 1. Bảng kênh bán ─────────────────────────────────────────────────────
    if not _co_bang("room_kenh"):
        op.create_table(
            "room_kenh",
            sa.Column("id", sa.Integer, primary_key=True),
            sa.Column(
                "room_id",
                sa.Integer,
                sa.ForeignKey("rooms.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            # 'ngan_han' (theo đêm) · 'dai_han' (theo tháng) · 'ban' (tổng giá)
            sa.Column("kenh", sa.String(20), nullable=False),
            sa.Column("gia", sa.Float, nullable=False, server_default="0"),
            # 'dem' | 'thang' | 'm2_thang' | 'tong' — ĐƠN VỊ đi kèm giá, chính là
            # thứ thiếu ở `base_price` và gây ra bug nhân giá tháng với số đêm.
            sa.Column("don_vi", sa.String(20), nullable=False),
            # Số đêm / số tháng tối thiểu. NULL = không ràng buộc.
            sa.Column("toi_thieu", sa.Integer, nullable=True),
            # Cọc: số tháng (thuê) hoặc phần trăm (bán).
            sa.Column("dat_coc", sa.Float, nullable=True),
            sa.Column(
                "dang_bat",
                sa.Boolean,
                nullable=False,
                server_default=sa.true(),
                index=True,
            ),
            sa.Column(
                "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
            ),
            sa.Column(
                "updated_at", sa.DateTime, nullable=False, server_default=sa.func.now()
            ),
            sa.UniqueConstraint("room_id", "kenh", name="uq_room_kenh"),
        )

    # ── 2. Chép base_price sang kênh dai_han cho phòng đang có ───────────────
    # Mọi phòng hiện tại đều là cho thuê dài hạn (0/22 phòng có is_homestay).
    # Phòng nào đã có dòng kênh rồi thì bỏ qua — chạy lại không nhân đôi.
    if _co_bang("rooms") and _co_bang("room_kenh"):
        op.execute(
            sa.text(
                """
                INSERT INTO room_kenh (room_id, kenh, gia, don_vi, dang_bat)
                SELECT r.id,
                       CASE WHEN r.is_homestay THEN 'ngan_han' ELSE 'dai_han' END,
                       COALESCE(r.base_price, 0),
                       CASE WHEN r.is_homestay THEN 'dem' ELSE 'thang' END,
                       TRUE
                FROM rooms r
                WHERE NOT EXISTS (
                    SELECT 1 FROM room_kenh k WHERE k.room_id = r.id
                )
                """
            )
        )

    # ── 3. Một phòng được NHIỀU tin theo thời gian ───────────────────────────
    # UNIQUE cũ chặn cứng việc rao lại. Thay bằng partial unique: chỉ chặn hai
    # tin CÙNG ĐANG RAO trên cùng một phòng + cùng kênh.
    if _co_unique("houses", _UNIQUE_CU):
        op.drop_constraint(_UNIQUE_CU, "houses", type_="unique")
    elif _co_index("houses", _UNIQUE_CU):
        op.drop_index(_UNIQUE_CU, table_name="houses")

    if _la_postgres() and not _co_index("houses", _UNIQUE_MOI):
        op.execute(
            sa.text(
                f"""
                CREATE UNIQUE INDEX {_UNIQUE_MOI}
                ON houses (source_room_id, transaction_type, product_type)
                WHERE status = 'published' AND source_room_id IS NOT NULL
                """
            )
        )

    # ── 4. Vòng đời tin đăng ────────────────────────────────────────────────
    # Không có mốc kết thúc thì không phân biệt được "tin đang tìm khách" với
    # "tin của lượt thuê năm ngoái" — mà phân biệt đó chính là thứ làm cho quan
    # hệ một-phòng-nhiều-tin có nghĩa.
    if _co_bang("houses"):
        cot = {c["name"] for c in _insp().get_columns("houses")}
        if "ket_thuc_luc" not in cot:
            op.add_column(
                "houses", sa.Column("ket_thuc_luc", sa.DateTime, nullable=True)
            )
        if "ly_do_ket_thuc" not in cot:
            # 'da_cho_thue' | 'da_ban' | 'het_han' | 'chu_go'
            op.add_column(
                "houses", sa.Column("ly_do_ket_thuc", sa.String(20), nullable=True)
            )


def downgrade() -> None:
    if _co_bang("houses"):
        cot = {c["name"] for c in _insp().get_columns("houses")}
        if "ly_do_ket_thuc" in cot:
            op.drop_column("houses", "ly_do_ket_thuc")
        if "ket_thuc_luc" in cot:
            op.drop_column("houses", "ket_thuc_luc")

    if _co_index("houses", _UNIQUE_MOI):
        op.drop_index(_UNIQUE_MOI, table_name="houses")

    # Khôi phục UNIQUE cũ CHỈ KHI dữ liệu cho phép — nếu đã có phòng nhiều tin
    # thì dựng lại ràng buộc sẽ nổ. Thà để không có còn hơn làm hỏng downgrade.
    if _co_bang("houses"):
        trung = op.get_bind().execute(
            sa.text(
                """
                SELECT COUNT(*) FROM (
                    SELECT source_room_id FROM houses
                    WHERE source_room_id IS NOT NULL
                    GROUP BY source_room_id HAVING COUNT(*) > 1
                ) t
                """
            )
        ).scalar()
        if not trung and not _co_unique("houses", _UNIQUE_CU):
            op.create_unique_constraint(_UNIQUE_CU, "houses", ["source_room_id"])

    if _co_bang("room_kenh"):
        op.drop_table("room_kenh")
