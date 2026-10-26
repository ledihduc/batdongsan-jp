"""Profile uy tín Đợt 2: file thiết kế + dự án CÓ KIỂM CHỨNG

Revision ID: 0059_project_verify
Revises: 0058_reputation

contractor_projects thêm:
- design_files (JSON): danh sách URL file thiết kế (PDF) — trưng bày cho khách.
- verified (bool): admin đã xác nhận dự án CÓ THẬT (nguồn gốc/khách xác nhận).
  Chỉ dự án verified mới CỘNG vào tín hiệu uy tín; dự án tự đăng vẫn hiển thị
  nhưng gắn nhãn "tự đăng". Đây là chốt chống bơm-số-lượng (Sybil/FTC).
- verified_at.

Nguyên tắc: TRƯNG BÀY thưởng số lượng (khách xem hết), ĐIỂM thưởng bằng chứng
(chỉ dự án verified). Additive/nullable.
"""

from alembic import op
import sqlalchemy as sa

revision = "0059_project_verify"
down_revision = "0058_reputation"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "contractor_projects" not in tables:
        return
    cols = _cols("contractor_projects")
    if "design_files" not in cols:
        op.add_column("contractor_projects",
                      sa.Column("design_files", sa.JSON(), nullable=True))
    if "verified" not in cols:
        op.add_column(
            "contractor_projects",
            sa.Column("verified", sa.Boolean(), nullable=False,
                      server_default=sa.false()),
        )
    if "verified_at" not in cols:
        op.add_column("contractor_projects",
                      sa.Column("verified_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "contractor_projects" not in tables:
        return
    cols = _cols("contractor_projects")
    for c in ("verified_at", "verified", "design_files"):
        if c in cols:
            op.drop_column("contractor_projects", c)
