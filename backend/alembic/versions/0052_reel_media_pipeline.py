"""reel media pipeline (P1)

Pipeline chuẩn hoá video: upload (streaming) → job → worker ffmpeg
(ffprobe validate → transcode H.264/AAC ≤720x1280 faststart → trích thumbnail)
→ reel.processing_status='ready'.

Reel DEMO/cũ đang phát được giữ `processing_status='ready'` (server_default)
nên KHÔNG biến mất khỏi feed sau migration.

Revision ID: 0052_reel_media_pipeline
Revises: 0051_reel_moderation
Create Date: 2026-07-18
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0052_reel_media_pipeline"
down_revision: Union[str, Sequence[str], None] = "0051_reel_moderation"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "reels",
        sa.Column(
            "processing_status",
            sa.String(length=20),
            nullable=False,
            server_default="ready",
        ),
    )
    op.add_column(
        "reels", sa.Column("processing_error", sa.String(length=300), nullable=True)
    )
    op.add_column(
        "reels", sa.Column("original_path", sa.String(length=500), nullable=True)
    )
    op.add_column("reels", sa.Column("duration_ms", sa.Integer(), nullable=True))
    op.add_column("reels", sa.Column("width", sa.Integer(), nullable=True))
    op.add_column("reels", sa.Column("height", sa.Integer(), nullable=True))
    op.add_column("reels", sa.Column("size_bytes", sa.Integer(), nullable=True))
    op.create_index("ix_reels_processing_status", "reels", ["processing_status"])

    op.create_table(
        "media_jobs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("kind", sa.String(length=30), nullable=False,
                  server_default="reel_transcode"),
        sa.Column("reel_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False,
                  server_default="queued"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("started_at", sa.DateTime(), nullable=True),
        sa.Column("finished_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_media_jobs_reel_id", "media_jobs", ["reel_id"])
    op.create_index("ix_media_jobs_status", "media_jobs", ["status"])
    op.create_index("ix_media_jobs_created_at", "media_jobs", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_media_jobs_created_at", table_name="media_jobs")
    op.drop_index("ix_media_jobs_status", table_name="media_jobs")
    op.drop_index("ix_media_jobs_reel_id", table_name="media_jobs")
    op.drop_table("media_jobs")
    op.drop_index("ix_reels_processing_status", table_name="reels")
    op.drop_column("reels", "size_bytes")
    op.drop_column("reels", "height")
    op.drop_column("reels", "width")
    op.drop_column("reels", "duration_ms")
    op.drop_column("reels", "original_path")
    op.drop_column("reels", "processing_error")
    op.drop_column("reels", "processing_status")
