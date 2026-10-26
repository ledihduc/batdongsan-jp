"""test_revision_0018_not_null_v2 — migration 0018 enforce NOT NULL trên source_id.

Bối cảnh: 0017 ban đầu định làm NOT NULL nhưng phải defer (no-op) vì service
layer chưa dual-write. Sau khi reservation_service / contract_service /
marketplace_sync_service đã dual-write source_id, 0018 thực thi enforce.

Test cases:
  1. Happy path: chain 0012→0018 chạy sạch trên data hợp lệ.
  2. Failure path: row có source_id NULL + source không khớp seed → RuntimeError.
"""

from __future__ import annotations

import pytest
from alembic import command as alembic_command
from sqlalchemy import create_engine, text

from tests.migrations.conftest import (
    _insert_contract,
    _insert_host,
    _insert_reservation,
    _make_alembic_cfg,
    _now,
)


def test_chain_to_0018_enforces_not_null(migration_db_url: str) -> None:
    """Apply 0012→0018 trên reservations/contracts hợp lệ → NOT NULL active."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 900, "Host 0018 Happy")
        _insert_reservation(conn, 90, host_id=900, source="marketplace")
        _insert_reservation(conn, 91, host_id=900, source="direct")
        _insert_contract(conn, 90, host_id=900, source="manual")

    engine.dispose()

    cfg = _make_alembic_cfg(migration_db_url)
    alembic_command.upgrade(cfg, "0018_source_id_not_null_v2")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        version = conn.execute(
            text("SELECT version_num FROM alembic_version")
        ).scalar()
        assert version == "0018_source_id_not_null_v2"

        # 0 NULL rows
        null_res = conn.execute(
            text("SELECT COUNT(*) FROM reservations WHERE source_id IS NULL")
        ).scalar()
        assert null_res == 0

        null_con = conn.execute(
            text("SELECT COUNT(*) FROM contracts WHERE source_id IS NULL")
        ).scalar()
        assert null_con == 0

        # NOT NULL enforced: INSERT thiếu source_id phải fail.
        # (Dùng raw SQL — ORM model đã nullable=False nhưng test này
        # check schema-level constraint trực tiếp.)
        with pytest.raises(Exception):  # IntegrityError concrete class khác giữa drivers
            conn.execute(text(
                "INSERT INTO reservations "
                "(id, host_id, room_id, guest_name, guest_phone, check_in_date, "
                "check_out_date, nights, total_amount, source, created_at, updated_at) "
                "VALUES (999, 900, 1, 'X', '0', '2026-07-01', '2026-07-02', 1, 500000, "
                "'manual', :now, :now)"
            ), {"now": _now()})

    engine2.dispose()


def test_0018_raises_runtime_error_when_orphan_null_remains(migration_db_url: str) -> None:
    """Row có source_id NULL + source không backfill được → 0018 RuntimeError.

    Setup: apply chain đến 0017 (no-op), insert orphan row với source value
    không có trong seed (host không có RevenueSource cho source đó), upgrade
    0017→0018 → 0018 re-backfill không match → vẫn NULL → pre-check raise.
    """
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 901, "Host 0018 Orphan")
        _insert_reservation(conn, 92, host_id=901, source="manual")

    engine.dispose()

    # Apply đến 0017 (vẫn nullable + no-op enforce).
    cfg = _make_alembic_cfg(migration_db_url)
    alembic_command.upgrade(cfg, "0017_source_id_not_null")

    # Manually xoá source_id của row vừa được 0014 backfill VÀ xoá luôn
    # revenue_sources rows của host 901 → re-backfill không match.
    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.begin() as conn:
        conn.execute(text("UPDATE reservations SET source_id = NULL WHERE id = 92"))
        conn.execute(text("DELETE FROM revenue_sources WHERE host_id = 901"))
    engine2.dispose()

    # Upgrade 0017 → 0018 phải raise RuntimeError vì re-backfill không match.
    cfg = _make_alembic_cfg(migration_db_url)
    with pytest.raises(RuntimeError, match="Cannot enforce NOT NULL"):
        alembic_command.upgrade(cfg, "0018_source_id_not_null_v2")
