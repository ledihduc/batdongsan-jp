"""houses_legal_status

Thêm cột legal_status (String, nullable) — pháp lý cho tin MUA BÁN
(red_book=sổ đỏ | pink_book=sổ hồng | sale_contract=HĐMB | pending=chờ sổ).
Null cho tin cho thuê / tin cũ. Cross-dialect, additive, an toàn.

Revision ID: 0040_houses_legal_status
Revises: 0039_listing_v2
Create Date: 2026-07-04
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0040_houses_legal_status"
down_revision: Union[str, Sequence[str], None] = "0039_listing_v2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("houses", sa.Column("legal_status", sa.String(length=20), nullable=True))


def downgrade() -> None:
    op.drop_column("houses", "legal_status")
