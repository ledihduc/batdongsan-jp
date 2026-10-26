"""Add JPY pricing columns + currency to `contracts` (JP rental agreements).

Phase-04 schema sweep (Session 2). The existing `contracts` table stores
rental agreement pricing in `monthly_rent` + `deposit` (Float, implicit VND
in the VN product). The JP fork needs JPY-denominated pricing on the SAME
agreement row (rather than only on the side-car `jp_rental_terms`), so the
contract header carries the authoritative amount a JP tenant signed.

We ADD mirror columns (nullable, additive) rather than mutate the VN
columns to preserve dual-market compatibility — VN rows keep writing
`monthly_rent`/`deposit`, JP rows write the `*_jpy` triplet plus
`key_money_jpy` (礼金) and `agency_fee_jpy` (仲介手数料) which have NO
VN analog on `contracts`.

Columns added on `contracts`:
  - rent_jpy          NUMERIC(15,0)  monthly rent (家賃)
  - deposit_jpy       NUMERIC(15,0)  敷金 shikikin
  - key_money_jpy     NUMERIC(15,0)  礼金 reikin
  - agency_fee_jpy    NUMERIC(15,0)  仲介手数料 chuukai tesuuryou
  - currency          VARCHAR(3)     ISO 4217 — 'VND' | 'JPY' (nullable,
                                     NULL = legacy row, read as 'VND')

NUMERIC(15,0) chosen over Float to match the invoice-side columns
(`gross_shikikin_jpy` 0157 uses NUMERIC(12,0); 15 picked here to hold up
to 999,999,999,999,999 JPY — safe ceiling for Tokyo luxury rent while
still fitting a 64-bit int if the ORM later casts to int).

No `rental_contracts` sibling table — in this codebase `contracts` IS the
rental agreement. See `app/models/rental.py` line 332 (class Contract).

Discipline:
  - Additive + nullable (zero backfill risk on VN rows).
  - Idempotent: inspect-before-add on every column.
  - Downgrade drops only columns this migration added.
  - `CURRENT_TIMESTAMP` is not needed here (no new timestamp columns).

Revision ID: 0161_jp_rentals_pricing_jpy_cols
Revises: 0160_jp_addresses_v2
"""

from alembic import op
import sqlalchemy as sa


revision = "0161_jp_rentals_pricing_jpy_cols"
down_revision = "0160_jp_addresses_v2"
branch_labels = None
depends_on = None


_TABLE = "contracts"

# Column name → SQLAlchemy column spec (nullable mirrors; no server_default
# so legacy rows read as NULL rather than being silently stamped 0).
_JPY_COLS: tuple[tuple[str, sa.types.TypeEngine], ...] = (
    ("rent_jpy", sa.Numeric(15, 0)),
    ("deposit_jpy", sa.Numeric(15, 0)),
    ("key_money_jpy", sa.Numeric(15, 0)),
    ("agency_fee_jpy", sa.Numeric(15, 0)),
)

_CURRENCY_COL = "currency"


def _existing_cols(insp: sa.engine.reflection.Inspector) -> set[str]:
    if not insp.has_table(_TABLE):
        return set()
    return {c["name"] for c in insp.get_columns(_TABLE)}


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        # Defensive: `contracts` ships from baseline. If missing, abort
        # rather than silently create a half-table.
        raise RuntimeError(
            "Table 'contracts' missing — baseline not applied. "
            "Run earlier migrations first."
        )

    existing = _existing_cols(insp)

    # JPY pricing mirrors — nullable, no server_default (NULL = not a JP row).
    for name, col_type in _JPY_COLS:
        if name not in existing:
            op.add_column(
                _TABLE,
                sa.Column(name, col_type, nullable=True),
            )

    # Currency tag — nullable (legacy VN rows stay NULL; reader treats
    # NULL as 'VND'). No server_default to avoid accidentally retro-tagging
    # historical rows.
    if _CURRENCY_COL not in existing:
        op.add_column(
            _TABLE,
            sa.Column(_CURRENCY_COL, sa.String(3), nullable=True),
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        return

    existing = _existing_cols(insp)

    if _CURRENCY_COL in existing:
        op.drop_column(_TABLE, _CURRENCY_COL)

    # Reverse-order drop of the JPY mirrors.
    for name, _ in reversed(_JPY_COLS):
        if name in existing:
            op.drop_column(_TABLE, name)
