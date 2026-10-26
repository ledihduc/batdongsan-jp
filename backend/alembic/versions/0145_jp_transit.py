"""Create jp_train_lines, jp_stations, jp_transit_access tables.

駅データ (station data) schema for transit-based listing search.
Data source: 駅データ.jp one-shot CSV import (quarterly refresh).

jp_train_lines: canonical train line reference (e.g. 山手線, 東京メトロ銀座線)
jp_stations: individual station records linked to one or more lines
jp_transit_access: listing <-> station walk-time association

Idempotent: checks has_table() before each create.
Has downgrade(): drops all three tables in FK-safe order.

Revision ID: 0145_jp_transit
Revises: 0144_jp_property_info
"""

from alembic import op
import sqlalchemy as sa

revision = "0145_jp_transit"
down_revision = "0144_jp_property_info"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # -- jp_train_lines -------------------------------------------------
    if not insp.has_table("jp_train_lines"):
        op.create_table(
            "jp_train_lines",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            # Official line name in Japanese (e.g. '山手線')
            sa.Column("name_ja", sa.String(100), nullable=False,
                      comment="路線名 in Japanese (e.g. '山手線')"),
            # Romanized name for search/display (e.g. 'Yamanote Line')
            sa.Column("name_en", sa.String(100), nullable=True,
                      comment="Romanized line name for display"),
            # Operator company (e.g. 'JR東日本', '東京メトロ')
            sa.Column("operator", sa.String(100), nullable=True,
                      comment="鉄道会社 operator name"),
            # External reference code from 駅データ.jp (line_cd)
            sa.Column("ekidata_line_cd", sa.Integer(), nullable=True, unique=True,
                      comment="駅データ.jp line_cd for quarterly refresh idempotency"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_jp_train_lines_name_ja", "jp_train_lines", ["name_ja"])
        op.create_index("ix_jp_train_lines_ekidata_line_cd", "jp_train_lines", ["ekidata_line_cd"])

    # -- jp_stations ----------------------------------------------------
    if not insp.has_table("jp_stations"):
        op.create_table(
            "jp_stations",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            # FK to jp_train_lines (primary line — station may appear on multiple lines)
            sa.Column("line_id", sa.Integer(), sa.ForeignKey("jp_train_lines.id"), nullable=True,
                      comment="Primary line FK. Station may exist on multiple lines."),
            # Station name in Japanese (e.g. '渋谷')
            sa.Column("name_ja", sa.String(100), nullable=False,
                      comment="駅名 in Japanese (e.g. '渋谷')"),
            # Romanized station name
            sa.Column("name_en", sa.String(100), nullable=True,
                      comment="Romanized station name"),
            # Prefecture (都道府県) for regional filtering
            sa.Column("prefecture", sa.String(20), nullable=True,
                      comment="都道府県 (e.g. '東京都')"),
            # Geographic coordinates for map display
            sa.Column("latitude", sa.Numeric(10, 7), nullable=True),
            sa.Column("longitude", sa.Numeric(10, 7), nullable=True),
            # External reference code from 駅データ.jp (station_cd)
            sa.Column("ekidata_station_cd", sa.Integer(), nullable=True, unique=True,
                      comment="駅データ.jp station_cd for quarterly refresh idempotency"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_jp_stations_name_ja", "jp_stations", ["name_ja"])
        op.create_index("ix_jp_stations_prefecture", "jp_stations", ["prefecture"])
        op.create_index("ix_jp_stations_line_id", "jp_stations", ["line_id"])
        op.create_index("ix_jp_stations_ekidata_station_cd", "jp_stations", ["ekidata_station_cd"])

    # -- jp_transit_access ----------------------------------------------
    if not insp.has_table("jp_transit_access"):
        op.create_table(
            "jp_transit_access",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            # Listing reference — nullable string to avoid FK dependency on core listing table.
            # The listing_id is a string UUID matching app/models.py Listing.id convention.
            # No inline index=True — explicit op.create_index below owns the
            # ix_jp_transit_access_listing_id index.
            sa.Column("listing_id", sa.String(64), nullable=False,
                      comment="Listing UUID (no FK to avoid cross-schema dep)"),
            sa.Column("station_id", sa.Integer(), sa.ForeignKey("jp_stations.id"), nullable=False),
            # Walk time in minutes (徒歩分数)
            sa.Column("walk_min", sa.Integer(), nullable=False,
                      comment="徒歩分数 from listing to station. Max 60."),
            # Multi-tenant isolation
            # NOTE: org_id is the core multi-tenant isolation key for all JP tables.
            # Every repository list query MUST filter by org_id by default.
            # No inline index=True — explicit op.create_index below owns the
            # ix_jp_transit_access_org_id index.
            sa.Column("org_id", sa.String(64), nullable=True,
                      comment="Broker org tenant ID. MUST be filtered in every list query."),
            sa.Column("region", sa.String(3), nullable=False, server_default="jp"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_jp_transit_access_listing_id", "jp_transit_access", ["listing_id"])
        op.create_index("ix_jp_transit_access_org_id", "jp_transit_access", ["org_id"])
        # Composite index for org-scoped listing transit lookup
        op.create_index(
            "ix_jp_transit_access_org_listing",
            "jp_transit_access",
            ["org_id", "listing_id"],
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # Drop in FK-safe reverse order
    if insp.has_table("jp_transit_access"):
        op.drop_index("ix_jp_transit_access_org_listing", table_name="jp_transit_access")
        op.drop_index("ix_jp_transit_access_org_id", table_name="jp_transit_access")
        op.drop_index("ix_jp_transit_access_listing_id", table_name="jp_transit_access")
        op.drop_table("jp_transit_access")

    if insp.has_table("jp_stations"):
        op.drop_index("ix_jp_stations_ekidata_station_cd", table_name="jp_stations")
        op.drop_index("ix_jp_stations_line_id", table_name="jp_stations")
        op.drop_index("ix_jp_stations_prefecture", table_name="jp_stations")
        op.drop_index("ix_jp_stations_name_ja", table_name="jp_stations")
        op.drop_table("jp_stations")

    if insp.has_table("jp_train_lines"):
        op.drop_index("ix_jp_train_lines_ekidata_line_cd", table_name="jp_train_lines")
        op.drop_index("ix_jp_train_lines_name_ja", table_name="jp_train_lines")
        op.drop_table("jp_train_lines")
