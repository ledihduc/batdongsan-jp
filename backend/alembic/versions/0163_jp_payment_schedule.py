"""Add JP billing-cycle / payment-schedule metadata to `contracts`.

Phase-04 schema sweep (Session 4). Extends `contracts` with five
nullable fields so the service layer can model the Japanese
月末締め翌月末払 ("month-end close, next-month-end pay") convention
and other JP billing-cycle patterns that break the current implicit
"bills on the 1st, due on the 1st, no grace" VN assumption.

Columns added on `contracts` (all nullable, additive):
  - first_bill_date              DATE                初回請求日
                                 Anchor date for the first billing cycle.
                                 Nullable because many legacy / VN rows
                                 have no explicit anchor and the service
                                 computes one from `start_date`. Pure DATE
                                 (no timezone) — billing day is a civil
                                 calendar concept, not a wall-clock event.

  - bill_day_of_month            SMALLINT            請求日 (締め日)
                                 1..31 for an explicit day-of-month, or
                                 the sentinel 99 for 末日 (last day of
                                 month, regardless of month length).
                                 SMALLINT not INT — the valid domain fits
                                 easily in 2 bytes and the saving matters
                                 at scale on `contracts`. No CHECK (99)
                                 constraint here because an audit job is
                                 planned (same reasoning as Session 2 Q2:
                                 nullable + partial writes trip simple
                                 CHECKs on in-progress rows). 29/30/31
                                 are permitted raw — the service layer
                                 normalises to end-of-short-months per
                                 民法 Art.143 (期間の計算).

  - payment_due_day_of_month     SMALLINT            支払期日 (支払日)
                                 1..31 or 99 (末日). Same encoding as
                                 `bill_day_of_month`. The classic JP
                                 commercial lease pattern is bill=99
                                 (月末締め) and due=99 of the NEXT month
                                 (翌月末払) — the "offset in months" is
                                 derived by the service, not stored as
                                 a column, because it is almost always
                                 +0 or +1 and encoding it would invite
                                 drift between two columns that must
                                 agree. Keep the schedule flat; let the
                                 service layer own the cycle calculus.

  - grace_period_days            SMALLINT  DEFAULT 0 支払猶予日数
                                 Days after `payment_due_day_of_month`
                                 before a payment counts as 延滞 (late)
                                 and the late-fee clock starts. DEFAULT
                                 0 on NEW rows (no implicit grace), but
                                 LEFT NULLABLE so legacy rows read as
                                 NULL and the service can distinguish
                                 "explicitly zero grace" from "legacy
                                 row — fall back to tenant default".
                                 server_default = text('0') so Postgres
                                 writes 0 at INSERT time without a Python
                                 round-trip. (Session 1 Q3 pattern: this
                                 IS a safe server_default — it is a
                                 domain constant, not a wall-clock
                                 timestamp.)

  - late_fee_rate_bps            SMALLINT            遅延損害金年率 (bps)
                                 Annual late-fee rate in BASIS POINTS
                                 (1 bps = 0.01%). Stored as an integer
                                 to dodge NUMERIC rounding on daily
                                 accrual math. Hard legal ceiling per
                                 利息制限法 Art.1 + 消費者契約法 Art.9
                                 for consumer contracts is 14.6%/年 for
                                 residential leases (= 1460 bps) under
                                 the common 民法 Art.419 default; the
                                 absolute ceiling in 利息制限法 is 20%/年
                                 (= 2000 bps) for principals under
                                 10万円. We store up to 2000 raw and
                                 let the service enforce the per-contract
                                 class ceiling — SMALLINT (±32767) has
                                 ample headroom. Nullable because many
                                 contracts simply inherit the statutory
                                 default and do not record a rate.

Discipline:
  - Additive + nullable (VN rows + legacy JP rows read as NULL).
  - Idempotent: inspect-before-add per column.
  - Downgrade drops columns in reverse order.
  - server_default only on `grace_period_days` (domain constant 0).
    No server_default on day-of-month or rate columns — those are
    truly unknown for legacy rows and NULL carries that meaning.
  - No CHECK constraints paired across columns — Session 2 Q2 reasoning
    (nullable + partial writes). Audit job owns cross-column rules.
  - No ENUM for the 99 sentinel — keeps forward-compat (future codes
    like 98 = "second-to-last day" land without ALTER TYPE).

Revision ID: 0163_jp_payment_schedule
Revises: 0162_jp_contracts_tax_fields
"""

from alembic import op
import sqlalchemy as sa


revision = "0163_jp_payment_schedule"
down_revision = "0162_jp_contracts_tax_fields"
branch_labels = None
depends_on = None


_TABLE = "contracts"

# (name, type, server_default). Order matters for downgrade (we drop
# in reverse). server_default is a sa.text() or None.
_SCHEDULE_COLS: tuple[tuple[str, sa.types.TypeEngine, sa.sql.elements.TextClause | None], ...] = (
    ("first_bill_date", sa.Date(), None),
    ("bill_day_of_month", sa.SmallInteger(), None),
    ("payment_due_day_of_month", sa.SmallInteger(), None),
    ("grace_period_days", sa.SmallInteger(), sa.text("0")),
    ("late_fee_rate_bps", sa.SmallInteger(), None),
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

    for name, col_type, server_default in _SCHEDULE_COLS:
        if name not in existing:
            op.add_column(
                _TABLE,
                sa.Column(
                    name,
                    col_type,
                    nullable=True,
                    server_default=server_default,
                ),
            )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        return

    existing = _existing_cols(insp)

    # Reverse-order drop of the payment-schedule columns.
    for name, _, _ in reversed(_SCHEDULE_COLS):
        if name in existing:
            op.drop_column(_TABLE, name)
