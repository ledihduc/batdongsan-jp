"""house_quality_rating

Sao chất lượng theo tiêu chí (PCCC, đủ đồ, bếp, WC khép kín, điều hoà) cho mảng
NHÀ TRỌ CHO THUÊ. Thêm cột vào houses (additive, nullable → backward-compatible):
- quality_criteria (JSON): checklist tiêu chí chủ khai.
- quality_self_star (int): sao tự khai suy từ criteria.
- quality_verified_star (int): sao sau thẩm định thực tế (Phase 2).
- quality_verified_at (datetime).

Revision ID: 0042_house_quality_rating
Revises: 0041_booking_availability
Create Date: 2026-07-05
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0042_house_quality_rating"
down_revision: Union[str, Sequence[str], None] = "0041_booking_availability"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("houses", sa.Column("quality_criteria", sa.JSON(), nullable=True))
    op.add_column("houses", sa.Column("quality_self_star", sa.Integer(), nullable=True))
    op.add_column(
        "houses", sa.Column("quality_verified_star", sa.Integer(), nullable=True)
    )
    op.add_column(
        "houses", sa.Column("quality_verified_at", sa.DateTime(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("houses", "quality_verified_at")
    op.drop_column("houses", "quality_verified_star")
    op.drop_column("houses", "quality_self_star")
    op.drop_column("houses", "quality_criteria")
