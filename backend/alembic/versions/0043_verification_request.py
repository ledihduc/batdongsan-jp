"""verification_request

Luồng thẩm định chất lượng nhà trọ: chủ yêu cầu → admin/thẩm-định-viên đi kiểm
tra thực tế → gắn verified_star vào houses (đã có cột từ 0042). Phí xác minh để
DEFERRED (chờ Payment core + quyết định kinh doanh).

Bảng mới verification_request (additive).

Revision ID: 0043_verification_request
Revises: 0042_house_quality_rating
Create Date: 2026-07-05
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0043_verification_request"
down_revision: Union[str, Sequence[str], None] = "0042_house_quality_rating"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "verification_requests",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("house_id", sa.Integer(), nullable=False, index=True),
        sa.Column("host_id", sa.Integer(), nullable=False, index=True),
        # requested | inspecting | done | rejected
        sa.Column("status", sa.String(20), nullable=False, server_default="requested"),
        sa.Column("fee_amount", sa.Integer(), nullable=False, server_default="0"),
        # deferred (chờ Payment) | manual_confirmed | paid
        sa.Column("payment_status", sa.String(20), nullable=False, server_default="deferred"),
        sa.Column("verified_star", sa.Integer(), nullable=True),
        sa.Column("criteria_json", sa.JSON(), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("assignee_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("verification_requests")
