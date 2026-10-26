"""test_full_chain — apply migration chain 0012→0017 trên DB sạch.

Post-flight assertions:
  - Zero NULL source_id trên reservations + contracts.
  - commission columns nullable (NULL cho data cũ).
  - monthly_revenue_goal nullable (NULL cho data cũ).
  - revenue_sources: 3 rows per host (chỉ hosts có reservations/contracts).
  - alembic_version = '0017_source_id_not_null'.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import command as alembic_command
from sqlalchemy import create_engine, text

from tests.migrations.conftest import (
    _insert_contract,
    _insert_host,
    _insert_reservation,
    _make_alembic_cfg,
)


def test_full_chain_0012_to_0017(migration_db_url: str) -> None:
    """Chạy toàn bộ chain 0012-0017, assert post-flight queries."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        # 3 hosts với nhiều loại source khác nhau
        _insert_host(conn, 700, "Host Full Chain 1")
        _insert_host(conn, 701, "Host Full Chain 2")
        _insert_reservation(conn, 70, host_id=700, source="marketplace")
        _insert_reservation(conn, 71, host_id=700, source="direct")
        _insert_reservation(conn, 72, host_id=700, source="manual")
        _insert_contract(conn, 70, host_id=701, source="marketplace")
        _insert_contract(conn, 71, host_id=701, source="manual")

    engine.dispose()

    # Apply full chain
    cfg = _make_alembic_cfg(migration_db_url)
    alembic_command.upgrade(cfg, "0017_source_id_not_null")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        # 1. alembic version
        version = conn.execute(
            text("SELECT version_num FROM alembic_version")
        ).scalar()
        assert version == "0017_source_id_not_null", f"Got version: {version}"

        # 2. Zero NULL source_id
        null_res = conn.execute(
            text("SELECT COUNT(*) FROM reservations WHERE source_id IS NULL")
        ).scalar()
        assert null_res == 0, f"reservations NULL source_id: {null_res}"

        null_con = conn.execute(
            text("SELECT COUNT(*) FROM contracts WHERE source_id IS NULL")
        ).scalar()
        assert null_con == 0, f"contracts NULL source_id: {null_con}"

        # 3. revenue_sources: 3 per host × 2 hosts = 6
        rs_count = conn.execute(
            text("SELECT COUNT(*) FROM revenue_sources")
        ).scalar()
        assert rs_count == 6, f"Expected 6 revenue_sources, got {rs_count}"

        # 4. commission columns nullable (all NULL for new rows without commission)
        non_null_commission = conn.execute(
            text("SELECT COUNT(*) FROM reservations WHERE commission_rate IS NOT NULL")
        ).scalar()
        assert non_null_commission == 0, "Legacy rows should have NULL commission"

        # 5. monthly_revenue_goal column exists (nullable)
        hp_rows = conn.execute(
            text("SELECT monthly_revenue_goal FROM host_profiles LIMIT 1")
        ).fetchall()
        # Column exists even if no host_profiles rows exist (DDL test)
        # If no rows: query executes without error = column exists
        # (fetchall returns empty list, not error)
        assert hp_rows is not None  # Column exists if no exception raised

        # 6. commission columns on invoices nullable
        inv_null = conn.execute(
            text("SELECT COUNT(*) FROM invoices WHERE commission_amount IS NOT NULL")
        ).scalar()
        assert inv_null == 0, "Legacy invoices should have NULL commission"

        # 7. FK integrity: all source_ids point to valid revenue_sources
        orphan_res = conn.execute(text(
            "SELECT COUNT(*) FROM reservations r "
            "LEFT JOIN revenue_sources rs ON r.source_id = rs.id "
            "WHERE r.source_id IS NOT NULL AND rs.id IS NULL"
        )).scalar()
        assert orphan_res == 0, f"Orphan reservations.source_id: {orphan_res}"

    engine2.dispose()


def test_full_chain_downgrade_0017_to_0016(migration_db_url: str) -> None:
    """Downgrade từ 0017 về 0016 phải cho phép NULL source_id lại."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 800, "Host Downgrade Test")
        _insert_reservation(conn, 80, host_id=800, source="direct")

    engine.dispose()

    cfg = _make_alembic_cfg(migration_db_url)
    alembic_command.upgrade(cfg, "0017_source_id_not_null")

    # Downgrade một bước: 0017 → 0016
    alembic_command.downgrade(cfg, "0016_add_monthly_revenue_goal")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        version = conn.execute(
            text("SELECT version_num FROM alembic_version")
        ).scalar()
        assert version == "0016_add_monthly_revenue_goal"

        # Downgrade 0017 → nullable lại; có thể set NULL
        conn.execute(text("UPDATE reservations SET source_id = NULL WHERE id = 80"))
        null_count = conn.execute(
            text("SELECT COUNT(*) FROM reservations WHERE source_id IS NULL")
        ).scalar()
        assert null_count == 1, "After downgrade 0017, source_id should be nullable"

    engine2.dispose()
