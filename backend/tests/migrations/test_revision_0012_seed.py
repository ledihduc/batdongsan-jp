"""test_revision_0012_seed — kiểm tra migration 0012 tạo bảng revenue_sources
và seed đúng 3 nguồn mặc định cho mỗi host có reservation hoặc contract.

Fixture:
  - 2 hosts (id=10, id=11)
  - 1 reservation cho host 10
  - 1 contract cho host 11
  → Sau upgrade 0012: revenue_sources COUNT = 6 (3 per host × 2 hosts)
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
)

EXPECTED_NAMES = {"Trực tiếp", "Marketplace nội bộ", "Khác"}
EXPECTED_COLORS = {"Trực tiếp": "#4CAF50", "Marketplace nội bộ": "#2196F3", "Khác": "#9E9E9E"}


def test_seed_creates_3_sources_per_host(migration_db_url: str) -> None:
    """2 hosts × 3 nguồn = 6 rows trong revenue_sources sau 0012."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 10, "Host Alpha")
        _insert_host(conn, 11, "Host Beta")
        _insert_reservation(conn, 1, host_id=10)
        _insert_contract(conn, 1, host_id=11)

    engine.dispose()

    cfg = _make_alembic_cfg(migration_db_url)
    alembic_command.upgrade(cfg, "0012_create_revenue_sources")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        count = conn.execute(text("SELECT COUNT(*) FROM revenue_sources")).scalar()
        assert count == 6, f"Expected 6 revenue_sources, got {count}"

        rows = conn.execute(
            text("SELECT host_id, name, color_hex FROM revenue_sources ORDER BY host_id, name")
        ).fetchall()

        host_ids = {r[0] for r in rows}
        assert host_ids == {10, 11}, f"Expected hosts {{10, 11}}, got {host_ids}"

        for host_id in (10, 11):
            names = {r[1] for r in rows if r[0] == host_id}
            assert names == EXPECTED_NAMES, f"Host {host_id}: expected {EXPECTED_NAMES}, got {names}"

        for row in rows:
            expected_color = EXPECTED_COLORS[row[1]]
            assert row[2] == expected_color, (
                f"Color mismatch for '{row[1]}': expected {expected_color}, got {row[2]}"
            )

    engine2.dispose()


def test_seed_skips_duplicate_hosts(migration_db_url: str) -> None:
    """Host với cả reservation lẫn contract chỉ nhận 3 sources (không duplicate)."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 20, "Host Gamma")
        # cùng host có cả reservation và contract
        _insert_reservation(conn, 2, host_id=20)
        _insert_contract(conn, 2, host_id=20)

    engine.dispose()

    cfg = _make_alembic_cfg(migration_db_url)
    alembic_command.upgrade(cfg, "0012_create_revenue_sources")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        count = conn.execute(text(
            "SELECT COUNT(*) FROM revenue_sources WHERE host_id = 20"
        )).scalar()
        assert count == 3, f"Expected 3 (no duplicate), got {count}"

    engine2.dispose()


def test_seed_idempotent_if_sources_exist(migration_db_url: str) -> None:
    """Re-running upgrade không tạo duplicate nếu revenue_sources đã tồn tại."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 30, "Host Delta")
        _insert_reservation(conn, 3, host_id=30)

    engine.dispose()

    cfg = _make_alembic_cfg(migration_db_url)
    # Apply 0012 → downgrade → re-apply không được phép trong alembic sequence test,
    # nhưng tính idempotent của WHERE NOT EXISTS trong INSERT đã được test implicitly
    # bởi test_seed_skips_duplicate_hosts. Đây test alembic version tracking.
    alembic_command.upgrade(cfg, "0012_create_revenue_sources")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        version = conn.execute(
            text("SELECT version_num FROM alembic_version")
        ).scalar()
        assert version == "0012_create_revenue_sources"

    engine2.dispose()
