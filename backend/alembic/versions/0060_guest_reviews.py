"""Profile uy tín Đợt 3: chiều ngược chủ nhà → khách thuê

Revision ID: 0060_guest_reviews
Revises: 0059_project_verify

Mở uy tín cho role guest (đang TRỐNG hoàn toàn). Chủ nhà đánh giá khách thuê
sau giao dịch — bất đối xứng kiểu Airbnb: khách được chấm 3 tiêu chí (Sạch sẽ ·
Giao tiếp · Tuân thủ thoả thuận), so với 6 tiêu chí khách chấm chủ nhà.

Bảng mới, additive.
"""

from alembic import op
import sqlalchemy as sa

revision = "0060_guest_reviews"
down_revision = "0059_project_verify"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())

    # review_count lưu sẵn để badge "chủ nhà tin cậy" áp ngưỡng ≥5 review mà
    # không phải COUNT mỗi lần render (tránh N+1 ở list_houses).
    if "host_profiles" in tables and "review_count" not in _cols("host_profiles"):
        op.add_column(
            "host_profiles",
            sa.Column("review_count", sa.Integer(), nullable=False,
                      server_default="0"),
        )

    if "guest_reviews" not in tables:
        op.create_table(
            "guest_reviews",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("guest_id", sa.Integer(), nullable=False, index=True),
            # reviewer = chủ nhà (host) đánh giá.
            sa.Column("reviewer_id", sa.Integer(), nullable=False, index=True),
            sa.Column("appointment_id", sa.Integer(), nullable=True),
            sa.Column("rating", sa.Integer(), nullable=False),
            sa.Column("cleanliness", sa.Integer(), nullable=True),
            sa.Column("communication", sa.Integer(), nullable=True),
            sa.Column("rule_observance", sa.Integer(), nullable=True),
            sa.Column("comment", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False,
                      server_default=sa.func.now()),
        )


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "guest_reviews" in tables:
        op.drop_table("guest_reviews")
    if "host_profiles" in tables and "review_count" in _cols("host_profiles"):
        op.drop_column("host_profiles", "review_count")
