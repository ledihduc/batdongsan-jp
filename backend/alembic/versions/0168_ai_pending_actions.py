"""Create ai_pending_actions — hành động ghi AI chờ xác nhận (plan 20261027-1102 Phase 09, P6).

Token chỉ lưu SHA-256; 1 lần dùng (UPDATE có điều kiện); `result` để gỡ dữ liệu AI đã ghi.
Additive, idempotent (has_table), có downgrade(). JSONB trên Postgres, JSON nơi khác (mẫu 0146).

Revision ID: 0168_ai_pending_actions
Revises: 0167_jp_listing_link_columns
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0168_ai_pending_actions"
down_revision = "0167_jp_listing_link_columns"
branch_labels = None
depends_on = None

_TABLE = "ai_pending_actions"


def upgrade() -> None:
    bind = op.get_bind()
    if sa.inspect(bind).has_table(_TABLE):
        return
    json_type = postgresql.JSONB() if bind.dialect.name == "postgresql" else sa.JSON()
    op.create_table(
        _TABLE,
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("token_sha256", sa.String(64), nullable=False, comment="SHA-256 hex của token; token gốc không lưu"),
        sa.Column("action", sa.String(64), nullable=False),
        sa.Column("params", json_type, nullable=False),
        sa.Column("channel", sa.String(10), nullable=False, comment="mcp | chat"),
        sa.Column("owner_user_id", sa.Integer(), nullable=True, comment="Người tạo trong chat; NULL khi MCP"),
        sa.Column("status", sa.String(12), nullable=False, server_default="pending",
                  comment="pending | executed | failed | undone"),
        sa.Column("error_code", sa.String(40), nullable=True),
        sa.Column("result", json_type, nullable=True, comment="Id dòng đã ghi — dùng để gỡ"),
        sa.Column("executed_by_user_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("executed_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_ai_pending_actions_token_sha256", _TABLE, ["token_sha256"], unique=True)
    op.create_index("ix_ai_pending_actions_owner_user_id", _TABLE, ["owner_user_id"])
    op.create_index("ix_ai_pending_actions_executed_by_user_id", _TABLE, ["executed_by_user_id"])
    op.create_index("ix_ai_pending_actions_expires_at", _TABLE, ["expires_at"])


def downgrade() -> None:
    bind = op.get_bind()
    if not sa.inspect(bind).has_table(_TABLE):
        return
    for name in ("ix_ai_pending_actions_expires_at", "ix_ai_pending_actions_executed_by_user_id",
                 "ix_ai_pending_actions_owner_user_id", "ix_ai_pending_actions_token_sha256"):
        op.drop_index(name, table_name=_TABLE)
    op.drop_table(_TABLE)
