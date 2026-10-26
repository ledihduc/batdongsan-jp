"""service_marketplace_v2

Marketplace Dịch vụ P1/P2 (hybrid self-serve + operator):
- contractors +: slug (unique), cover_images, website, year_established, team_size,
  plan (free/pro), is_promoted → hồ sơ đơn vị công khai + quảng bá.
- construction_leads +: province_code/district_code (matching), visibility,
  target_contractor_id (liên hệ thẳng 1 đơn vị), expires_at, max_quotes (chống spam).
- MỚI contractor_reviews (đánh giá đơn vị, tách khỏi reviews của nhà).
- MỚI lead_contractors (routing lead → đơn vị: đã xem/đã báo giá; feed + giới hạn N).

Additive, cross-DB.

Revision ID: 0045_service_marketplace_v2
Revises: 0044_construction_marketplace
Create Date: 2026-07-05
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0045_service_marketplace_v2"
down_revision: Union[str, Sequence[str], None] = "0044_construction_marketplace"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── contractors: hồ sơ công khai + quảng bá ───────────────────────────────
    op.add_column("contractors", sa.Column("slug", sa.String(60), nullable=True))
    op.add_column("contractors", sa.Column("cover_images", sa.Text(), nullable=True))
    op.add_column("contractors", sa.Column("website", sa.String(300), nullable=True))
    op.add_column("contractors", sa.Column("year_established", sa.Integer(), nullable=True))
    op.add_column("contractors", sa.Column("team_size", sa.String(50), nullable=True))
    op.add_column("contractors", sa.Column("plan", sa.String(20), nullable=False, server_default="free"))
    op.add_column("contractors", sa.Column("is_promoted", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.create_index("ix_contractors_slug", "contractors", ["slug"], unique=True)

    # ── construction_leads: matching + liên hệ thẳng + chống spam ──────────────
    op.add_column("construction_leads", sa.Column("province_code", sa.String(32), nullable=True))
    op.add_column("construction_leads", sa.Column("district_code", sa.String(64), nullable=True))
    op.add_column("construction_leads", sa.Column("visibility", sa.String(20), nullable=False, server_default="public"))
    op.add_column("construction_leads", sa.Column("target_contractor_id", sa.Integer(), nullable=True))
    op.add_column("construction_leads", sa.Column("expires_at", sa.DateTime(), nullable=True))
    op.add_column("construction_leads", sa.Column("max_quotes", sa.Integer(), nullable=False, server_default="5"))
    op.create_index("ix_leads_province", "construction_leads", ["province_code"])

    # ── contractor_reviews (đánh giá đơn vị) ───────────────────────────────────
    op.create_table(
        "contractor_reviews",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("contractor_id", sa.Integer(), nullable=False, index=True),
        sa.Column("user_id", sa.Integer(), nullable=False, index=True),
        sa.Column("lead_id", sa.Integer(), nullable=True),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )

    # ── lead_contractors (routing + feed) ──────────────────────────────────────
    op.create_table(
        "lead_contractors",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("lead_id", sa.Integer(), nullable=False, index=True),
        sa.Column("contractor_id", sa.Integer(), nullable=False, index=True),
        sa.Column("viewed_at", sa.DateTime(), nullable=True),
        sa.Column("quoted_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index(
        "ix_lead_contractor_unique", "lead_contractors",
        ["lead_id", "contractor_id"], unique=True,
    )


def downgrade() -> None:
    op.drop_table("lead_contractors")
    op.drop_table("contractor_reviews")
    op.drop_index("ix_leads_province", table_name="construction_leads")
    for c in ("max_quotes", "expires_at", "target_contractor_id", "visibility",
              "district_code", "province_code"):
        op.drop_column("construction_leads", c)
    op.drop_index("ix_contractors_slug", table_name="contractors")
    for c in ("is_promoted", "plan", "team_size", "year_established", "website",
              "cover_images", "slug"):
        op.drop_column("contractors", c)
