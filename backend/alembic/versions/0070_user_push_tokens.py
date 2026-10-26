"""user_push_tokens

Store per-device FCM registration tokens for authenticated users.

Revision ID: 0070_user_push_tokens
Revises: 0069_user_blocks
Create Date: 2026-08-10
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0070_user_push_tokens"
down_revision: Union[str, Sequence[str], None] = "0069_user_blocks"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_push_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.String(length=120), nullable=False),
        sa.Column("token", sa.String(length=500), nullable=False),
        sa.Column("platform", sa.String(length=20), nullable=False, server_default="unknown"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("last_seen_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "device_id", name="uq_user_push_token_device"),
    )
    op.create_index("ix_user_push_tokens_user_id", "user_push_tokens", ["user_id"])
    op.create_index("ix_user_push_tokens_token", "user_push_tokens", ["token"])


def downgrade() -> None:
    op.drop_index("ix_user_push_tokens_token", table_name="user_push_tokens")
    op.drop_index("ix_user_push_tokens_user_id", table_name="user_push_tokens")
    op.drop_table("user_push_tokens")
