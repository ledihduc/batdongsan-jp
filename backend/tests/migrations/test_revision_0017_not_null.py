"""test_revision_0017_not_null — kiểm tra migration 0017 enforce NOT NULL trên source_id.

Test cases:
  1. Nếu còn NULL source_id → RuntimeError (pre-check fails).
  2. Nếu tất cả rows đã có source_id → NOT NULL enforced thành công.
"""

from __future__ import annotations

import pytest
import sqlalchemy as sa
from alembic import command as alembic_command
from sqlalchemy import create_engine, text

from tests.migrations.conftest import (
    _insert_host,
    _insert_reservation,
    _make_alembic_cfg,
    _now,
)


def _upgrade_to_0016(db_url: str) -> None:
    """Apply 0012→0016 (pre-conditions cho 0017)."""
    cfg = _make_alembic_cfg(db_url)
    alembic_command.upgrade(cfg, "0016_add_monthly_revenue_goal")


@pytest.mark.skip(
    reason=(
        "0017 NOT NULL enforcement is currently a no-op (deferred until "
        "service layer dual-writes source_id). Re-enable when 0017 is "
        "swapped back from no-op to the ALTER COLUMN form."
    )
)
def test_not_null_raises_if_null_source_id_exists(migration_db_url: str) -> None:
    """RuntimeError khi còn reservation với source_id NULL trước khi enforce NOT NULL."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 500, "Host Not Null Test")
        _insert_reservation(conn, 50, host_id=500, source="manual")

    engine.dispose()

    # Apply đến 0016 (bao gồm 0012 seed + 0013 FK + 0014 backfill)
    _upgrade_to_0016(migration_db_url)

    # Sau 0014 backfill, source_id phải được set. Manually NULL một row để test 0017 check.
    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.begin() as conn:
        conn.execute(text("UPDATE reservations SET source_id = NULL WHERE id = 50"))
    engine2.dispose()

    # 0017 phải raise vì có NULL
    cfg = _make_alembic_cfg(migration_db_url)
    with pytest.raises(RuntimeError, match="Cannot enforce NOT NULL"):
        alembic_command.upgrade(cfg, "0017_source_id_not_null")


def test_not_null_succeeds_when_all_populated(migration_db_url: str) -> None:
    """NOT NULL enforced thành công khi tất cả source_id đã được backfill."""
    engine = create_engine(migration_db_url, connect_args={"check_same_thread": False})

    with engine.begin() as conn:
        _insert_host(conn, 600, "Host Clean Test")
        _insert_reservation(conn, 60, host_id=600, source="marketplace")
        _insert_reservation(conn, 61, host_id=600, source="direct")

    engine.dispose()

    cfg = _make_alembic_cfg(migration_db_url)
    # Upgrade đến head (0017) — không được raise
    alembic_command.upgrade(cfg, "0017_source_id_not_null")

    engine2 = create_engine(migration_db_url, connect_args={"check_same_thread": False})
    with engine2.connect() as conn:
        # Verify alembic_version = 0017
        version = conn.execute(
            text("SELECT version_num FROM alembic_version")
        ).scalar()
        assert version == "0017_source_id_not_null"

        # Verify không còn NULL
        null_count = conn.execute(
            text("SELECT COUNT(*) FROM reservations WHERE source_id IS NULL")
        ).scalar()
        assert null_count == 0

    engine2.dispose()
