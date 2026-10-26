"""industrial_re_promote

Marketplace P3:
- houses + industrial_attrs (JSON): BĐS công nghiệp dùng chung bảng houses với
  product_type='industrial'; thuộc tính KCN (diện tích ha, tải điện, PCCC, pháp
  lý KCN) gom vào 1 cột JSON — tái dùng search/detail/booking sẵn có.
- Gói pro/promote đã có sẵn cột (contractors.plan/is_promoted từ 0045); P3 chỉ
  dùng để xếp hạng directory — KHÔNG cần đổi schema ở đây.

Additive, cross-DB (Postgres prod / SQLite dev). Reversible.

Revision ID: 0046_industrial_re_promote
Revises: 0045_service_marketplace_v2
Create Date: 2026-07-11
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0046_industrial_re_promote"
down_revision: Union[str, Sequence[str], None] = "0045_service_marketplace_v2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "houses",
        sa.Column("industrial_attrs", sa.JSON(), nullable=True),
    )
    # Index bộ lọc loại tin CN: product_type có sẵn (0008-ish) nhưng thêm index
    # riêng cho truy vấn "duyệt tin công nghiệp" nếu chưa có. Bọc try để idempotent
    # trên DB đã có index.
    try:
        op.create_index(
            "ix_houses_product_type_status",
            "houses",
            ["product_type", "status"],
        )
    except Exception:  # noqa: BLE001 — index có thể đã tồn tại
        pass


def downgrade() -> None:
    try:
        op.drop_index("ix_houses_product_type_status", table_name="houses")
    except Exception:  # noqa: BLE001
        pass
    op.drop_column("houses", "industrial_attrs")
