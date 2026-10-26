"""construction_marketplace

Marketplace Thi công (thiết kế/xây dựng/nội thất): services (seed 3), contractors
(hồ sơ năng lực), contractor_projects (portfolio), construction_leads (RFQ),
quotes (báo giá). Tất cả bảng MỚI (additive).

Revision ID: 0044_construction_marketplace
Revises: 0043_verification_request
Create Date: 2026-07-11
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0044_construction_marketplace"
down_revision: Union[str, Sequence[str], None] = "0043_verification_request"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "construction_services",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("slug", sa.String(40), nullable=False, unique=True, index=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("icon", sa.String(50), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )

    op.create_table(
        "contractors",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=True, index=True),
        sa.Column("company_name", sa.String(200), nullable=False),
        sa.Column("service_slugs", sa.Text(), nullable=True),  # JSONList
        sa.Column("province_code", sa.String(32), nullable=True, index=True),
        sa.Column("district_code", sa.String(64), nullable=True, index=True),
        sa.Column("areas", sa.Text(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("phone", sa.String(50), nullable=True),
        sa.Column("logo_path", sa.String(500), nullable=True),
        sa.Column("verified", sa.Boolean(), nullable=False, server_default=sa.false(), index=True),
        sa.Column("verified_at", sa.DateTime(), nullable=True),
        sa.Column("rating_avg", sa.Float(), nullable=False, server_default="0"),
        sa.Column("rating_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending", index=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )

    op.create_table(
        "contractor_projects",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("contractor_id", sa.Integer(), nullable=False, index=True),
        sa.Column("title", sa.String(300), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("images", sa.Text(), nullable=True),  # JSONList
        sa.Column("service_slug", sa.String(40), nullable=True, index=True),
        sa.Column("year", sa.Integer(), nullable=True),
        sa.Column("location", sa.String(200), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )

    op.create_table(
        "construction_leads",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=True, index=True),
        sa.Column("service_slug", sa.String(40), nullable=False, index=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("phone", sa.String(50), nullable=False, index=True),
        sa.Column("area", sa.String(200), nullable=True),
        sa.Column("budget", sa.String(100), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("images", sa.Text(), nullable=True),  # JSONList
        sa.Column("status", sa.String(20), nullable=False, server_default="new", index=True),
        sa.Column("assigned_operator_id", sa.Integer(), nullable=True, index=True),
        sa.Column("contractor_id", sa.Integer(), nullable=True, index=True),
        sa.Column("source", sa.String(30), nullable=False, server_default="app"),
        sa.Column("created_at", sa.DateTime(), nullable=True, index=True),
    )

    op.create_table(
        "quotes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("lead_id", sa.Integer(), nullable=False, index=True),
        sa.Column("contractor_id", sa.Integer(), nullable=False, index=True),
        sa.Column("amount", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(3), nullable=False, server_default="VND"),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("valid_until", sa.DateTime(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="sent", index=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("responded_at", sa.DateTime(), nullable=True),
    )

    # Seed 3 dịch vụ thi công.
    svc = sa.table(
        "construction_services",
        sa.column("slug", sa.String),
        sa.column("name", sa.String),
        sa.column("description", sa.Text),
        sa.column("icon", sa.String),
        sa.column("sort_order", sa.Integer),
    )
    op.bulk_insert(
        svc,
        [
            {"slug": "design", "name": "Thiết kế",
             "description": "Thiết kế kiến trúc & nội thất", "icon": "architecture", "sort_order": 1},
            {"slug": "build", "name": "Xây dựng",
             "description": "Xây mới, sửa chữa, cải tạo", "icon": "construction", "sort_order": 2},
            {"slug": "interior", "name": "Nội thất",
             "description": "Thi công & mua sắm nội thất", "icon": "chair", "sort_order": 3},
        ],
    )


def downgrade() -> None:
    op.drop_table("quotes")
    op.drop_table("construction_leads")
    op.drop_table("contractor_projects")
    op.drop_table("contractors")
    op.drop_table("construction_services")
