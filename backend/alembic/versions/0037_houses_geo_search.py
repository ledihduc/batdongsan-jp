"""houses_geo_search

Geo-search cho houses (tìm địa danh / tỉnh-thành / quanh đây).

Thêm:
- province_code / district_code (String, nullable, indexed) — chuẩn hoá địa giới
  từ city/district free-text (province_code = slug trong vietnam-provinces.json).
- geocode_status (String, default 'pending', indexed) + geocoded_at — phục vụ
  backfill toạ độ idempotent/resumable.
- (Postgres only) cột geom geometry(Point,4326) + GIST index + trigger đồng bộ
  geom từ lat/lng (BEFORE INSERT/UPDATE). geom là nguồn dẫn xuất, lat/lng là
  source of truth. Trigger phủ cả nguồn ghi ngoài ORM (marketplace-sync raw SQL).

Cross-dialect: cột code/status chạy cả SQLite dev; phần PostGIS bị guard bằng
dialect check nên `alembic upgrade head` trên SQLite không lỗi.

Revision ID: 0037_houses_geo_search
Revises: 0036_commission_pct_check_constraint
Create Date: 2026-07-03
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0037_houses_geo_search"
down_revision: Union[str, Sequence[str], None] = "0036_commission_pct_check_constraint"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    dialect = connection.dialect.name

    # ── Cột chuẩn hoá + geocode status: cross-dialect (chạy cả SQLite) ────────
    op.add_column("houses", sa.Column("province_code", sa.String(length=32), nullable=True))
    op.add_column("houses", sa.Column("district_code", sa.String(length=64), nullable=True))
    op.add_column(
        "houses",
        sa.Column("geocode_status", sa.String(length=16), nullable=False, server_default="pending"),
    )
    op.add_column("houses", sa.Column("geocoded_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_houses_province_code", "houses", ["province_code"])
    op.create_index("ix_houses_district_code", "houses", ["district_code"])
    op.create_index("ix_houses_geocode_status", "houses", ["geocode_status"])

    if dialect != "postgresql":
        return  # SQLite dev: không có PostGIS, dừng ở đây.

    # ── Postgres/PostGIS only ────────────────────────────────────────────────
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    op.execute("ALTER TABLE houses ADD COLUMN geom geometry(Point, 4326)")

    # Backfill geom từ lat/lng đã có + đánh dấu geocoded (idempotent).
    op.execute(
        """
        UPDATE houses
           SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326),
               geocode_status = 'geocoded'
         WHERE latitude IS NOT NULL AND longitude IS NOT NULL
        """
    )

    # Trigger giữ geom đồng bộ với lat/lng (nguồn sự thật duy nhất cho geom).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION houses_sync_geom() RETURNS trigger AS $$
        BEGIN
          IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
            NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
          ELSE
            NEW.geom := NULL;
          END IF;
          RETURN NEW;
        END; $$ LANGUAGE plpgsql;
        """
    )
    op.execute(
        """
        CREATE TRIGGER trg_houses_sync_geom
          BEFORE INSERT OR UPDATE OF latitude, longitude ON houses
          FOR EACH ROW EXECUTE FUNCTION houses_sync_geom();
        """
    )

    # GIST index: full + partial (nearby query luôn kèm status='approved' AND geom IS NOT NULL).
    op.execute("CREATE INDEX ix_houses_geom_gist ON houses USING GIST (geom)")
    op.execute(
        """
        CREATE INDEX ix_houses_geom_approved_gist ON houses USING GIST (geom)
          WHERE status = 'approved' AND geom IS NOT NULL
        """
    )


def downgrade() -> None:
    connection = op.get_bind()
    dialect = connection.dialect.name

    if dialect == "postgresql":
        op.execute("DROP TRIGGER IF EXISTS trg_houses_sync_geom ON houses")
        op.execute("DROP FUNCTION IF EXISTS houses_sync_geom()")
        op.execute("DROP INDEX IF EXISTS ix_houses_geom_approved_gist")
        op.execute("DROP INDEX IF EXISTS ix_houses_geom_gist")
        op.execute("ALTER TABLE houses DROP COLUMN IF EXISTS geom")

    op.drop_index("ix_houses_geocode_status", table_name="houses")
    op.drop_index("ix_houses_district_code", table_name="houses")
    op.drop_index("ix_houses_province_code", table_name="houses")
    op.drop_column("houses", "geocoded_at")
    op.drop_column("houses", "geocode_status")
    op.drop_column("houses", "district_code")
    op.drop_column("houses", "province_code")
