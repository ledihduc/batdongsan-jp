"""house_search_fields

Them cot cho tim kiem BDS nang cao:
  - direction   : huong nha (phong thuy) — slug 8 huong, null = chua khai.
  - rating_avg  : cache diem danh gia trung binh (tu bang reviews).
  - rating_count: so luong review.
Backfill rating_avg/count tu reviews hien co. Additive + nullable/default,
idempotent (inspect truoc khi them).

Revision ID: 0071_house_search_fields
Revises: 0070_user_push_tokens
Create Date: 2026-08-21
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0071_house_search_fields"
down_revision: Union[str, Sequence[str], None] = "0070_user_push_tokens"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_col(insp, table, col) -> bool:
    return col in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not _has_col(insp, "houses", "direction"):
        op.add_column("houses", sa.Column("direction", sa.String(length=12), nullable=True))
        op.create_index("ix_houses_direction", "houses", ["direction"])
    if not _has_col(insp, "houses", "rating_avg"):
        op.add_column(
            "houses",
            sa.Column("rating_avg", sa.Float(), nullable=False, server_default="0"),
        )
        op.create_index("ix_houses_rating_avg", "houses", ["rating_avg"])
    if not _has_col(insp, "houses", "rating_count"):
        op.add_column(
            "houses",
            sa.Column("rating_count", sa.Integer(), nullable=False, server_default="0"),
        )

    # ── Backfill rating_avg/count tu reviews (an toan neu bang reviews rong) ──
    if "reviews" in insp.get_table_names():
        op.execute(
            """
            UPDATE houses h SET
              rating_count = COALESCE(r.cnt, 0),
              rating_avg   = COALESCE(r.avg, 0)
            FROM (
              SELECT house_id, COUNT(*) AS cnt, AVG(rating)::float AS avg
              FROM reviews GROUP BY house_id
            ) r
            WHERE r.house_id = h.id
            """
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if _has_col(insp, "houses", "rating_count"):
        op.drop_column("houses", "rating_count")
    if _has_col(insp, "houses", "rating_avg"):
        op.drop_index("ix_houses_rating_avg", table_name="houses")
        op.drop_column("houses", "rating_avg")
    if _has_col(insp, "houses", "direction"):
        op.drop_index("ix_houses_direction", table_name="houses")
        op.drop_column("houses", "direction")
