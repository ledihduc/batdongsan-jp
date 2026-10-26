"""Add JP contract lifecycle state machine column to `contracts`.

Phase-04 schema sweep (Session 6). Composes with 0164:

  - 0164 gave `contracts` four FK pointers to the aux tables
    (jp_econtracts / jp_it_sessions / jp_contract_renewals /
    jp_deposit_settlements) + `jp_renewal_cycle_months`.
    Those FKs answer "WHICH aux row for this contract?".

  - 0165 (this one) adds the lifecycle STATE column + its
    transition timestamp. It answers "WHICH PHASE of the
    JP lease lifecycle is this contract currently in?",
    without forcing the service / admin dashboard to
    JOIN all four aux tables and run a derivation
    (CASE WHEN jp_deposit_settlement_id IS NOT NULL THEN
    'settled' WHEN jp_contract_renewal_id IS NOT NULL
    THEN 'renewing' ...) on every read.

Columns added on `contracts` (both nullable, additive):

  - jp_lifecycle_state           VARCHAR(32)  NULL
                                 Current phase of the JP lease
                                 lifecycle state machine. Valid
                                 values (documented in column
                                 comment; NOT enforced by CHECK
                                 constraint — see "No CHECK" note):

                                   'draft'       : 契約書作成中 — lease
                                                   terms being drawn
                                                   up, no 重説 yet.
                                   'it_pending'  : IT重説 session
                                                   scheduled but not
                                                   executed (jp_it_sessions
                                                   row exists, status
                                                   not 'completed').
                                   'it_done'     : 重要事項説明 完了 —
                                                   tenant has received
                                                   explanation per
                                                   宅建業法 Art.35; ready
                                                   to sign.
                                   'signed'      : CloudSign 電子契約
                                                   sealed (jp_econtract_id
                                                   populated), lease not
                                                   yet in effect.
                                   'active'      : 契約期間中 — lease in
                                                   force, rent cycle
                                                   running.
                                   'renewing'    : 更新手続き中 — within
                                                   the 借地借家法 Art.26
                                                   renewal window; new
                                                   jp_contract_renewal
                                                   row open.
                                   'ended'       : 契約終了 — lease
                                                   expired or terminated,
                                                   move-out complete,
                                                   settlement pending.
                                   'settled'     : 敷金精算 完了 —
                                                   jp_deposit_settlement
                                                   row finalised,
                                                   contract archived.

                                 Nullable because (a) legacy VN
                                 contracts have no JP lifecycle,
                                 (b) in-progress Phase-04 writes
                                 populate incrementally, (c)
                                 Phase-05 webhook handlers (the
                                 real producer of these values)
                                 ship after this migration.

  - jp_lifecycle_state_changed_at TIMESTAMP(timezone=True) NULL
                                 Timestamp of the LAST transition
                                 into the current state. Used by
                                 admin dashboard for "contracts
                                 stuck in 'it_pending' > 7 days"
                                 queries and by Phase-05 reminder
                                 cron. Nullable mirrors the state
                                 column.

Index added:

  - ix_contracts_jp_lifecycle_state ON (jp_lifecycle_state)
                                 B-tree index on the state column
                                 for the admin dashboard's
                                 "GROUP BY state COUNT(*)" and
                                 "WHERE state = 'it_pending'"
                                 queries. Non-unique (many contracts
                                 share each state). Postgres will
                                 skip NULL rows by default in B-tree
                                 which is fine — legacy VN rows
                                 don't need indexing.

Design decisions:

- **VARCHAR(32), not ENUM**: deliberate. Postgres ENUM types
  make ADD VALUE cheap but RENAME / DROP VALUE a schema-rewrite
  pain, and Phase-05 is still negotiating the exact state
  vocabulary with the ops team. String column + documented
  domain in the column comment + service-layer validation
  gives us "cheap ALTER" when the state list shifts, at the
  cost of DB-level enforcement. Session 2's rationale for
  "no CHECK on nullable columns during partial-write
  windows" applies equally here: a CHECK (state IN (...))
  would need an ALTER + table scan on every vocabulary
  change. We accept the trade.

- **No CHECK constraint on allowed values**: see above. The
  service layer (Phase-05 state_machine.py) enforces the
  transition graph AND the value set. DB stays permissive
  so partial writes during multi-step flows don't trip.

- **jp_lifecycle_state_changed_at nullable, no server_default**:
  NULL means "never transitioned" (fresh row), not "transitioned
  at migration time". A server_default of `now()` would
  falsely stamp every legacy row as "transitioned at migration
  deploy time", polluting the admin dashboard's dwell-time
  queries. Service writes the timestamp explicitly on each
  transition via the state_machine.

- **Index is non-unique, no WHERE clause**: a partial index
  (`WHERE jp_lifecycle_state IS NOT NULL`) would be smaller
  on the Postgres heap given most rows are legacy VN NULL,
  BUT it complicates the "count by state including the
  implicit 'legacy'/'unmapped' bucket" query the admin
  dashboard needs. Full non-unique B-tree keeps the SQL
  dumb and reindex cost is trivial at current contract
  volume.

- **Idempotent per Session 2a convention**: inspect columns
  + inspect indexes before create. Index creation uses
  `op.create_index` guarded by presence check (Alembic
  doesn't expose IF NOT EXISTS cleanly for cross-dialect
  support, so we inspect).

- **Reverse-order downgrade**: drop index → drop
  `jp_lifecycle_state_changed_at` → drop `jp_lifecycle_state`.
  Index must go first because dropping the indexed column
  would otherwise cascade-drop the index with a warning;
  explicit drop keeps the migration deterministic.

Revision ID: 0165_jp_contracts_lifecycle_state
Revises: 0164_jp_contracts_refs
"""

from alembic import op
import sqlalchemy as sa


revision = "0165_jp_contracts_lifecycle_state"
down_revision = "0164_jp_contracts_refs"
branch_labels = None
depends_on = None


_TABLE = "contracts"
_STATE_COL = "jp_lifecycle_state"
_CHANGED_AT_COL = "jp_lifecycle_state_changed_at"
_INDEX_NAME = "ix_contracts_jp_lifecycle_state"

# Documented in column comment so psql \d+ contracts shows the vocabulary.
_STATE_COMMENT = (
    "JP lease lifecycle phase. One of: "
    "'draft' | 'it_pending' | 'it_done' | 'signed' | "
    "'active' | 'renewing' | 'ended' | 'settled'. "
    "NULL = legacy VN row / not-yet-mapped. "
    "Enforced by service layer, not DB CHECK (Phase-05)."
)
_CHANGED_AT_COMMENT = (
    "UTC timestamp of the last transition into the current "
    "jp_lifecycle_state. NULL = never transitioned."
)


def _existing_cols(insp: sa.engine.reflection.Inspector, table: str) -> set[str]:
    if not insp.has_table(table):
        return set()
    return {c["name"] for c in insp.get_columns(table)}


def _existing_indexes(insp: sa.engine.reflection.Inspector, table: str) -> set[str]:
    if not insp.has_table(table):
        return set()
    return {ix["name"] for ix in insp.get_indexes(table) if ix.get("name")}


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        raise RuntimeError(
            "Table 'contracts' missing — baseline not applied. "
            "Run earlier migrations first."
        )

    existing_cols = _existing_cols(insp, _TABLE)
    existing_indexes = _existing_indexes(insp, _TABLE)

    # Step 1: add state column (nullable, no server_default).
    if _STATE_COL not in existing_cols:
        op.add_column(
            _TABLE,
            sa.Column(
                _STATE_COL,
                sa.String(length=32),
                nullable=True,
                comment=_STATE_COMMENT,
            ),
        )

    # Step 2: add transition-timestamp column (nullable, no server_default
    # — see docstring "No server_default" note).
    if _CHANGED_AT_COL not in existing_cols:
        op.add_column(
            _TABLE,
            sa.Column(
                _CHANGED_AT_COL,
                sa.DateTime(timezone=True),
                nullable=True,
                comment=_CHANGED_AT_COMMENT,
            ),
        )

    # Step 3: add index on state column (idempotent).
    if _INDEX_NAME not in existing_indexes:
        op.create_index(
            _INDEX_NAME,
            _TABLE,
            [_STATE_COL],
            unique=False,
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        return

    existing_cols = _existing_cols(insp, _TABLE)
    existing_indexes = _existing_indexes(insp, _TABLE)

    # Step 1: drop index first (reverse order).
    if _INDEX_NAME in existing_indexes:
        op.drop_index(_INDEX_NAME, table_name=_TABLE)

    # Step 2: drop timestamp column.
    if _CHANGED_AT_COL in existing_cols:
        op.drop_column(_TABLE, _CHANGED_AT_COL)

    # Step 3: drop state column.
    if _STATE_COL in existing_cols:
        op.drop_column(_TABLE, _STATE_COL)
