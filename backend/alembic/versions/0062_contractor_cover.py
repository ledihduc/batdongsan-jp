"""Đơn vị tự chọn ẢNH BÌA (cover) — bộ mặt thương hiệu, thay vì auto-pick

Revision ID: 0062_contractor_cover
Revises: 0061_construction_geo

Trước đây ảnh bìa hồ sơ đơn vị bị auto lấy "ảnh dự án đầu tiên" → đơn vị không
kiểm soát được bộ mặt của mình. Thêm `cover_path` (nullable) để đơn vị tự chọn;
FE fallback về ảnh portfolio đầu khi cover_path null (đơn vị cũ không mất bìa).

Additive + nullable → an toàn.
"""

from alembic import op
import sqlalchemy as sa

revision = "0062_contractor_cover"
down_revision = "0061_construction_geo"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "contractors" in tables and "cover_path" not in _cols("contractors"):
        op.add_column(
            "contractors",
            sa.Column("cover_path", sa.String(length=500), nullable=True),
        )


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "contractors" in tables and "cover_path" in _cols("contractors"):
        op.drop_column("contractors", "cover_path")
