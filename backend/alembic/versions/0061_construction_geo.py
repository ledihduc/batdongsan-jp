"""Đăng bài thi công giàu thông tin: toạ độ bản đồ + địa danh cho lead & post

Revision ID: 0061_construction_geo
Revises: 0060_guest_reviews

Cho form đăng thi công thống nhất (kiểu Facebook) ghim được VỊ TRÍ trên bản đồ:
  - construction_leads: thêm lat/lng + ward_slug + location_text (đã có images,
    province_code, district_code từ trước → khách "Cần thi công" đính ảnh + ghim
    bản đồ được).
  - social_posts: thêm lat/lng (đã có province/ward/location_text) → bài "Chia sẻ
    công trình" ghim bản đồ được.

Tất cả additive + nullable → an toàn, không ảnh hưởng dữ liệu cũ.
"""

from alembic import op
import sqlalchemy as sa

revision = "0061_construction_geo"
down_revision = "0060_guest_reviews"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())

    if "construction_leads" in tables:
        cols = _cols("construction_leads")
        if "lat" not in cols:
            op.add_column("construction_leads",
                          sa.Column("lat", sa.Float(), nullable=True))
        if "lng" not in cols:
            op.add_column("construction_leads",
                          sa.Column("lng", sa.Float(), nullable=True))
        if "ward_slug" not in cols:
            op.add_column("construction_leads",
                          sa.Column("ward_slug", sa.String(length=80), nullable=True))
        if "location_text" not in cols:
            op.add_column("construction_leads",
                          sa.Column("location_text", sa.String(length=200), nullable=True))

    if "social_posts" in tables:
        cols = _cols("social_posts")
        if "lat" not in cols:
            op.add_column("social_posts",
                          sa.Column("lat", sa.Float(), nullable=True))
        if "lng" not in cols:
            op.add_column("social_posts",
                          sa.Column("lng", sa.Float(), nullable=True))


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "social_posts" in tables:
        cols = _cols("social_posts")
        for c in ("lat", "lng"):
            if c in cols:
                op.drop_column("social_posts", c)
    if "construction_leads" in tables:
        cols = _cols("construction_leads")
        for c in ("location_text", "ward_slug", "lng", "lat"):
            if c in cols:
                op.drop_column("construction_leads", c)
