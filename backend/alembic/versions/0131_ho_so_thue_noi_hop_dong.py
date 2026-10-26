"""Hồ sơ thuê nối thẳng tới hợp đồng vừa ký khi chốt.

Chốt thuê sinh ra một `contracts` nhưng không lưu id về `rental_journeys`, nên
từ hồ sơ không mở được hợp đồng, và không biết hợp đồng đã kích hoạt chưa.

Additive: cột mới nullable, hồ sơ cũ giữ nguyên.

Revision ID: 0131_ho_so_thue_noi_hop_dong
Revises: 0130_tin_ngan_han_theo_hang
"""

import sqlalchemy as sa
from alembic import op

revision = "0131_ho_so_thue_noi_hop_dong"
down_revision = "0130_tin_ngan_han_theo_hang"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    cols = {c["name"] for c in sa.inspect(bind).get_columns("rental_journeys")}
    if "contract_id" in cols:
        return
    op.add_column(
        "rental_journeys", sa.Column("contract_id", sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        "fk_rental_journeys_contract_id",
        "rental_journeys",
        "contracts",
        ["contract_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    bind = op.get_bind()
    cols = {c["name"] for c in sa.inspect(bind).get_columns("rental_journeys")}
    if "contract_id" not in cols:
        return
    op.drop_constraint(
        "fk_rental_journeys_contract_id", "rental_journeys", type_="foreignkey"
    )
    op.drop_column("rental_journeys", "contract_id")
