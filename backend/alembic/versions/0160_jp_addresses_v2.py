"""Create jp_addresses_v2 table — JIS-coded canonical JP address store.

Phase-04 schema sweep (Session 1). Standalone, additive, zero coupling to
existing tables. Separate from `jp_addresses` v1 (zipcloud ingest cache)
because v2 is the canonical reference layer sourced from 国土交通省
位置参照情報 (MLIT) + 住所の郵便番号 (JP Post) with JIS X 0401/0402 codes.

Design:
  - postal_code: 7-digit normalized (no hyphen); NOT NULL (lookup key).
  - prefecture_jis: 2-digit JIS X 0401 prefecture code (e.g. '13' = 東京都).
  - city_code: 5-digit JIS X 0402 municipal code (e.g. '13113' = 渋谷区).
  - machi_aza: 町字 — town/aza granularity (JP Post `address3` level).
  - chome / banchi / go: 丁目/番地/号 — sub-locality numeric parts, kept
    nullable because MLIT datasets omit them below town-level.
  - prefecture / city / town: display names (kanji) mirrored for render
    without a code→name join at read time.
  - *_kana: フリガナ phonetic mirror for name-sort / autocomplete.
  - source + source_version: provenance (e.g. 'mlit_isj' / '20250401').
  - Composite index on (prefecture_jis, city_code) for admin-level drill.
  - Index on postal_code for primary read pattern (postal→address).

Discipline: additive + nullable (except postal_code) + idempotent inspect
+ full downgrade().

Revision ID: 0160_jp_addresses_v2
Revises: 0159_consent_pii_encrypted
"""

from alembic import op
import sqlalchemy as sa


revision = "0160_jp_addresses_v2"
down_revision = "0159_consent_pii_encrypted"
branch_labels = None
depends_on = None


_TABLE = "jp_addresses_v2"
_IX_POSTAL = "ix_jp_addresses_v2_postal_code"
_IX_ADMIN = "ix_jp_addresses_v2_pref_city"


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # Idempotent: only create if absent.
    if not insp.has_table(_TABLE):
        op.create_table(
            _TABLE,
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            # Primary lookup key — 7-digit postal code, no hyphen.
            sa.Column(
                "postal_code",
                sa.String(7),
                nullable=False,
                comment="7-digit JP postal code without hyphen (e.g. '1500001')",
            ),
            # JIS X 0401 — 2-digit prefecture code (e.g. '13' = 東京都).
            sa.Column(
                "prefecture_jis",
                sa.String(2),
                nullable=True,
                comment="JIS X 0401 prefecture code (2 digits)",
            ),
            # JIS X 0402 — 5-digit municipal (city/ward/town/village) code.
            sa.Column(
                "city_code",
                sa.String(5),
                nullable=True,
                comment="JIS X 0402 municipal code (5 digits)",
            ),
            # 町字 — town/aza granularity (JP Post address3 level).
            sa.Column("machi_aza", sa.String(200), nullable=True),
            # Sub-locality numeric parts.
            sa.Column("chome", sa.String(20), nullable=True),
            sa.Column("banchi", sa.String(20), nullable=True),
            sa.Column("go", sa.String(20), nullable=True),
            # Display mirrors (kanji).
            sa.Column("prefecture", sa.String(20), nullable=True),
            sa.Column("city", sa.String(100), nullable=True),
            sa.Column("town", sa.String(200), nullable=True),
            # フリガナ phonetic mirrors.
            sa.Column("prefecture_kana", sa.String(30), nullable=True),
            sa.Column("city_kana", sa.String(150), nullable=True),
            sa.Column("town_kana", sa.String(200), nullable=True),
            # Provenance.
            sa.Column(
                "source",
                sa.String(32),
                nullable=True,
                comment="Data source tag (e.g. 'mlit_isj', 'jp_post')",
            ),
            sa.Column(
                "source_version",
                sa.String(32),
                nullable=True,
                comment="Source dataset version (e.g. '20250401')",
            ),
            # Timestamps.
            sa.Column(
                "created_at",
                sa.DateTime(),
                nullable=False,
                server_default=sa.text("CURRENT_TIMESTAMP"),
            ),
            sa.Column(
                "updated_at",
                sa.DateTime(),
                nullable=False,
                server_default=sa.text("CURRENT_TIMESTAMP"),
            ),
        )

    # Indexes — idempotent per-index.
    existing_ix = {ix["name"] for ix in insp.get_indexes(_TABLE)} if insp.has_table(_TABLE) else set()
    if _IX_POSTAL not in existing_ix:
        op.create_index(_IX_POSTAL, _TABLE, ["postal_code"])
    if _IX_ADMIN not in existing_ix:
        op.create_index(_IX_ADMIN, _TABLE, ["prefecture_jis", "city_code"])


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if insp.has_table(_TABLE):
        existing_ix = {ix["name"] for ix in insp.get_indexes(_TABLE)}
        if _IX_ADMIN in existing_ix:
            op.drop_index(_IX_ADMIN, table_name=_TABLE)
        if _IX_POSTAL in existing_ix:
            op.drop_index(_IX_POSTAL, table_name=_TABLE)
        op.drop_table(_TABLE)
