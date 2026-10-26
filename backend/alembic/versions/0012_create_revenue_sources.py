"""create_revenue_sources

Phase 04 analytics — tạo bảng revenue_sources và seed 3 nguồn mặc định cho
mỗi host đang có reservation hoặc contract (UNION).

Tên mặc định:
  - 'Trực tiếp'         #4CAF50  (direct)
  - 'Marketplace nội bộ' #2196F3 (marketplace)
  - 'Khác'              #9E9E9E  (other / fallback)

Revision ID: 0012_create_revenue_sources
Revises: 0011_excl_reservation_overlap
Create Date: 2026-06-28
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0012_create_revenue_sources"
down_revision: Union[str, Sequence[str], None] = "0011_excl_reservation_overlap"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "revenue_sources",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=50), nullable=False),
        sa.Column(
            "color_hex",
            sa.String(length=7),
            nullable=False,
            server_default="#666666",
        ),
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["host_id"],
            ["users.id"],
            name="fk_revenue_sources_host_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("host_id", "name", name="uq_revenue_sources_host_name"),
    )
    op.create_index("ix_revenue_sources_host_id", "revenue_sources", ["host_id"])

    # Seed 3 nguồn mặc định cho mỗi host đang có reservation HOẶC contract.
    # Dùng datetime.utcnow() từ Python-side để tương thích cả SQLite lẫn Postgres
    # (tránh NOW() raw SQL không được SQLite hỗ trợ trong column default context).
    connection = op.get_bind()
    now = datetime.now(timezone.utc).replace(tzinfo=None)  # naive UTC → DateTime col
    connection.execute(
        sa.text(
            """
            INSERT INTO revenue_sources (host_id, name, color_hex, is_archived,
                                         created_at, updated_at)
            SELECT h.host_id, s.name, s.color_hex, FALSE, :now, :now
            FROM (
                SELECT DISTINCT host_id FROM reservations
                UNION
                SELECT DISTINCT host_id FROM contracts
            ) AS h
            CROSS JOIN (
                SELECT 'Trực tiếp'          AS name, '#4CAF50' AS color_hex
                UNION ALL
                SELECT 'Marketplace nội bộ', '#2196F3'
                UNION ALL
                SELECT 'Khác',               '#9E9E9E'
            ) AS s
            WHERE NOT EXISTS (
                SELECT 1 FROM revenue_sources rs
                WHERE rs.host_id = h.host_id AND rs.name = s.name
            )
            """
        ),
        {"now": now},
    )


def downgrade() -> None:
    op.drop_index("ix_revenue_sources_host_id", table_name="revenue_sources")
    op.drop_table("revenue_sources")
