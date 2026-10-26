"""user_blocks

Chặn người dùng (Apple Guideline 1.2 cho UGC): viewer chặn thì không còn thấy
bài/reel/bình luận của người bị chặn. Additive, cross-DB.

Revision ID: 0069_user_blocks
Revises: 0068_planning_hidden_provinces
Create Date: 2026-08-03
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0069_user_blocks"
down_revision: Union[str, Sequence[str], None] = "0068_planning_hidden_provinces"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_blocks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("blocker_id", sa.Integer(), nullable=False),
        sa.Column("blocked_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("blocker_id", "blocked_id", name="uq_user_block_pair"),
    )
    op.create_index("ix_user_blocks_blocker_id", "user_blocks", ["blocker_id"])
    op.create_index("ix_user_blocks_blocked_id", "user_blocks", ["blocked_id"])
    op.create_index("ix_user_blocks_created_at", "user_blocks", ["created_at"])


def downgrade() -> None:
    for ix in (
        "ix_user_blocks_created_at",
        "ix_user_blocks_blocked_id",
        "ix_user_blocks_blocker_id",
    ):
        op.drop_index(ix, table_name="user_blocks")
    op.drop_table("user_blocks")
