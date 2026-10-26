"""Create jp_property_info table — JP physical property attributes.

Stores 間取り/面積/築年数/構造/向き for JP listings.
These fields are display-mandatory in JP real estate law (宅建業法).

Idempotent: checks has_table() before create.
Has downgrade(): drops table and indexes.

Revision ID: 0144_jp_property_info
Revises: 0143_jp_rental_terms
"""

from alembic import op
import sqlalchemy as sa

revision = "0144_jp_property_info"
down_revision = "0143_jp_rental_terms"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if insp.has_table("jp_property_info"):
        return

    op.create_table(
        "jp_property_info",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        # Multi-tenant isolation — see jp_rental_terms for org_id contract.
        # NOTE: org_id is the core multi-tenant isolation key for all JP tables.
        # Every repository list query MUST filter by org_id by default.
        # NOTE: no `index=True` here — explicit op.create_index below owns the
        # ix_jp_property_info_org_id index. Inline `index=True` + same-named
        # explicit create collides on fresh-bootstrap (DuplicateTable).
        sa.Column("org_id", sa.String(64), nullable=True,
                  comment="Broker org tenant ID. MUST be filtered in every list query."),
        sa.Column("region", sa.String(3), nullable=False, server_default="jp",
                  comment="Defense-in-depth region tag. Always 'jp'."),
        # 間取り — floor plan layout enum
        # Values: 1K/1DK/1LDK/2K/2DK/2LDK/3K/3DK/3LDK/4LDK+
        sa.Column("layout", sa.String(10), nullable=True,
                  comment="間取り: 1K/1DK/1LDK/2K/2DK/2LDK/3K/3DK/3LDK/4LDK+"),
        # 専有面積 — exclusive floor area in square meters
        sa.Column("floor_area_sqm", sa.Numeric(7, 2), nullable=True,
                  comment="専有面積 in m². Display mandatory per 宅建業法."),
        # 築年数 — building construction year (calendar year)
        sa.Column("building_year", sa.Integer(), nullable=True,
                  comment="築年 (construction year). Used to compute building age."),
        # 構造 — building structure type
        # RC = 鉄筋コンクリート, WOOD = 木造, STEEL = 鉄骨, SRC = 鉄骨鉄筋コンクリート
        sa.Column("structure", sa.String(10), nullable=True,
                  comment="構造: RC | WOOD | STEEL | SRC"),
        # 階数 — floor number of the unit
        sa.Column("floor_number", sa.Integer(), nullable=True,
                  comment="Unit floor number (1-based). Negative for basement."),
        # 向き — orientation / compass facing
        # Values: N/NE/E/SE/S/SW/W/NW
        sa.Column("orientation", sa.String(2), nullable=True,
                  comment="向き (orientation): N/NE/E/SE/S/SW/W/NW"),
        # 入居可能日 — available move-in date
        sa.Column("available_from", sa.Date(), nullable=True,
                  comment="入居可能日. NULL = currently occupied, confirm with agent."),
        # Timestamps
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    op.create_index("ix_jp_property_info_org_id", "jp_property_info", ["org_id"])
    op.create_index("ix_jp_property_info_layout", "jp_property_info", ["layout"])
    op.create_index("ix_jp_property_info_region", "jp_property_info", ["region"])


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_property_info"):
        return

    op.drop_index("ix_jp_property_info_region", table_name="jp_property_info")
    op.drop_index("ix_jp_property_info_layout", table_name="jp_property_info")
    op.drop_index("ix_jp_property_info_org_id", table_name="jp_property_info")
    op.drop_table("jp_property_info")
