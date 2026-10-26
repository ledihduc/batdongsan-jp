"""contractor_scale

Them cot 'scale' (LOAI HINH doanh nghiep) cho contractors — phuc vu loc tim kiem
theo quy mo. Khac team_size (dau nguoi). Backfill tu team_size bang heuristic.
Additive + nullable, idempotent.

Revision ID: 0072_contractor_scale
Revises: 0071_house_search_fields
Create Date: 2026-08-21
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0072_contractor_scale"
down_revision: Union[str, Sequence[str], None] = "0071_house_search_fields"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_col(insp, table, col) -> bool:
    return col in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not _has_col(insp, "contractors", "scale"):
        op.add_column("contractors", sa.Column("scale", sa.String(length=20), nullable=True))
        op.create_index("ix_contractors_scale", "contractors", ["scale"])

    # Index cho year_established (filter kinh nghiem) — them neu chua co.
    existing_idx = {i["name"] for i in insp.get_indexes("contractors")}
    if "ix_contractors_year_established" not in existing_idx:
        op.create_index(
            "ix_contractors_year_established", "contractors", ["year_established"]
        )

    # ── Backfill scale tu team_size (dau nguoi) — chi voi cac ban ghi chua co scale ──
    # Heuristic: '100+'->corporation, '51-100'->medium, '21-50'->small,
    #            '6-20'->crew, '1-5'->individual. Con lai giu null (admin sua tay).
    op.execute(
        """
        UPDATE contractors SET scale = CASE team_size
            WHEN '100+'   THEN 'corporation'
            WHEN '51-100' THEN 'medium'
            WHEN '21-50'  THEN 'small'
            WHEN '6-20'   THEN 'crew'
            WHEN '1-5'    THEN 'individual'
            ELSE scale
        END
        WHERE scale IS NULL AND team_size IS NOT NULL
        """
    )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    existing_idx = {i["name"] for i in insp.get_indexes("contractors")}
    if "ix_contractors_year_established" in existing_idx:
        op.drop_index("ix_contractors_year_established", table_name="contractors")
    if _has_col(insp, "contractors", "scale"):
        op.drop_index("ix_contractors_scale", table_name="contractors")
        op.drop_column("contractors", "scale")
