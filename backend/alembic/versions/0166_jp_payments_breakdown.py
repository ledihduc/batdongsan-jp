"""Add 消費税法 Art.28 invoice breakdown columns to `jp_payment_intents`.

Phase-04 schema sweep (Session 7). Composes with:

  - 0151 (`jp_payment_intents`)        : parent table — one row per
                                         payment attempt to Komoju.
                                         Carries only the GROSS
                                         `amount_jpy`; no legal
                                         breakdown.
  - 0162 (`jp_contracts_tax_fields`)   : contract-level 適格請求書
                                         発行事業者 (qualified-issuer)
                                         meta — T-number + 課税
                                         区分 — i.e. WHO is issuing
                                         the invoice and under what
                                         tax regime.
  - 0163 (`jp_payment_schedule`)       : billing-cycle rails — when
                                         to charge.
  - 0165 (`jp_contracts_lifecycle_state`): lease state — guards
                                           whether an invoice is
                                           even legal to issue
                                           ('active' | 'renewing'
                                           allowed, 'draft' | 'ended'
                                           not).

0166 (this one) adds the PER-PAYMENT breakdown that Japan's 消費税法
Art.28 requires on every 適格請求書 (qualified invoice): the gross
`amount_jpy` on 0151 must be decomposable into (i) tax-exempt base
rent (家賃 is 非課税 under 消費税法 Art.6-1 bessho 13), (ii) the
taxable management-fee portion (管理費 is 課税), (iii) the explicit
消費税 amount per Art.30 reduced-tax display rule, (iv) any
延滞金 (late fee), and (v) the issuer's registered T-number per
インボイス制度 (invoice system, started 2023-10-01). Without these
columns the service layer has to BACK-DERIVE the split at invoice
PDF time from side-car tables + hard-coded rates — fragile and
breaks when tenants dispute the breakdown.

Columns added on `jp_payment_intents` (all nullable, additive):

  - jp_rent_amount_jpy      BIGINT  NULL
                            家賃 base rent portion of this payment.
                            非課税 per 消費税法 Art.6-1 bessho 13
                            (住宅の貸付け). Nullable because (a)
                            legacy jp_payment_intents rows (if any)
                            predate the breakdown, (b) non-rental
                            payment intents (deposits, key money
                            paid separately) don't need a rent
                            breakdown.

  - jp_mgmt_fee_jpy         BIGINT  NULL
                            管理費 management-fee portion. 課税
                            (standard 10% consumption tax). Nullable
                            — a payment may be rent-only.

  - jp_consumption_tax_jpy  BIGINT  NULL
                            消費税 amount collected on top of
                            `jp_mgmt_fee_jpy` (and any other
                            taxable components). Must be shown
                            EXPLICITLY on the 適格請求書 per
                            Art.57-4-1. Nullable — zero-rated or
                            tax-exempt payments carry NULL
                            (not 0) to distinguish "not
                            applicable" from "computed, zero".

  - jp_late_fee_jpy         BIGINT  NULL
                            延滞金 charged under lease contract's
                            late-payment clause (typical 14.6%
                            per 民法 Art.419 cap). Nullable — a
                            payment on-time has none.

  - jp_tax_invoice_number   VARCHAR(16)  NULL
                            適格請求書発行事業者登録番号 — the
                            issuer's "T" + 13-digit National Tax
                            Agency registration number (e.g.
                            'T1234567890123'). 14 chars total,
                            VARCHAR(16) gives slack for future
                            format shifts. Pulled from the parent
                            contract's 0162 `jp_qii_t_number` at
                            payment-intent creation time and
                            SNAPSHOTTED here, so historical
                            invoices stay stable even if the
                            contract-level issuer later rotates.
                            Nullable because (a) legacy rows,
                            (b) non-qualified-issuer flows (small
                            landlords below 1,000万円 threshold
                            opt out of the invoice system).

No index on any of these columns:

  - The breakdown fields are READ by invoice-PDF generation keyed
    by `id` (already a PK) or by `invoice_id` (already indexed on
    0151). No GROUP BY or filter query hits these columns.
  - `jp_tax_invoice_number` is a snapshot for audit / display, not
    a lookup key — the authoritative lookup is `jp_contracts_tax_fields`.

Design decisions:

- **BIGINT not NUMERIC(15,0)**: Session 2's `contracts.rent_jpy`
  used NUMERIC(15,0) to match the baseline's existing Numeric
  pricing cols on `contracts`. Here the parent table 0151
  already uses NUMERIC(12,0) for the gross `amount_jpy`, but
  mission brief for Session 7 pins BIGINT. BIGINT (signed
  64-bit) holds up to 9.2 × 10^18 JPY — vastly larger than any
  single rental payment and matches the Python `int` returned
  by the service layer without a Decimal cast on read. Trade:
  the breakdown cols won't align exact-storage-type with
  `amount_jpy` on the same row (NUMERIC(12,0) ≠ BIGINT) —
  acceptable because the service layer casts both to int.

- **All nullable, no server_default**: see per-column notes.
  Backfill is a Phase-05 service responsibility (requires
  joining to the contract's tax meta from 0162), not a
  migration-time computation. A server_default of 0 would
  conflate "unknown breakdown" with "zero", breaking the
  invoice-PDF generator's "if NULL, derive; else trust" branch.

- **No CHECK constraint on sum**: a tempting rule is
  `rent + mgmt_fee + consumption_tax + late_fee = amount_jpy`,
  but it fails on (i) rounding (消費税 rounds to int per invoice
  under 国税庁 bulletin 2023-10), (ii) partial payments where
  the intent amount is a down-payment on a larger invoice,
  (iii) refund flows where sign conventions diverge. Service
  layer validates with a tolerance window; DB stays dumb.

- **VARCHAR(16) for T-number** matches 0162's issuer column
  width. Keep both in sync if either changes.

- **Idempotent per Session 2a convention**: inspect columns
  before add; downgrade reverses order.

- **No index creation**: see note above. Reverse-order
  downgrade only needs to drop columns.

Revision ID: 0166_jp_payments_breakdown
Revises: 0165_jp_contracts_lifecycle_state
"""

from alembic import op
import sqlalchemy as sa


revision = "0166_jp_payments_breakdown"
down_revision = "0165_jp_contracts_lifecycle_state"
branch_labels = None
depends_on = None


_TABLE = "jp_payment_intents"

# Column name → (SQLAlchemy type, comment).
# Order defines upgrade() add order; downgrade() reverses.
_COLUMNS: list[tuple[str, sa.types.TypeEngine, str]] = [
    (
        "jp_rent_amount_jpy",
        sa.BigInteger(),
        "家賃 base rent portion. 非課税 per 消費税法 Art.6-1 bessho 13 "
        "(住宅の貸付け). NULL = legacy row or non-rental payment.",
    ),
    (
        "jp_mgmt_fee_jpy",
        sa.BigInteger(),
        "管理費 management-fee portion. 課税 (10% standard rate). "
        "NULL = rent-only payment with no mgmt fee.",
    ),
    (
        "jp_consumption_tax_jpy",
        sa.BigInteger(),
        "消費税 amount on taxable components. Shown explicitly on "
        "適格請求書 per 消費税法 Art.57-4-1. NULL = not applicable "
        "(distinct from computed-zero).",
    ),
    (
        "jp_late_fee_jpy",
        sa.BigInteger(),
        "延滞金 under late-payment clause (typically capped by 民法 Art.419). "
        "NULL = on-time payment.",
    ),
    (
        "jp_tax_invoice_number",
        sa.String(length=16),
        "適格請求書発行事業者登録番号 — issuer's 'T' + 13-digit NTA "
        "registration number snapshot (e.g. 'T1234567890123'). "
        "Snapshotted from jp_contracts.jp_qii_t_number (0162) at "
        "intent creation. NULL = non-qualified issuer or legacy row.",
    ),
]


def _existing_cols(insp: sa.engine.reflection.Inspector, table: str) -> set[str]:
    if not insp.has_table(table):
        return set()
    return {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        raise RuntimeError(
            f"Table '{_TABLE}' missing — baseline / 0151 not applied. "
            "Run earlier migrations first."
        )

    existing_cols = _existing_cols(insp, _TABLE)

    for name, type_, comment in _COLUMNS:
        if name not in existing_cols:
            op.add_column(
                _TABLE,
                sa.Column(
                    name,
                    type_,
                    nullable=True,
                    comment=comment,
                ),
            )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        return

    existing_cols = _existing_cols(insp, _TABLE)

    # Reverse-order drop.
    for name, _type, _comment in reversed(_COLUMNS):
        if name in existing_cols:
            op.drop_column(_TABLE, name)
