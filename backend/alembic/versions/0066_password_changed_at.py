"""Mốc đổi mật khẩu — để đổi mật khẩu vô hiệu hoá token cũ

Revision ID: 0066_password_changed_at
Revises: 0065_design_est_cost

Hệ thống không có danh sách thu hồi token. Trước đây người dùng nghi bị lộ tài
khoản và đổi mật khẩu thì mọi token cũ VẪN SỐNG tới hết hạn (TTL 7 ngày) — tức
đổi mật khẩu không đuổi được kẻ đang chiếm phiên. So `iat` của token với mốc
này là cách rẻ nhất để đóng ca đó.

NULL = chưa từng đổi mật khẩu → mọi token hiện có vẫn hợp lệ, không ai bị đăng
xuất khi triển khai.

Additive + nullable + idempotent.
"""

from alembic import op
import sqlalchemy as sa

revision = "0066_password_changed_at"
down_revision = "0065_design_est_cost"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "users" in tables and "password_changed_at" not in _cols("users"):
        op.add_column(
            "users",
            sa.Column("password_changed_at", sa.DateTime(), nullable=True),
        )


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "users" in tables and "password_changed_at" in _cols("users"):
        op.drop_column("users", "password_changed_at")
