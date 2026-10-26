"""Đăng nhập bằng EMAIL **hoặc** SỐ ĐIỆN THOẠI — một ô duy nhất.

## Vì sao

Người Việt nhớ số điện thoại của mình, không phải lúc nào cũng nhớ email — và
nhiều người bán hàng chỉ có Zalo, không dùng email bao giờ. Bắt buộc email lúc
đăng ký là một rào chắn ngay ở cửa vào.

## Cột nào thành khoá

Cho đăng nhập bằng SĐT nghĩa là `users.phone` trở thành **khoá định danh**,
ngang hàng email. Nó đang là cột thường: mặc định `''`, không ràng buộc gì. Hai
người cùng một số thì `/login` không biết trả về ai.

Đo trước khi làm (08/09/2026): 30 tài khoản · 17 có số · **0 số trùng** · 16 số
đúng dạng `0xxxxxxxxx`. Nên thêm ràng buộc được ngay, không phải dọn dữ liệu.

## Vì sao là UNIQUE MỘT PHẦN, không phải UNIQUE thường

Cả hai cột đều dùng `''` cho "không có". Postgres coi `''` là một giá trị THẬT
nên `UNIQUE` thường sẽ chặn người thứ hai không có số — tức là chặn đúng 13
tài khoản đang tồn tại. `WHERE <> ''` bỏ nhóm rỗng ra khỏi phạm vi ràng buộc.

Đây cũng là lý do phải HẠ `ix_users_email` từ unique thường xuống unique một
phần: từ nay email được phép rỗng (người đăng ký bằng số).

## Chuẩn hoá số cũ

Chỉ đổi những số CHẮC CHẮN suy ra được (`+84…`/`84…` → `0…`) và chỉ khi không
đụng số của người khác. Số lệch chuẩn (vd `8478553330`) GIỮ NGUYÊN — đoán sai
một chữ số là gán tài khoản cho người khác; chủ tài khoản đó vẫn đăng nhập bằng
email như trước.

Bất biến: additive · idempotent · có downgrade.

Revision ID: 0097_dang_nhap_bang_sdt
Revises: 0096_lich_chiem_dung_phong
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0097_dang_nhap_bang_sdt"
down_revision = "0096_lich_chiem_dung_phong"
branch_labels = None
depends_on = None

_IDX_EMAIL_CU = "ix_users_email"
_IDX_EMAIL = "uq_users_email_khac_rong"
_IDX_PHONE = "uq_users_phone_khac_rong"


def _insp():
    return sa.inspect(op.get_bind())


def _co_bang(ten: str) -> bool:
    return ten in _insp().get_table_names()


def _co_index(bang: str, ten: str) -> bool:
    if not _co_bang(bang):
        return False
    return any(i["name"] == ten for i in _insp().get_indexes(bang))


def _la_postgres() -> bool:
    return op.get_bind().dialect.name == "postgresql"


def upgrade() -> None:
    if not _co_bang("users") or not _la_postgres():
        return

    # ── 1. Chuẩn hoá số cũ về `0xxxxxxxxx` ──────────────────────────────────
    # `NOT EXISTS` chặn việc chuẩn hoá xong đụng số người khác — thà để lệch
    # chuẩn còn hơn tạo ra một cặp trùng rồi ràng buộc bên dưới nổ.
    op.execute(
        sa.text(
            r"""
            UPDATE users u SET phone = '0' || substring(u.phone from 3)
            WHERE u.phone ~ '^84[35789][0-9]{8}$'
              AND NOT EXISTS (
                  SELECT 1 FROM users x
                  WHERE x.id <> u.id
                    AND x.phone = '0' || substring(u.phone from 3)
              )
            """
        )
    )
    op.execute(
        sa.text(
            r"""
            UPDATE users u SET phone = '0' || substring(u.phone from 4)
            WHERE u.phone ~ '^\+84[35789][0-9]{8}$'
              AND NOT EXISTS (
                  SELECT 1 FROM users x
                  WHERE x.id <> u.id
                    AND x.phone = '0' || substring(u.phone from 4)
              )
            """
        )
    )
    # Ô rỗng phải là chuỗi rỗng, không phải NULL — hai thứ này cùng nghĩa
    # "không có số" nhưng chỉ một cái lọt qua được `WHERE phone <> ''`.
    op.execute(sa.text("UPDATE users SET phone = '' WHERE phone IS NULL"))
    op.execute(sa.text("UPDATE users SET email = '' WHERE email IS NULL"))

    # ── 2. Email: unique thường → unique MỘT PHẦN (cho phép rỗng) ───────────
    if _co_index("users", _IDX_EMAIL_CU):
        op.drop_index(_IDX_EMAIL_CU, table_name="users")
    # Vẫn cần index thường để tra cứu lúc đăng nhập.
    if not _co_index("users", _IDX_EMAIL_CU):
        op.create_index(_IDX_EMAIL_CU, "users", ["email"])
    if not _co_index("users", _IDX_EMAIL):
        op.execute(
            sa.text(
                f"CREATE UNIQUE INDEX {_IDX_EMAIL} ON users (email) "
                f"WHERE email <> ''"
            )
        )

    # ── 3. SĐT thành khoá định danh ─────────────────────────────────────────
    if not _co_index("users", "ix_users_phone"):
        op.create_index("ix_users_phone", "users", ["phone"])
    if not _co_index("users", _IDX_PHONE):
        op.execute(
            sa.text(
                f"CREATE UNIQUE INDEX {_IDX_PHONE} ON users (phone) "
                f"WHERE phone <> ''"
            )
        )


def downgrade() -> None:
    if not _co_bang("users") or not _la_postgres():
        return

    for ten in (_IDX_PHONE, "ix_users_phone", _IDX_EMAIL):
        if _co_index("users", ten):
            op.drop_index(ten, table_name="users")

    # Dựng lại UNIQUE thường trên email CHỈ KHI không còn ô rỗng nào — có ô
    # rỗng mà dựng lại là lệnh nổ giữa chừng, để DB dở dang.
    con_rong = op.get_bind().execute(
        sa.text("SELECT count(*) FROM users WHERE email = ''")
    ).scalar()
    if _co_index("users", _IDX_EMAIL_CU):
        op.drop_index(_IDX_EMAIL_CU, table_name="users")
    if not con_rong:
        op.create_index(_IDX_EMAIL_CU, "users", ["email"], unique=True)
    else:
        op.create_index(_IDX_EMAIL_CU, "users", ["email"])
