"""Create jp_addresses table for Japanese address lookups.

Phase 00 JP foundation: stores postal code lookup results from the
zipcloud.ibsnet.co.jp API (日本郵便 data). Acts as an address reference
store for the JP region.

Table design:
  - postal_code indexed for fast lookups (multiple rows per code — town level).
  - All address fields nullable (API may not return all granularity levels).
  - kana mirror fields for phonetic display (フリガナ).

Idempotent: checks has_table() before create.
Has downgrade(): drops the table.

Revision ID: 0142_jp_address
Revises: 0141_invoice_currency
"""

from alembic import op
import sqlalchemy as sa

revision = "0142_jp_address"
down_revision = "0141_invoice_currency"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # Idempotent: only create if not already present.
    if not insp.has_table("jp_addresses"):
        op.create_table(
            "jp_addresses",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            # 7-digit postal code without hyphen (normalized on insert).
            sa.Column(
                "postal_code",
                sa.String(7),
                nullable=False,
                comment="7-digit JP postal code without hyphen (e.g. '1500001')",
            ),
            # 都道府県 (prefecture) — e.g. '東京都'
            sa.Column("prefecture", sa.String(20), nullable=True),
            # 市区町村 (city/ward) — e.g. '渋谷区'
            sa.Column("city", sa.String(100), nullable=True),
            # 町域 (town/neighborhood) — e.g. '神南'
            sa.Column("town", sa.String(100), nullable=True),
            # Sub-address fields (not returned by zipcloud; reserved for future data sources)
            sa.Column("chome", sa.String(20), nullable=True),
            sa.Column("banchi", sa.String(20), nullable=True),
            sa.Column("go", sa.String(20), nullable=True),
            sa.Column("building", sa.String(200), nullable=True),
            # フリガナ (phonetic kana) mirror fields
            sa.Column("prefecture_kana", sa.String(30), nullable=True),
            sa.Column("city_kana", sa.String(150), nullable=True),
            sa.Column("town_kana", sa.String(150), nullable=True),
            # Timestamps
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
        # Index on postal_code for fast lookup (primary access pattern).
        op.create_index("ix_jp_addresses_postal_code", "jp_addresses", ["postal_code"])


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if insp.has_table("jp_addresses"):
        op.drop_index("ix_jp_addresses_postal_code", table_name="jp_addresses")
        op.drop_table("jp_addresses")
