"""test_revision_0014_backfill — kiểm tra data migration 0014 backfill source_id
từ string enum sang FK.

Test cases:
  1. Happy path: 3 reservations với source marketplace/direct/manual → source_id populated.
  2. Unknown source value → fallback 'Khác' (ELSE branch trong CASE).
  3. RuntimeError nếu còn NULL sau backfill (chỉ xảy ra khi host_id không có
     matching revenue_source — edge case: reservation với host không có sources).
"""

from __future__ import annotations

import pytest
import sqlalchemy as sa
from alembic import command as alembic_command
from sqlalchemy import create_engine, text

from tests.migrations.conftest import (
    _insert_contract,
    _insert_host,
    _insert_reservation,
    _make_alembic_cfg,
    _now,
)


def _upgrade_to_0013(db_url: str) -> None:
    """Apply migrations 0012 + 0013 (pre-conditions cho 0014)."""
    cfg = _make_alembic_cfg(db_url)
    alembic_command.upgrade(cfg, "0013_add_source_id_fk_nullable")


def test_backfill_maps_all_enum_values(migration_db_url: str) -> None:
    """3 reservations với source marketplace/direct/manual → source_id đúng mapping."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 100, "Host Backfill Test")
        _insert_reservation(conn, 10, host_id=100, source="marketplace")
        _insert_reservation(conn, 11, host_id=100, source="direct")
        _insert_reservation(conn, 12, host_id=100, source="manual")

    engine.dispose()

    _upgrade_to_0013(migration_db_url)

    cfg = _make_alembic_cfg(migration_db_url)
    alembic_command.upgrade(cfg, "0014_backfill_source_id")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        # Không còn NULL
        null_count = conn.execute(
            text("SELECT COUNT(*) FROM reservations WHERE source_id IS NULL")
        ).scalar()
        assert null_count == 0, f"Expected 0 NULL source_id, got {null_count}"

        # Kiểm tra mapping: marketplace → 'Marketplace nội bộ'
        row = conn.execute(text(
            "SELECT rs.name FROM reservations r "
            "JOIN revenue_sources rs ON r.source_id = rs.id "
            "WHERE r.id = 10"
        )).fetchone()
        assert row is not None and row[0] == "Marketplace nội bộ", f"marketplace → {row}"

        # direct → 'Trực tiếp'
        row = conn.execute(text(
            "SELECT rs.name FROM reservations r "
            "JOIN revenue_sources rs ON r.source_id = rs.id "
            "WHERE r.id = 11"
        )).fetchone()
        assert row is not None and row[0] == "Trực tiếp", f"direct → {row}"

        # manual → 'Khác'
        row = conn.execute(text(
            "SELECT rs.name FROM reservations r "
            "JOIN revenue_sources rs ON r.source_id = rs.id "
            "WHERE r.id = 12"
        )).fetchone()
        assert row is not None and row[0] == "Khác", f"manual → {row}"

    engine2.dispose()


def test_backfill_unknown_source_falls_back_to_khac(migration_db_url: str) -> None:
    """Source value không trong enum (e.g. 'unknown') → map về 'Khác' (ELSE branch)."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 200, "Host Unknown Source")
        _insert_reservation(conn, 20, host_id=200, source="some_unknown_value")

    engine.dispose()

    _upgrade_to_0013(migration_db_url)

    cfg = _make_alembic_cfg(migration_db_url)
    alembic_command.upgrade(cfg, "0014_backfill_source_id")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        row = conn.execute(text(
            "SELECT rs.name FROM reservations r "
            "JOIN revenue_sources rs ON r.source_id = rs.id "
            "WHERE r.id = 20"
        )).fetchone()
        assert row is not None and row[0] == "Khác", (
            f"Unknown source should fall back to 'Khác', got: {row}"
        )

    engine2.dispose()


def test_backfill_contracts_mapped_correctly(migration_db_url: str) -> None:
    """Contracts cũng được backfill đúng theo cùng mapping."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 300, "Host Contract Test")
        _insert_contract(conn, 30, host_id=300, source="marketplace")
        _insert_contract(conn, 31, host_id=300, source="direct")

    engine.dispose()

    _upgrade_to_0013(migration_db_url)

    cfg = _make_alembic_cfg(migration_db_url)
    alembic_command.upgrade(cfg, "0014_backfill_source_id")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        null_count = conn.execute(
            text("SELECT COUNT(*) FROM contracts WHERE source_id IS NULL")
        ).scalar()
        assert null_count == 0

        row = conn.execute(text(
            "SELECT rs.name FROM contracts c "
            "JOIN revenue_sources rs ON c.source_id = rs.id "
            "WHERE c.id = 30"
        )).fetchone()
        assert row is not None and row[0] == "Marketplace nội bộ"

    engine2.dispose()


def test_backfill_raises_if_no_matching_source(migration_db_url: str) -> None:
    """RuntimeError nếu reservation có host_id không có revenue_sources.

    Mô phỏng: host có reservation, migration 0012+0013 đã chạy, nhưng sau đó
    revenue_sources cho host đó bị xóa thủ công (hoặc host mới được insert
    với reservation trực tiếp sau khi 0012 đã chạy xong → seed bị bỏ qua).

    Kịch bản: insert reservation SAU khi 0012 đã seed, xóa revenue_sources của
    host đó, rồi chạy 0014 → phải raise.
    """
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 400, "Host No Sources Later")
        _insert_reservation(conn, 40, host_id=400, source="manual")

    engine.dispose()

    # Apply 0012 (seeds sources cho host 400) + 0013 (add nullable FK)
    _upgrade_to_0013(migration_db_url)

    # Mô phỏng tình huống sources bị mất SAU khi seed (e.g. orphan cleanup, bad script)
    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.begin() as conn:
        conn.execute(sa.text("DELETE FROM revenue_sources WHERE host_id = 400"))
        # Verify delete worked
        cnt = conn.execute(
            sa.text("SELECT COUNT(*) FROM revenue_sources WHERE host_id = 400")
        ).scalar()
        assert cnt == 0
    engine2.dispose()

    # Bây giờ 0014 phải raise vì không có revenue_sources cho host 400
    cfg = _make_alembic_cfg(migration_db_url)
    with pytest.raises(RuntimeError, match="Data migration failed"):
        alembic_command.upgrade(cfg, "0014_backfill_source_id")
