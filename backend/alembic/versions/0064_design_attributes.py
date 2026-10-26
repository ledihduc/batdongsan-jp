"""Thuộc tính "mẫu nhà" cho ContractorProject — lọc + hiển thị kiểu trang mẫu nhà

Revision ID: 0064_design_attributes
Revises: 0063_host_cover

Thư viện thiết kế cần bộ lọc giống trang mẫu nhà (loại nhà, phong cách, số tầng,
số phòng ngủ, diện tích, kích thước). Thêm các cột nullable vào contractor_projects
để đơn vị khai khi đăng thiết kế. Dự án cũ để null → vẫn hiện, chỉ không khớp khi
lọc theo thuộc tính đó.

Additive + nullable → an toàn.
"""

from alembic import op
import sqlalchemy as sa

revision = "0064_design_attributes"
down_revision = "0063_host_cover"
branch_labels = None
depends_on = None

_NEW = {
    "house_type": sa.String(length=30),   # nha_pho | nha_cap4 | biet_thu | can_ho_dv
    "style": sa.String(length=30),         # hien_dai | tan_co_dien | dia_trung_hai
    "floors": sa.Integer,                  # số tầng
    "bedrooms": sa.Integer,                # số phòng ngủ
    "area": sa.Float,                      # diện tích sàn (m²)
    "width_m": sa.Float,                   # chiều rộng / mặt tiền (m)
    "length_m": sa.Float,                  # chiều dài (m)
}


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "contractor_projects" not in tables:
        return
    have = _cols("contractor_projects")
    for name, coltype in _NEW.items():
        if name not in have:
            op.add_column(
                "contractor_projects",
                sa.Column(name, coltype if not callable(coltype) else coltype(),
                          nullable=True),
            )


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "contractor_projects" not in tables:
        return
    have = _cols("contractor_projects")
    for name in _NEW:
        if name in have:
            op.drop_column("contractor_projects", name)
