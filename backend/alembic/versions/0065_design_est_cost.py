"""Giá tham khảo (est_cost) cho ContractorProject — thông số "mẫu nhà"

Revision ID: 0065_design_est_cost
Revises: 0064_design_attributes

Trang chi tiết mẫu nhà có "Giá tham khảo" trong bảng thông số. Thêm cột nullable
est_cost (VND) để đơn vị tự khai; ẩn khi null (dự án cũ không bị ảnh hưởng).

Additive + nullable → an toàn.
"""

from alembic import op
import sqlalchemy as sa

revision = "0065_design_est_cost"
down_revision = "0064_design_attributes"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "contractor_projects" in tables and "est_cost" not in _cols("contractor_projects"):
        op.add_column(
            "contractor_projects",
            sa.Column("est_cost", sa.BigInteger, nullable=True),
        )


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "contractor_projects" in tables and "est_cost" in _cols("contractor_projects"):
        op.drop_column("contractor_projects", "est_cost")
