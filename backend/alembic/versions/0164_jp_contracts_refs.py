"""Add JP cross-reference FK columns to `contracts`.

Phase-04 schema sweep (Session 5). Wires `contracts` to the four
JP-specific auxiliary tables introduced by Sessions 2a / earlier
(0154-0157) so the invoice & lifecycle services can resolve the
"signed e-contract / IT重説 session / active renewal / exit
settlement" for a lease in a single JOIN rather than a correlated
reverse-lookup by `contract_id` on each aux table.

Columns added on `contracts` (all nullable, additive):

  - jp_econtract_id              INTEGER      → jp_econtracts(id)
                                 Points to the CloudSign-backed signed
                                 PDF (電子契約) rendered + sealed for
                                 this lease. Nullable because paper-
                                 contract flows and in-progress leases
                                 have no signed artefact yet.

  - jp_it_session_id             INTEGER      → jp_it_sessions(id)
                                 Points to the IT重説 (remote
                                 explanation of important matters)
                                 session fulfilling 宅建業法 Art.35
                                 for this contract. Nullable: deferred
                                 per scope-phase-2-defer.md (table
                                 exists upstream as placeholder but
                                 the service flow is not shipped in
                                 Phase-04). FK still wired now so
                                 Phase-05 can start populating
                                 without another ALTER.

  - jp_contract_renewal_id       INTEGER      → jp_contract_renewals(id)
                                 Points to the CURRENT / latest
                                 renewal cycle. 借地借家法 Art.26
                                 defaults contracts to 2-year renewal;
                                 this FK is "fast lookup of the active
                                 cycle" so the service does not scan
                                 all renewals for the contract on
                                 every billing run. Nullable because a
                                 fresh (never-renewed) contract has
                                 no renewal row yet.

  - jp_deposit_settlement_id     INTEGER      → jp_deposit_settlements(id)
                                 Points to the 敷金精算 row created at
                                 contract exit (原状回復 deductions +
                                 refund). Nullable because active
                                 contracts have no settlement yet, and
                                 unique-ish in practice (one settlement
                                 per contract) but we DO NOT add a
                                 UNIQUE constraint here — settlement
                                 revisions / corrections may need a
                                 second row during Phase-05 workflow
                                 iteration. Service enforces 1:1.

  - jp_renewal_cycle_months      SMALLINT     契約更新サイクル (月)
                                 Explicit renewal interval in months.
                                 Not derived from the renewals table
                                 because the FIRST renewal needs to
                                 know "when" before any renewal row
                                 exists. Common values: 24 (2年, the
                                 借地借家法 Art.26 default), 12 (1年
                                 短期借家), 36 (3年 社宅 patterns).
                                 SMALLINT — 32767-month contracts are
                                 not a thing. No CHECK (1..60) —
                                 Session 2 Q2 reasoning (nullable
                                 column + partial-write intermediate
                                 states trip simple range CHECKs).

Design decisions:

- **FK target column choice**: all four aux tables use
  `id SERIAL PK` (`Integer`), so the referencing columns are
  `Integer` to match — not `BigInteger`. Session 4 recommendation
  text proposed BIGINT but the actual aux-table PKs are `Integer`;
  matching the real target width avoids an implicit widening cast
  on JOIN and a future `ALTER TABLE … ALTER COLUMN … TYPE BIGINT`
  if we grow the aux tables (that lift is cheap; the mismatch
  today is costly in query planner surprises).

- **`use_alter=True` on every FK**: the aux tables (0154-0157)
  were created BEFORE this migration lands and already carry
  `contract_id` columns pointing back to `contracts.id`. That is
  not a cycle on paper — the aux side's FK points one way, our
  new FKs point the other way — but at CREATE time the autogen
  dependency sort cannot prove no cycle. `use_alter=True` adds
  the FK as a separate ALTER TABLE after column creation, which
  (a) survives any future circular refactor and (b) matches the
  idempotent inspect-before-add pattern this file follows.

- **No ON DELETE / ON UPDATE cascade**: deliberately omitted.
  JP legal retention rules (宅建業法 Art.49, 10-year retention
  for 重要事項説明書 and signed contracts) mean deleting an aux
  row while a contract still references it is a data-integrity
  bug worth surfacing as a FK violation, not silently cascading
  the pointer to NULL. Service layer must detach before delete.

- **NOT NULL deferred**: all columns ship nullable because
  (a) legacy VN rows have no JP relations, (b) in-progress
  Phase-04 writes populate them incrementally, and (c)
  Session 2's "no CHECK on nullable columns during partial-write
  windows" rule applies. The service enforces "signed-and-active
  contracts MUST have jp_econtract_id" at the API layer.

Revision ID: 0164_jp_contracts_refs
Revises: 0163_jp_payment_schedule
"""

from alembic import op
import sqlalchemy as sa


revision = "0164_jp_contracts_refs"
down_revision = "0163_jp_payment_schedule"
branch_labels = None
depends_on = None


_TABLE = "contracts"

# (col_name, col_type, fk_target_table, fk_target_col, fk_name) — fk_target_table=None
# means a plain scalar column (no FK). fk_name must be stable so downgrade can drop it.
_REF_COLS: tuple[tuple[str, sa.types.TypeEngine, str | None, str | None, str | None], ...] = (
    (
        "jp_econtract_id",
        sa.Integer(),
        "jp_econtracts",
        "id",
        "fk_contracts_jp_econtract_id",
    ),
    (
        "jp_it_session_id",
        sa.Integer(),
        "jp_it_sessions",
        "id",
        "fk_contracts_jp_it_session_id",
    ),
    (
        "jp_contract_renewal_id",
        sa.Integer(),
        "jp_contract_renewals",
        "id",
        "fk_contracts_jp_contract_renewal_id",
    ),
    (
        "jp_deposit_settlement_id",
        sa.Integer(),
        "jp_deposit_settlements",
        "id",
        "fk_contracts_jp_deposit_settlement_id",
    ),
    (
        "jp_renewal_cycle_months",
        sa.SmallInteger(),
        None,
        None,
        None,
    ),
)


def _existing_cols(insp: sa.engine.reflection.Inspector, table: str) -> set[str]:
    if not insp.has_table(table):
        return set()
    return {c["name"] for c in insp.get_columns(table)}


def _existing_fks(insp: sa.engine.reflection.Inspector, table: str) -> set[str]:
    if not insp.has_table(table):
        return set()
    return {fk["name"] for fk in insp.get_foreign_keys(table) if fk.get("name")}


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        raise RuntimeError(
            "Table 'contracts' missing — baseline not applied. "
            "Run earlier migrations first."
        )

    existing_cols = _existing_cols(insp, _TABLE)
    existing_fks = _existing_fks(insp, _TABLE)

    # Step 1: add columns (nullable, no server_default — these are
    # true pointers, NULL means "no related row yet", not a
    # business-constant default).
    for name, col_type, _target_table, _target_col, _fk_name in _REF_COLS:
        if name not in existing_cols:
            op.add_column(
                _TABLE,
                sa.Column(name, col_type, nullable=True),
            )

    # Step 2: add FKs as separate ALTERs (use_alter=True equivalent at
    # the Alembic-op level). Skip targets whose table is missing —
    # the scope policy says FK only if target exists. Skip FKs
    # already present (idempotent re-run after partial failure).
    for name, _col_type, target_table, target_col, fk_name in _REF_COLS:
        if target_table is None or fk_name is None:
            continue
        if not insp.has_table(target_table):
            # Target aux table does not exist in this DB — defer FK to
            # a later migration. Column was still added above so the
            # service can start writing scalars.
            continue
        if fk_name in existing_fks:
            continue
        op.create_foreign_key(
            fk_name,
            _TABLE,
            target_table,
            [name],
            [target_col],
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table(_TABLE):
        return

    existing_cols = _existing_cols(insp, _TABLE)
    existing_fks = _existing_fks(insp, _TABLE)

    # Step 1: drop FKs first (reverse order), so Step 2 column drops
    # do not trip FK-dependency errors on Postgres.
    for name, _col_type, target_table, _target_col, fk_name in reversed(_REF_COLS):
        if target_table is None or fk_name is None:
            continue
        if fk_name in existing_fks:
            op.drop_constraint(fk_name, _TABLE, type_="foreignkey")

    # Step 2: drop columns in reverse-add order.
    for name, _col_type, _target_table, _target_col, _fk_name in reversed(_REF_COLS):
        if name in existing_cols:
            op.drop_column(_TABLE, name)
