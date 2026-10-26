"""Profile uy tín Đợt 1: response time + review đa tiêu chí

Revision ID: 0058_reputation
Revises: 0057_milestones_cert

- viewing_appointments.responded_at: mốc host phản hồi lần đầu (pending→khác) →
  tính avg_response_hours cho host (cột này đang CHẾT: có schema, không nguồn ghi).
- reviews: 6 tiêu chí con kiểu Airbnb (khách chấm nhà/chủ nhà) — nullable.
- contractor_reviews: 5 tiêu chí con kiểu Angi (khách chấm đơn vị) — nullable.

Điểm TỔNG (reviews.rating / contractor_reviews.rating) giữ nguyên, do người chấm
cho TRỰC TIẾP — KHÔNG phải trung bình các mục con (mẫu Airbnb/Booking 2024). Các
cột con chỉ để hiển thị chi tiết, không đổi cách tính điểm tổng.

Tất cả additive/nullable. Không đổi cột cũ.
"""

from alembic import op
import sqlalchemy as sa

revision = "0058_reputation"
down_revision = "0057_milestones_cert"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def _add(table: str, *columns: sa.Column) -> None:
    existing = _cols(table)
    for col in columns:
        if col.name not in existing:
            op.add_column(table, col)


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())

    if "viewing_appointments" in tables:
        _add("viewing_appointments",
             sa.Column("responded_at", sa.DateTime(), nullable=True))

    if "reviews" in tables:
        _add(
            "reviews",
            sa.Column("cleanliness", sa.Integer(), nullable=True),
            sa.Column("accuracy", sa.Integer(), nullable=True),
            sa.Column("checkin", sa.Integer(), nullable=True),
            sa.Column("communication", sa.Integer(), nullable=True),
            sa.Column("location", sa.Integer(), nullable=True),
            sa.Column("value", sa.Integer(), nullable=True),
        )

    if "contractor_reviews" in tables:
        _add(
            "contractor_reviews",
            sa.Column("quality", sa.Integer(), nullable=True),
            sa.Column("timeliness", sa.Integer(), nullable=True),
            sa.Column("communication", sa.Integer(), nullable=True),
            sa.Column("budget", sa.Integer(), nullable=True),
            sa.Column("professionalism", sa.Integer(), nullable=True),
        )


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())

    def drop(table: str, *names: str) -> None:
        if table not in tables:
            return
        cols = _cols(table)
        for n in names:
            if n in cols:
                op.drop_column(table, n)

    drop("contractor_reviews", "quality", "timeliness", "communication",
         "budget", "professionalism")
    drop("reviews", "cleanliness", "accuracy", "checkin", "communication",
         "location", "value")
    drop("viewing_appointments", "responded_at")
