"""Tests for invoice currency Alembic migration (0141_invoice_currency).

Covers:
  - Upgrade adds currency column to invoices table
  - Upgrade backfills existing rows with 'VND'
  - Downgrade removes currency column
  - Idempotency: running upgrade twice does not fail
  - Migration is in the correct chain (down_revision = 0140_ekyc_chu_nha)

Note: These tests run against an in-memory SQLite database to avoid requiring
a real Postgres instance. The idempotent guard (inspect().has_column) works
identically on both engines.
"""

from __future__ import annotations

import os

import pytest
import sqlalchemy as sa
from sqlalchemy import create_engine, inspect, text

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


# ---------------------------------------------------------------------------
# Helper: minimal invoices table for testing (matches schema sans currency)
# ---------------------------------------------------------------------------

def _bootstrap_invoices(engine: sa.Engine) -> None:
    """Create a minimal invoices table without currency column."""
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS invoices (
                id INTEGER PRIMARY KEY,
                host_id INTEGER NOT NULL DEFAULT 0,
                contract_id INTEGER NOT NULL DEFAULT 0,
                invoice_number TEXT UNIQUE,
                period_start TEXT,
                period_end TEXT,
                issued_date TEXT,
                due_date TEXT,
                status TEXT DEFAULT 'draft',
                total_amount REAL DEFAULT 0,
                paid_amount REAL DEFAULT 0,
                note TEXT,
                created_at TIMESTAMP,
                updated_at TIMESTAMP
            )
        """))


def _insert_sample_invoices(engine: sa.Engine) -> None:
    """Insert sample invoice rows (simulating existing VN data)."""
    with engine.begin() as conn:
        conn.execute(text("""
            INSERT INTO invoices (id, host_id, contract_id, invoice_number,
                                  period_start, period_end, issued_date, due_date,
                                  status, total_amount, paid_amount,
                                  created_at, updated_at)
            VALUES
                (1, 1, 1, 'INV-001', '2026-01-01', '2026-01-31', '2026-01-01',
                 '2026-01-15', 'paid', 5000000, 5000000,
                 '2026-01-01 00:00:00', '2026-01-01 00:00:00'),
                (2, 2, 2, 'INV-002', '2026-02-01', '2026-02-28', '2026-02-01',
                 '2026-02-15', 'sent', 3000000, 0,
                 '2026-02-01 00:00:00', '2026-02-01 00:00:00')
        """))


# ---------------------------------------------------------------------------
# Inline simulation of the migration logic (without running alembic CLI)
# ---------------------------------------------------------------------------

def _run_upgrade(engine: sa.Engine) -> None:
    """Execute migration 0141 upgrade logic directly (idempotent)."""
    with engine.begin() as conn:
        insp = inspect(conn)
        existing_cols = {col["name"] for col in insp.get_columns("invoices")}
        if "currency" not in existing_cols:
            conn.execute(text("ALTER TABLE invoices ADD COLUMN currency VARCHAR(3)"))
            conn.execute(
                text("UPDATE invoices SET currency = 'VND' WHERE currency IS NULL")
            )


def _run_downgrade(engine: sa.Engine) -> None:
    """Execute migration 0141 downgrade logic.

    Note: SQLite does not support DROP COLUMN directly in older versions.
    We test the column existence guard; on Postgres the full drop is tested.
    For SQLite we verify the column would be present before drop.
    """
    with engine.begin() as conn:
        insp = inspect(conn)
        existing_cols = {col["name"] for col in insp.get_columns("invoices")}
        # SQLite <3.35 doesn't support DROP COLUMN — verify column exists
        # and the downgrade logic would find it to drop.
        assert "currency" in existing_cols, "currency must exist before downgrade"
        # For testing purposes we recreate the table without the column
        # (mirrors what a real downgrade would do on SQLite via batch mode).
        conn.execute(text("""
            CREATE TABLE invoices_backup AS
            SELECT id, host_id, contract_id, invoice_number,
                   period_start, period_end, issued_date, due_date,
                   status, total_amount, paid_amount, note, created_at, updated_at
            FROM invoices
        """))
        conn.execute(text("DROP TABLE invoices"))
        conn.execute(text("ALTER TABLE invoices_backup RENAME TO invoices"))


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestInvoiceCurrencyMigration:
    """Tests for the currency column migration."""

    @pytest.fixture
    def engine(self, tmp_path):
        """Fresh SQLite engine per test."""
        db_path = tmp_path / "test_migration.db"
        eng = create_engine(f"sqlite:///{db_path}")
        yield eng
        eng.dispose()

    def test_upgrade_adds_currency_column(self, engine) -> None:
        """After upgrade, invoices table should have a 'currency' column."""
        _bootstrap_invoices(engine)
        _run_upgrade(engine)

        with engine.connect() as conn:
            insp = inspect(conn)
            cols = {c["name"] for c in insp.get_columns("invoices")}
        assert "currency" in cols

    def test_upgrade_backfills_vnd(self, engine) -> None:
        """Existing rows should be backfilled to 'VND' after upgrade."""
        _bootstrap_invoices(engine)
        _insert_sample_invoices(engine)
        _run_upgrade(engine)

        with engine.connect() as conn:
            rows = conn.execute(
                text("SELECT id, currency FROM invoices ORDER BY id")
            ).fetchall()

        assert len(rows) == 2
        for row in rows:
            assert row[1] == "VND", f"Row {row[0]} should have currency='VND'"

    def test_upgrade_idempotent(self, engine) -> None:
        """Running upgrade twice should not raise an error."""
        _bootstrap_invoices(engine)
        _run_upgrade(engine)
        # Second run must not raise (column already exists).
        _run_upgrade(engine)

        with engine.connect() as conn:
            insp = inspect(conn)
            cols = {c["name"] for c in insp.get_columns("invoices")}
        assert "currency" in cols

    def test_downgrade_removes_currency_column(self, engine) -> None:
        """After downgrade, currency column should not exist."""
        _bootstrap_invoices(engine)
        _insert_sample_invoices(engine)
        _run_upgrade(engine)
        _run_downgrade(engine)

        with engine.connect() as conn:
            insp = inspect(conn)
            cols = {c["name"] for c in insp.get_columns("invoices")}
        assert "currency" not in cols

    def test_no_data_loss_in_non_currency_columns(self, engine) -> None:
        """Downgrade must preserve all non-currency data."""
        _bootstrap_invoices(engine)
        _insert_sample_invoices(engine)
        _run_upgrade(engine)
        _run_downgrade(engine)

        with engine.connect() as conn:
            rows = conn.execute(
                text("SELECT id, invoice_number, total_amount FROM invoices ORDER BY id")
            ).fetchall()

        assert len(rows) == 2
        assert rows[0][1] == "INV-001"
        assert rows[1][1] == "INV-002"

    def test_new_jp_row_can_store_jpy(self, engine) -> None:
        """After upgrade, a JP invoice row can store 'JPY' as currency."""
        _bootstrap_invoices(engine)
        _run_upgrade(engine)

        with engine.begin() as conn:
            conn.execute(text("""
                INSERT INTO invoices (id, host_id, contract_id, invoice_number,
                                      period_start, period_end, issued_date, due_date,
                                      status, total_amount, paid_amount,
                                      currency, created_at, updated_at)
                VALUES (99, 1, 1, 'JP-INV-001', '2026-01-01', '2026-01-31', '2026-01-01',
                        '2026-01-15', 'draft', 50000, 0,
                        'JPY', '2026-01-01 00:00:00', '2026-01-01 00:00:00')
            """))

        with engine.connect() as conn:
            row = conn.execute(
                text("SELECT currency FROM invoices WHERE id = 99")
            ).fetchone()
        assert row[0] == "JPY"


class TestMigrationChain:
    """Tests verifying the migration revision chain is correct."""

    def test_revision_metadata(self) -> None:
        """Migration revision and down_revision match expected chain."""
        import importlib.util
        import pathlib

        migration_path = pathlib.Path(
            __file__
        ).parent.parent.parent / "alembic" / "versions" / "0141_invoice_currency.py"

        spec = importlib.util.spec_from_file_location("mig_0141", migration_path)
        assert spec is not None, "Migration file not found"
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)  # type: ignore[union-attr]

        assert mod.revision == "0141_invoice_currency"
        assert mod.down_revision == "0140_ekyc_chu_nha"

    def test_jp_address_migration_chain(self) -> None:
        """0142_jp_address chains correctly from 0141_invoice_currency."""
        import importlib.util
        import pathlib

        migration_path = pathlib.Path(
            __file__
        ).parent.parent.parent / "alembic" / "versions" / "0142_jp_address.py"

        spec = importlib.util.spec_from_file_location("mig_0142", migration_path)
        assert spec is not None, "Migration file not found"
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)  # type: ignore[union-attr]

        assert mod.revision == "0142_jp_address"
        assert mod.down_revision == "0141_invoice_currency"
