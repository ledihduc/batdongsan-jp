"""conftest — migration test fixtures.

Dùng SQLite in-memory DB thực (không phải FakeSession) để test alembic revisions.
Mỗi test nhận một DB sạch bắt đầu từ revision 0011_excl_reservation_overlap
(điểm bắt đầu trước khi chain 0012-0017 của Phase 04 được apply).

Pattern:
  1. Tạo DB thuần từ create_all (Base.metadata) — không chạy alembic để tránh
     phụ thuộc vào các revision 0001-0011 (planning schema + Postgres-only ops).
  2. Seed dữ liệu tối thiểu: users + contracts/reservations như mỗi test yêu cầu.
  3. Stamp DB tại 0011 để alembic coi 0012-0017 là pending.
  4. Chạy alembic upgrade đến revision cần test.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Generator

import pytest
import sqlalchemy as sa
from alembic import command as alembic_command
from alembic.config import Config as AlembicConfig
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker


# ── Helpers ─────────────────────────────────────────────────────────────────


def _make_alembic_cfg(db_url: str) -> AlembicConfig:
    """Tạo AlembicConfig trỏ vào test DB.

    env.py đọc DATABASE_URL từ os.environ (không phải sqlalchemy.url trong ini),
    nên phải override env var trước khi alembic command chạy.
    Caller chịu trách nhiệm set/restore os.environ["DATABASE_URL"].
    """
    backend_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    cfg = AlembicConfig(os.path.join(backend_root, "alembic.ini"))
    cfg.set_main_option("script_location", os.path.join(backend_root, "alembic"))
    cfg.set_main_option("sqlalchemy.url", db_url)
    # Override env var so env.py get_url() picks up the test DB URL
    os.environ["DATABASE_URL"] = db_url
    return cfg


def _seed_base_schema(engine: sa.engine.Engine) -> None:
    """Bootstrap schema tables cần thiết cho migration tests.

    Tạo minimal tables bằng raw DDL (không dùng alembic 0001-0011 vì chúng
    yêu cầu Postgres features như planning schema và gist extension).
    """
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY,
                name VARCHAR(300) NOT NULL,
                email VARCHAR(200) NOT NULL UNIQUE,
                password_hash VARCHAR(200) NOT NULL,
                phone VARCHAR(50) DEFAULT '',
                avatar_path VARCHAR(500),
                role VARCHAR(20) DEFAULT 'guest',
                is_active BOOLEAN DEFAULT 1,
                bio TEXT,
                created_at DATETIME,
                updated_at DATETIME
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS rooms (
                id INTEGER PRIMARY KEY,
                building_id INTEGER NOT NULL,
                code VARCHAR(20) NOT NULL,
                area_m2 FLOAT DEFAULT 0,
                capacity INTEGER DEFAULT 1,
                base_price FLOAT DEFAULT 0,
                status VARCHAR(20) DEFAULT 'vacant',
                images TEXT DEFAULT '[]',
                maintenance_start VARCHAR(20),
                maintenance_end VARCHAR(20),
                note TEXT,
                created_at DATETIME,
                updated_at DATETIME
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS reservations (
                id INTEGER PRIMARY KEY,
                host_id INTEGER NOT NULL REFERENCES users(id),
                room_id INTEGER NOT NULL,
                guest_user_id INTEGER,
                guest_name VARCHAR(300) NOT NULL,
                guest_phone VARCHAR(50) DEFAULT '',
                guest_email VARCHAR(200),
                check_in_date VARCHAR(20) NOT NULL,
                check_out_date VARCHAR(20) NOT NULL,
                nights INTEGER NOT NULL,
                total_amount FLOAT NOT NULL,
                deposit_paid FLOAT DEFAULT 0,
                status VARCHAR(20) DEFAULT 'pending',
                cancel_policy_snapshot TEXT DEFAULT '{}',
                cancelled_at DATETIME,
                refund_amount FLOAT,
                rejection_reason TEXT,
                source VARCHAR(20) DEFAULT 'manual',
                note TEXT,
                created_at DATETIME,
                updated_at DATETIME
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS contracts (
                id INTEGER PRIMARY KEY,
                host_id INTEGER NOT NULL REFERENCES users(id),
                room_id INTEGER NOT NULL,
                start_date VARCHAR(20) NOT NULL,
                end_date VARCHAR(20) NOT NULL,
                monthly_rent FLOAT NOT NULL,
                deposit FLOAT DEFAULT 0,
                status VARCHAR(20) DEFAULT 'draft',
                terminated_at VARCHAR(20),
                actual_end_date VARCHAR(20),
                deposit_refund_amount FLOAT,
                damage_note TEXT,
                damage_photos TEXT DEFAULT '[]',
                handover_photos TEXT DEFAULT '[]',
                created_at DATETIME,
                updated_at DATETIME,
                source VARCHAR(20) DEFAULT 'manual'
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS host_profiles (
                id INTEGER PRIMARY KEY,
                user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),
                verified BOOLEAN DEFAULT 0,
                cccd_front_path VARCHAR(500),
                cccd_back_path VARCHAR(500),
                cccd_number_hash VARCHAR(200),
                bank_account_number VARCHAR(50),
                bank_name VARCHAR(100),
                bank_account_holder VARCHAR(200),
                tax_id VARCHAR(50),
                avg_response_hours FLOAT,
                rating FLOAT,
                payout_schedule VARCHAR(20) DEFAULT 'monthly',
                created_at DATETIME,
                updated_at DATETIME
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS invoices (
                id INTEGER PRIMARY KEY,
                host_id INTEGER NOT NULL REFERENCES users(id),
                contract_id INTEGER NOT NULL,
                invoice_number VARCHAR(50) NOT NULL UNIQUE,
                period_start VARCHAR(20) NOT NULL,
                period_end VARCHAR(20) NOT NULL,
                issued_date VARCHAR(20) NOT NULL,
                due_date VARCHAR(20) NOT NULL,
                status VARCHAR(20) DEFAULT 'draft',
                total_amount FLOAT DEFAULT 0,
                paid_amount FLOAT DEFAULT 0,
                paid_at DATETIME,
                public_token VARCHAR(36) UNIQUE,
                public_token_expires_at DATETIME,
                note TEXT,
                created_at DATETIME,
                updated_at DATETIME
            )
        """))
        # alembic_version table (alembic stamp sẽ insert vào đây)
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS alembic_version (
                version_num VARCHAR(32) NOT NULL
            )
        """))


def _now() -> str:
    return datetime.now(timezone.utc).replace(tzinfo=None).isoformat()


def _insert_host(conn: sa.engine.Connection, host_id: int, name: str = "Test Host") -> None:
    conn.execute(text(
        "INSERT INTO users (id, name, email, password_hash, role, is_active, created_at, updated_at) "
        "VALUES (:id, :name, :email, 'hashed', 'host', 1, :now, :now)"
    ), {"id": host_id, "name": name, "email": f"host{host_id}@test.com", "now": _now()})


def _insert_reservation(
    conn: sa.engine.Connection,
    res_id: int,
    host_id: int,
    source: str = "manual",
) -> None:
    conn.execute(text(
        "INSERT INTO reservations "
        "(id, host_id, room_id, guest_name, guest_phone, check_in_date, check_out_date, "
        "nights, total_amount, source, created_at, updated_at) "
        "VALUES (:id, :host_id, 1, 'Guest', '0900000000', '2026-07-01', '2026-07-03', "
        "2, 500000, :source, :now, :now)"
    ), {"id": res_id, "host_id": host_id, "source": source, "now": _now()})


def _insert_contract(
    conn: sa.engine.Connection,
    con_id: int,
    host_id: int,
    source: str = "manual",
) -> None:
    conn.execute(text(
        "INSERT INTO contracts "
        "(id, host_id, room_id, start_date, end_date, monthly_rent, source, "
        "created_at, updated_at) "
        "VALUES (:id, :host_id, 1, '2026-07-01', '2027-06-30', 3000000, :source, :now, :now)"
    ), {"id": con_id, "host_id": host_id, "source": source, "now": _now()})


# ── Fixture: fresh SQLite DB stamped at 0011 ─────────────────────────────────


@pytest.fixture
def migration_db_url(tmp_path) -> Generator[str, None, None]:
    """Tạo SQLite DB thuần (file tmp) với schema tối thiểu, stamp tại 0011.

    Mỗi test nhận DB riêng biệt (tmp_path unique per test).
    Override DATABASE_URL env var để alembic env.py kết nối đúng test DB.
    Restore sau khi test hoàn thành.
    """
    db_path = tmp_path / "test_migration.db"
    url = f"sqlite:///{db_path}"

    # Lưu DATABASE_URL gốc (set bởi root conftest.py)
    original_db_url = os.environ.get("DATABASE_URL", "")

    try:
        # Override để alembic env.py dùng test DB
        os.environ["DATABASE_URL"] = url

        engine = create_engine(url, connect_args={"check_same_thread": False})
        _seed_base_schema(engine)
        engine.dispose()

        # Stamp tại 0011 để alembic biết bắt đầu từ đâu
        cfg = _make_alembic_cfg(url)
        alembic_command.stamp(cfg, "0011_excl_reservation_overlap")

        yield url
    finally:
        # Restore DATABASE_URL để không ảnh hưởng các test khác
        os.environ["DATABASE_URL"] = original_db_url


@pytest.fixture
def migration_engine(migration_db_url) -> Generator[sa.engine.Engine, None, None]:
    """SQLAlchemy engine cho migration_db_url."""
    engine = create_engine(
        migration_db_url, connect_args={"check_same_thread": False}
    )
    yield engine
    engine.dispose()
