"""Add 消費税 / インボイス制度 tax metadata columns to `contracts`.

Phase-04 schema sweep (Session 3). Extends `contracts` with the four
tax/invoice fields JP operations need to produce 適格請求書 (qualified
invoices) under 令和5年10月1日 施行 インボイス制度 (法 Art.57-2):

Columns added on `contracts`:
  - tax_treatment               VARCHAR(16)                消費税区分
                                nullable. Enum-ish values written by the
                                service layer:
                                  '内税'  — tax-inclusive (price = net+tax)
                                  '外税'  — tax-exclusive (price = net; tax added)
                                  '免税'  — tax-exempt (reikin / shikikin lines,
                                           non-rent charges, non-taxable
                                           supply under 消費税法 Art.6)
                                Not an enum type at DB level — kept as
                                VARCHAR for forward-compat (future codes
                                like '軽減' for 8% reduced-rate line items
                                can land without an ALTER TYPE).

  - invoice_issuer_id           VARCHAR(14)                適格請求書発行事業者登録番号
                                nullable. Format: 'T' + 13 digits (per
                                NTA spec; legal entities use the 法人番号
                                as the trailing 13 digits, individuals
                                use an NTA-assigned 13-digit code). The
                                'T' prefix is MANDATORY in the registered
                                string per 国税庁 guidance — stored as the
                                full 14-char string so downstream printers
                                / PDF generators do not have to re-prefix.
                                VARCHAR(14) not CHAR(14) because stored
                                values may be shorter during data-entry
                                intermediate states (before verification).

  - tax_registration_verified_at TIMESTAMP(timezone=True)  照合済み日時
                                nullable. Set when `invoice_issuer_id`
                                has been matched against the 国税庁
                                適格請求書発行事業者公表サイト. NULL means
                                either (a) no issuer ID yet, or (b) ID
                                present but not yet verified. The
                                service layer treats a non-NULL value
                                here as "safe to print on invoices".
                                No `server_default` — must be explicitly
                                set after a successful verification call.

  - consumption_tax_rate        NUMERIC(4,2)                消費税率
                                nullable. Expected values:
                                  10.00 — standard rate (default rent /
                                          service fees since 2019-10-01)
                                   8.00 — 軽減税率 reduced rate (food
                                          subscriptions, 定期購読新聞;
                                          rarely applies to rental but
                                          may apply to bundled line items
                                          on a lease like a weekly news
                                          delivery)
                                   0.00 — explicitly 0 (edge: specified
                                          non-taxable supply where the
                                          contract still records the
                                          calculation base for audit)
                                NUMERIC(4,2) chosen so rounding stays
                                exact (float Would drift at 10.00 - 8.00
                                equality checks).

Discipline:
  - Additive + nullable (VN rows + legacy JP rows read as NULL).
  - Idempotent: inspect-before-add per column.
  - Downgrade drops columns in reverse order.
  - No `server_default` on `tax_registration_verified_at` — timestamp
    semantics are "when verification happened"; `CURRENT_TIMESTAMP` would
    retro-stamp historical rows as verified-at-upgrade-time, which is a
    data-integrity lie. Service layer sets the value on real verification.
    (Session 1 Q3 answer: CURRENT_TIMESTAMP default is for "row-created"
    / "row-modified" audit cols; this column is domain-event timestamp.)
  - No CHECK constraint pairing `invoice_issuer_id` and
    `tax_registration_verified_at` — same reasoning as Session 2 Q2
    (nullable mirror pairs trip on partial writes). Audit job later.
  - No ENUM type for `tax_treatment` — see rationale above (forward-compat
    without ALTER TYPE ceremony).

Revision ID: 0162_jp_contracts_tax_fields
Revises: 0161_jp_rentals_pricing_jpy_cols
"""

from alembic import op
import sqlalchemy as sa


revision = "0162_jp_contracts_tax_fields"
down_revision = "0161_jp_rentals_pricing_jpy_cols"
branch_labels = None
depends_on = None


_TABLE = "contracts"

# Column name → SQLAlchemy column spec. Order matters for downgrade
# (we drop in reverse).
_TAX_COLS: tuple[tuple[str, sa.types.TypeEngine], ...] = (
    ("tax_treatment", sa.String(16)),
    ("invoice_issuer_id", sa.String(14)),
    ("tax_registration_verified_at", sa.DateTime(timezone=True)),
    ("consumption_tax_rate", sa.Numeric(4, 2)),
)


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

    for name, col_type in _TAX_COLS:
        if name not in existing:
            op.add_column(
                _TABLE,
                sa.Column(name, col_type, nullable=True),
            )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        return

    existing = _existing_cols(insp)

    # Reverse-order drop of the tax metadata columns.
    for name, _ in reversed(_TAX_COLS):
        if name in existing:
            op.drop_column(_TABLE, name)
