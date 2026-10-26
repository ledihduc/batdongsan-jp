"""category_groups

Gom danh mục BĐS thành 3 NHÓM MASTER (theo bảng chủ dự án chốt 24/08/2026):

    Lưu trú dài hạn (stay_long)  : Phòng trọ · Chung cư mini · Căn hộ · Nhà nguyên căn
    Lưu trú ngắn hạn (stay_short): Villa · Hotel · Motel · Home stay
    Kinh doanh (business)        : Mặt bằng cửa hàng · Shop house · Văn phòng · Kho xưởng

Nhóm dùng để TÔ MÀU PIN trên bản đồ và để người đăng tin chọn 2 bước
(nhóm → loại). Màu KHÔNG lưu ở DB — nằm trong design token của app, đổi màu
không phải deploy backend.

Bất biến: additive (chỉ thêm cột, nullable/có default) + idempotent.

NGOẠI LỆ CÓ CHỦ Ý — phần DUY NHẤT không thuần additive: gộp 2 danh mục
"Penthouse" và "Studio" vào "Căn hộ" (bảng master không có 2 loại này). Việc
này ĐỔI `houses.category_id` của ~3.000 tin, nên trước khi đổi có lưu ánh xạ cũ
vào bảng `mig0074_house_category_backup` để `downgrade()` khôi phục ĐÚNG từng
tin. Không xoá dòng danh mục nào — 2 loại cũ chỉ bị `is_active=false`.

Revision ID: 0074_category_groups
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0074_category_groups"
down_revision: Union[str, Sequence[str], None] = "0073_contractor_legal_verify"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_BACKUP_TABLE = "mig0074_house_category_backup"

# (tên, nhóm, icon material, thứ tự trong nhóm)
_MASTER: list[tuple[str, str, str, int]] = [
    ("Phòng trọ", "stay_long", "bed", 1),
    ("Chung cư mini", "stay_long", "apartment", 2),
    ("Căn hộ", "stay_long", "apartment", 3),
    ("Nhà nguyên căn", "stay_long", "home", 4),
    ("Villa", "stay_short", "villa", 1),
    ("Hotel", "stay_short", "hotel", 2),
    ("Motel", "stay_short", "night_shelter", 3),
    ("Home stay", "stay_short", "holiday_village", 4),
    ("Mặt bằng cửa hàng", "business", "storefront", 1),
    ("Shop house", "business", "store", 2),
    ("Văn phòng", "business", "corporate_fare", 3),
    ("Kho xưởng", "business", "warehouse", 4),
]

# Danh mục cũ đổi TÊN sang loại tương đương (giữ nguyên id → tin không phải đổi).
_RENAME = {
    "Nhà phố": "Nhà nguyên căn",
    "Biệt thự": "Villa",
    "BĐS công nghiệp": "Kho xưởng",
}

# Danh mục cũ KHÔNG có trong master → dồn tin sang loại đích rồi tắt.
_MERGE_INTO = {
    "Penthouse": "Căn hộ",
    "Studio": "Căn hộ",
}


def _has_col(insp, table: str, col: str) -> bool:
    return col in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # ── 1. Cột mới trên categories ───────────────────────────────────────────
    if not _has_col(insp, "categories", "group_key"):
        op.add_column(
            "categories",
            sa.Column("group_key", sa.String(16), nullable=False, server_default=""),
        )
    if not _has_col(insp, "categories", "sort_order"):
        op.add_column(
            "categories",
            sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
        )
    if not _has_col(insp, "categories", "is_active"):
        op.add_column(
            "categories",
            sa.Column(
                "is_active", sa.Boolean, nullable=False, server_default=sa.true()
            ),
        )
    idx = {i["name"] for i in insp.get_indexes("categories")}
    if "ix_categories_group_key" not in idx:
        op.create_index("ix_categories_group_key", "categories", ["group_key"])

    # ── 2. Đổi tên danh mục cũ sang loại tương đương ─────────────────────────
    for old, new in _RENAME.items():
        # Chỉ đổi khi tên đích CHƯA tồn tại — tránh tạo hai dòng trùng tên khi
        # chạy lại hoặc khi DB đã có sẵn loại đó.
        exists_new = bind.execute(
            sa.text("SELECT id FROM categories WHERE name = :n"), {"n": new}
        ).first()
        if exists_new is None:
            bind.execute(
                sa.text("UPDATE categories SET name = :new WHERE name = :old"),
                {"new": new, "old": old},
            )

    # ── 3. Thêm loại còn thiếu + gán nhóm/thứ tự cho tất cả ──────────────────
    for name, group, icon, order in _MASTER:
        row = bind.execute(
            sa.text("SELECT id FROM categories WHERE name = :n"), {"n": name}
        ).first()
        if row is None:
            bind.execute(
                sa.text(
                    "INSERT INTO categories (name, icon, group_key, sort_order,"
                    " is_active) VALUES (:n, :i, :g, :o, TRUE)"
                ),
                {"n": name, "i": icon, "g": group, "o": order},
            )
        else:
            bind.execute(
                sa.text(
                    "UPDATE categories SET group_key = :g, sort_order = :o,"
                    " is_active = TRUE, icon = CASE WHEN icon = '' THEN :i ELSE icon END"
                    " WHERE id = :id"
                ),
                {"g": group, "o": order, "i": icon, "id": row[0]},
            )

    # ── 4. Gộp Penthouse/Studio vào Căn hộ (có sao lưu để hoàn tác) ──────────
    if _BACKUP_TABLE not in insp.get_table_names():
        op.create_table(
            _BACKUP_TABLE,
            sa.Column("house_id", sa.Integer, primary_key=True),
            sa.Column("old_category_id", sa.Integer, nullable=False),
        )
    for old, target in _MERGE_INTO.items():
        old_row = bind.execute(
            sa.text("SELECT id FROM categories WHERE name = :n"), {"n": old}
        ).first()
        new_row = bind.execute(
            sa.text("SELECT id FROM categories WHERE name = :n"), {"n": target}
        ).first()
        if old_row is None or new_row is None or old_row[0] == new_row[0]:
            continue
        old_id, new_id = old_row[0], new_row[0]
        # Lưu ánh xạ TRƯỚC khi đổi; ON CONFLICT để chạy lại không nhân đôi.
        bind.execute(
            sa.text(
                f"INSERT INTO {_BACKUP_TABLE} (house_id, old_category_id) "
                "SELECT id, category_id FROM houses WHERE category_id = :old "
                "ON CONFLICT (house_id) DO NOTHING"
            ),
            {"old": old_id},
        )
        bind.execute(
            sa.text("UPDATE houses SET category_id = :new WHERE category_id = :old"),
            {"new": new_id, "old": old_id},
        )
        # Giữ dòng danh mục (tin cũ trong log/báo cáo còn tra được tên) nhưng
        # ẩn khỏi mọi nơi chọn danh mục.
        bind.execute(
            sa.text(
                "UPDATE categories SET is_active = FALSE, group_key = '',"
                " sort_order = 0 WHERE id = :id"
            ),
            {"id": old_id},
        )

    # Danh mục lạ (nếu có) chưa thuộc nhóm nào → coi như dài hạn để không biến
    # mất khỏi bộ lọc; admin đổi lại sau.
    bind.execute(
        sa.text(
            "UPDATE categories SET group_key = 'stay_long'"
            " WHERE is_active = TRUE AND (group_key IS NULL OR group_key = '')"
        )
    )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # 1. Trả tin về danh mục cũ theo bảng sao lưu.
    if _BACKUP_TABLE in insp.get_table_names():
        bind.execute(
            sa.text(
                f"UPDATE houses SET category_id = b.old_category_id "
                f"FROM {_BACKUP_TABLE} b WHERE houses.id = b.house_id"
            )
        )
        op.drop_table(_BACKUP_TABLE)

    # 2. Bật lại các danh mục đã ẩn + trả tên cũ.
    bind.execute(sa.text("UPDATE categories SET is_active = TRUE"))
    for old, new in _RENAME.items():
        bind.execute(
            sa.text("UPDATE categories SET name = :old WHERE name = :new"),
            {"old": old, "new": new},
        )

    # 3. Bỏ cột (dữ liệu nhóm mất theo — đúng bản chất downgrade).
    #
    # CỐ Ý KHÔNG xoá 7 loại mới thêm (Chung cư mini, Hotel, Motel, Home stay,
    # Mặt bằng cửa hàng, Shop house, Văn phòng): sau khi upgrade có thể đã có
    # tin đăng trỏ vào chúng, xoá là làm mồ côi dữ liệu thật. Chúng chỉ nằm im
    # trong danh sách nếu quay về bản cũ.
    idx = {i["name"] for i in insp.get_indexes("categories")}
    if "ix_categories_group_key" in idx:
        op.drop_index("ix_categories_group_key", table_name="categories")
    for col in ("group_key", "sort_order", "is_active"):
        if _has_col(insp, "categories", col):
            op.drop_column("categories", col)
