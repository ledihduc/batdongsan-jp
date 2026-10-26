"""Đơn vị/sàn mà người bán đang hợp tác.

Thẻ danh tính trên trang sale có dòng "Hợp tác: <sàn>" — thứ khách nhìn để biết
người này đứng sau ai. Đây là thông tin NGƯỜI BÁN TỰ KHAI, không phải hệ thống
suy ra, nên chỉ là một ô chữ; không sinh badge, không xếp hạng theo nó.

Revision ID: 0089_agency
Revises: 0088_lien_he_cong_khai
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0089_agency"
down_revision = "0088_lien_he_cong_khai"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "host_profiles", sa.Column("agency", sa.String(200), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("host_profiles", "agency")
