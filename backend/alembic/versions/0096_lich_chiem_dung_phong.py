"""`room_chiem_dung` — MỘT dòng thời gian chiếm dụng cho MỌI kênh (đợt D — R4/D1).

## Vấn đề

Một phòng bán được trên nhiều kênh cùng lúc (`room_kenh`, mig 0092): chưa có
khách thuê dài thì cho thuê theo đêm cho đỡ trống. Nhưng "phòng có trống không"
đang được trả lời bằng HAI nguồn không biết nhau:

    ngắn hạn  →  `reservations` (có EXCLUDE chống trùng — chỉ trong nội bộ nó)
    dài hạn   →  `rooms.status` = 'vacant' | 'occupied'  (một cờ, KHÔNG có ngày)

Hậu quả nếu mở hai kênh cùng lúc: hợp đồng thuê từ 01/10 không chặn được ai đặt
đêm 15/10, vì `reservations` không hề nhìn thấy `contracts`. Và cờ `vacant` thì
không trả lời được "trống từ ngày nào" — chủ nhà không có lịch để nhìn, chỉ có
một bóng đèn bật/tắt.

Đây là điều kiện CHẶN của việc mở hai kênh, nên bảng này phải có trước.

## Cách sửa

Một bảng duy nhất ghi "phòng X bận từ ngày A đến ngày B, vì lý do gì". Mọi kênh
ghi vào đây; ràng buộc `EXCLUDE USING gist` khiến hai khoảng chồng nhau trên
cùng một phòng **không thể tồn tại** — không phải nhờ code nhớ kiểm, mà nhờ DB
từ chối. Đây đúng kỹ thuật đã dùng cho `reservations` và slot đặt xem.

`den_ngay` là ngày TRẢ phòng, **không tính** (nửa khoảng `[)`) — trùng quy ước
`reservations.check_out_date`. Nhờ vậy trả sáng nay / nhận chiều nay không bị
tính là chồng lấn. Hợp đồng ghi ngày cuối cùng còn hiệu lực nên backfill cộng
thêm một ngày.

## Backfill

Chèn từng dòng trong khối con có bắt lỗi: dữ liệu cũ CÓ THỂ chồng nhau (trước
nay không gì cấm), và một dòng xấu không được làm hỏng cả migration. Dòng bị
chối chỉ có nghĩa "khoảng đó đã có người khác giữ" — thứ tự ưu tiên: hợp đồng
trước, đơn đặt đêm sau.

Bất biến: additive · idempotent (dedup theo `nguon`+`nguon_id`) · có downgrade.

Revision ID: 0096_lich_chiem_dung_phong
Revises: 0095_lich_xem_neo_phong
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0096_lich_chiem_dung_phong"
down_revision = "0095_lich_xem_neo_phong"
branch_labels = None
depends_on = None

_BANG = "room_chiem_dung"
_EXCL = "excl_room_chiem_dung_trung"


def _insp():
    return sa.inspect(op.get_bind())


def _co_bang(ten: str) -> bool:
    return ten in _insp().get_table_names()


def _la_postgres() -> bool:
    return op.get_bind().dialect.name == "postgresql"


def upgrade() -> None:
    if not _co_bang(_BANG):
        op.create_table(
            _BANG,
            sa.Column("id", sa.Integer, primary_key=True),
            sa.Column(
                "room_id",
                sa.Integer,
                sa.ForeignKey("rooms.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            sa.Column("tu_ngay", sa.Date, nullable=False),
            # Ngày TRẢ phòng — KHÔNG tính vào khoảng bận.
            sa.Column("den_ngay", sa.Date, nullable=False),
            # 'ngan_han' | 'dai_han' | 'khoa' (chủ nhà tự chặn: sửa chữa, để
            # dành cho người nhà…). Khớp `room_kenh.kenh`, thêm 'khoa'.
            sa.Column("kenh", sa.String(20), nullable=False, server_default="dai_han"),
            # 'reservation' | 'contract' | 'thu_cong' — biết ai sinh ra dòng này
            # thì mới gỡ đúng dòng khi đơn/hợp đồng bị huỷ.
            sa.Column("nguon", sa.String(20), nullable=False, server_default="thu_cong"),
            sa.Column("nguon_id", sa.Integer, nullable=True),
            sa.Column("ghi_chu", sa.String(300), nullable=True),
            sa.Column(
                "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
            ),
        )
        op.create_index(
            f"ix_{_BANG}_nguon", _BANG, ["nguon", "nguon_id"]
        )

    # Ràng buộc chống chồng lấn. Chỉ Postgres — SQLite (test) không có gist,
    # tầng service vẫn kiểm bằng câu truy vấn nên test không mất ý nghĩa.
    if _la_postgres():
        co_excl = op.get_bind().execute(
            sa.text(
                "SELECT 1 FROM pg_constraint WHERE conname = :t"
            ),
            {"t": _EXCL},
        ).first()
        if not co_excl:
            op.execute(sa.text("CREATE EXTENSION IF NOT EXISTS btree_gist"))
            op.execute(
                sa.text(
                    f"""
                    ALTER TABLE {_BANG} ADD CONSTRAINT {_EXCL}
                    EXCLUDE USING gist (
                        room_id WITH =,
                        daterange(tu_ngay, den_ngay, '[)') WITH &&
                    )
                    """
                )
            )
        # Khoảng rỗng/ngược ngày lọt qua EXCLUDE (daterange rỗng không chồng ai)
        # nhưng vô nghĩa với người đọc lịch.
        co_chk = op.get_bind().execute(
            sa.text("SELECT 1 FROM pg_constraint WHERE conname = 'ck_room_chiem_dung_ngay'")
        ).first()
        if not co_chk:
            op.execute(
                sa.text(
                    f"ALTER TABLE {_BANG} ADD CONSTRAINT ck_room_chiem_dung_ngay "
                    f"CHECK (den_ngay > tu_ngay)"
                )
            )

    if not _la_postgres():
        return

    # ── Backfill: hợp đồng trước (kỳ hạn dài, ưu tiên cao), đơn đêm sau ──────
    op.execute(
        sa.text(
            f"""
            DO $$
            DECLARE r RECORD;
            BEGIN
                FOR r IN
                    SELECT c.id, c.room_id, c.start_date::date AS tu,
                           (c.end_date::date + 1) AS den
                    FROM contracts c
                    WHERE c.status = 'active'
                      AND c.start_date ~ '^\\d{{4}}-\\d{{2}}-\\d{{2}}$'
                      AND c.end_date   ~ '^\\d{{4}}-\\d{{2}}-\\d{{2}}$'
                      AND c.end_date::date >= c.start_date::date
                      AND NOT EXISTS (
                          SELECT 1 FROM {_BANG} k
                          WHERE k.nguon = 'contract' AND k.nguon_id = c.id
                      )
                LOOP
                    BEGIN
                        INSERT INTO {_BANG}
                            (room_id, tu_ngay, den_ngay, kenh, nguon, nguon_id)
                        VALUES (r.room_id, r.tu, r.den, 'dai_han', 'contract', r.id);
                    EXCEPTION WHEN exclusion_violation OR check_violation THEN
                        NULL;  -- khoảng đã có người giữ; bỏ qua, không chặn migration
                    END;
                END LOOP;

                FOR r IN
                    SELECT s.id, s.room_id, s.check_in_date AS tu,
                           s.check_out_date AS den
                    FROM reservations s
                    WHERE s.status IN ('pending','approved','checked_in')
                      AND s.check_out_date > s.check_in_date
                      AND NOT EXISTS (
                          SELECT 1 FROM {_BANG} k
                          WHERE k.nguon = 'reservation' AND k.nguon_id = s.id
                      )
                LOOP
                    BEGIN
                        INSERT INTO {_BANG}
                            (room_id, tu_ngay, den_ngay, kenh, nguon, nguon_id)
                        VALUES (r.room_id, r.tu, r.den, 'ngan_han', 'reservation', r.id);
                    EXCEPTION WHEN exclusion_violation OR check_violation THEN
                        NULL;
                    END;
                END LOOP;
            END $$;
            """
        )
    )


def downgrade() -> None:
    if _co_bang(_BANG):
        op.drop_table(_BANG)
