"""contact_leads

Lead 'gọi lại' nhẹ (redesign v2): khách để lại Tên+SĐT tại khoảnh khắc giá trị,
KHÔNG cần login. Tách khỏi construction_leads (RFQ báo giá). Additive, cross-DB.

Revision ID: 0067_contact_leads
Revises: 0066_password_changed_at
Create Date: 2026-07-30
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0067_contact_leads"
down_revision: Union[str, Sequence[str], None] = "0066_password_changed_at"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "contact_leads",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("phone", sa.String(50), nullable=False),
        sa.Column("source", sa.String(50), nullable=False),
        sa.Column("context", sa.Text(), nullable=True),
        sa.Column("world", sa.String(20), nullable=True),
        sa.Column("province_code", sa.String(32), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="new"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_contact_leads_user", "contact_leads", ["user_id"])
    op.create_index("ix_contact_leads_phone", "contact_leads", ["phone"])
    op.create_index("ix_contact_leads_source", "contact_leads", ["source"])
    op.create_index("ix_contact_leads_status", "contact_leads", ["status"])
    op.create_index("ix_contact_leads_created", "contact_leads", ["created_at"])
    op.create_index("ix_contact_leads_province", "contact_leads", ["province_code"])


def downgrade() -> None:
    for ix in (
        "ix_contact_leads_province", "ix_contact_leads_created",
        "ix_contact_leads_status", "ix_contact_leads_source",
        "ix_contact_leads_phone", "ix_contact_leads_user",
    ):
        op.drop_index(ix, table_name="contact_leads")
    op.drop_table("contact_leads")
