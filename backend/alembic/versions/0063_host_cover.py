"""Ảnh bìa storefront cho CHỦ NHÀ (host_profiles.cover_path)

Revision ID: 0063_host_cover
Revises: 0062_contractor_cover

Banner chỉ dành cho host/contractor (không cho member thường). Đặt ở
host_profiles để "chỉ host có banner" là ràng buộc CẤU TRÚC, tránh vanity-creep.
Additive + nullable → an toàn.
"""

from alembic import op
import sqlalchemy as sa

revision = "0063_host_cover"
down_revision = "0062_contractor_cover"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "host_profiles" in tables and "cover_path" not in _cols("host_profiles"):
        op.add_column(
            "host_profiles",
            sa.Column("cover_path", sa.String(length=500), nullable=True),
        )


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "host_profiles" in tables and "cover_path" in _cols("host_profiles"):
        op.drop_column("host_profiles", "cover_path")
