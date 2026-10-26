"""add joined_at_datetime to contract_tenants with backfill

Revision ID: 0031_add_contract_tenants_joined_datetime
Revises: 0030_extend_contracts_kb04_form_data
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-55b: millisecond-precision move-in time for 6h SLA post-move-in

ContractTenant.joined_at is STR(20) ISO date (day-precision only — researcher-02 §B).
For AC-55b 6h SLA post-move-in, we need DateTime precision.

Dual-write transition strategy:
  - Add joined_at_datetime (DateTime, nullable) alongside existing joined_at (str)
  - Backfill: parse joined_at date string → set time = 00:00:00
  - New writes populate BOTH columns (dual-write) until phase-11 switchover
  - DO NOT drop joined_at in this migration (keep for backward-compat)
  - Phase-11 verifies all reads use joined_at_datetime, then drops joined_at

Backfill strategy (chunked to avoid table locks on large tenant base):
  - UPDATE ... WHERE id BETWEEN :lo AND :hi, batches of 1000 rows
  - Data-quality issues wrapped in try/except (NULL joined_at → NULL datetime)
  - Runs only on PostgreSQL (SQLite: joined_at already handled via create_all)
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0031_add_contract_tenants_joined_datetime"
down_revision = "0030_extend_contracts_kb04_form_data"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("contract_tenants") as batch_op:
        # Add nullable column — backfill below
        batch_op.add_column(
            sa.Column("joined_at_datetime", sa.DateTime, nullable=True)
        )

    # Backfill from existing joined_at (ISO date string → midnight DateTime)
    # PostgreSQL: use CAST ... AS TIMESTAMP for type coercion
    # SQLite: parsed via Python strptime (create_all path — no data in dev)
    conn = op.get_bind()
    if conn.dialect.name == "postgresql":
        _backfill_postgres(conn)
    elif conn.dialect.name == "sqlite":
        # SQLite dev: no production data to backfill; new create_all sets up empty schema
        pass


def _backfill_postgres(conn) -> None:
    """Chunked UPDATE to avoid table lock on large contract_tenants table.

    Postgres only. Batches of 1000 rows. Skips NULL joined_at (no data-quality error).
    Set lock_timeout = 30s to abort on blocking lock.
    """
    try:
        conn.execute(sa.text("SET lock_timeout = '30s'"))

        # Find row ID range for chunking
        result = conn.execute(
            sa.text(
                "SELECT MIN(contract_id), MAX(contract_id) "
                "FROM contract_tenants WHERE joined_at IS NOT NULL"
            )
        ).fetchone()

        if result is None or result[0] is None:
            return  # No rows to backfill

        min_id, max_id = result[0], result[1]
        batch_size = 1000
        lo = min_id

        while lo <= max_id:
            hi = lo + batch_size
            conn.execute(
                sa.text(
                    """
                    UPDATE contract_tenants
                    SET joined_at_datetime = TO_TIMESTAMP(joined_at, 'YYYY-MM-DD')
                    WHERE contract_id BETWEEN :lo AND :hi
                      AND joined_at IS NOT NULL
                      AND joined_at_datetime IS NULL
                      AND joined_at ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                    """
                ),
                {"lo": lo, "hi": hi},
            )
            lo = hi + 1
    except Exception as exc:  # noqa: BLE001
        # Log and continue — backfill failure should not block schema migration
        import warnings
        warnings.warn(
            f"contract_tenants.joined_at_datetime backfill encountered error: {exc}. "
            "Manual backfill may be needed: "
            "UPDATE contract_tenants SET joined_at_datetime = TO_TIMESTAMP(joined_at, 'YYYY-MM-DD') "
            "WHERE joined_at IS NOT NULL;",
            RuntimeWarning,
            stacklevel=2,
        )


def downgrade() -> None:
    with op.batch_alter_table("contract_tenants") as batch_op:
        batch_op.drop_column("joined_at_datetime")
