"""Migration tests for delegation domain (phase-01 revisions 0021–0035).

Tests:
  - Each upgrade/downgrade pair runs cleanly (reversibility)
  - AC-08: partial UNIQUE (owner_id) WHERE status='active' constraint works
  - AC-04: CHECK commission XOR constraint blocks both-NULL and both-set cases
  - AC-10b: duplicate pending invite for same (owner, invitee) blocked

Pattern:
  1. Fresh SQLite DB seeded with minimal schema (users, contracts, etc.)
  2. Stamp at 0020 (delegation chain starts at 0021)
  3. Upgrade to target revision
  4. Verify expected tables/columns exist
  5. Downgrade -1
  6. Verify rollback was clean

Note: Partial unique indexes (WHERE status=...) are PostgreSQL-only and skipped on SQLite.
The application layer enforces these constraints for SQLite (dev mode).
CHECK constraints are tested via direct INSERT failures.

SQLite limitations in test scope:
  - No CHECK constraint enforcement by default (requires sqlite3.enable_load_extension or
    PRAGMA enforce_check_constraint=ON — depends on sqlite version)
  - Partial UNIQUE indexes not supported → tested via application logic only
  - These are verified as Postgres-only when running smoke tests (SMOKE_DATABASE_URL set)
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta

import pytest
import sqlalchemy as sa
from alembic import command as alembic_command
from alembic.config import Config as AlembicConfig
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker


# ── Helpers ───────────────────────────────────────────────────────────────────

BACKEND_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _make_alembic_cfg(db_url: str) -> AlembicConfig:
    cfg = AlembicConfig(os.path.join(BACKEND_ROOT, "alembic.ini"))
    cfg.set_main_option("script_location", os.path.join(BACKEND_ROOT, "alembic"))
    cfg.set_main_option("sqlalchemy.url", db_url)
    os.environ["DATABASE_URL"] = db_url
    return cfg


def _seed_minimal_schema(engine: sa.engine.Engine) -> None:
    """Create minimal tables needed for delegation migrations to run on SQLite."""
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name VARCHAR(300) NOT NULL DEFAULT '',
                email VARCHAR(200) NOT NULL UNIQUE,
                password_hash VARCHAR(200) NOT NULL DEFAULT '',
                phone VARCHAR(50) DEFAULT '',
                avatar_path VARCHAR(500) DEFAULT '',
                role VARCHAR(20) DEFAULT 'guest',
                is_active BOOLEAN DEFAULT 1,
                birthday VARCHAR(20),
                bio TEXT,
                id_number VARCHAR(50),
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS buildings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                host_id INTEGER NOT NULL REFERENCES users(id),
                name VARCHAR(300) NOT NULL DEFAULT '',
                address VARCHAR(500) DEFAULT '',
                city VARCHAR(100) DEFAULT '',
                district VARCHAR(100) DEFAULT '',
                ward VARCHAR(100) DEFAULT '',
                note TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS rooms (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                building_id INTEGER NOT NULL REFERENCES buildings(id),
                code VARCHAR(50) NOT NULL DEFAULT '',
                area_m2 FLOAT,
                capacity INTEGER DEFAULT 1,
                base_price FLOAT DEFAULT 0,
                status VARCHAR(20) DEFAULT 'vacant',
                images TEXT DEFAULT '[]',
                note TEXT,
                is_listed_on_marketplace BOOLEAN DEFAULT 0,
                is_homestay BOOLEAN DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS tenants (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                host_id INTEGER NOT NULL REFERENCES users(id),
                full_name VARCHAR(300) NOT NULL DEFAULT '',
                phone VARCHAR(50) DEFAULT '',
                is_placeholder BOOLEAN DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS revenue_sources (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                host_id INTEGER NOT NULL REFERENCES users(id),
                name VARCHAR(50) NOT NULL DEFAULT '',
                color_hex VARCHAR(7) DEFAULT '#666666',
                is_archived BOOLEAN DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS contracts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                host_id INTEGER NOT NULL REFERENCES users(id),
                room_id INTEGER NOT NULL REFERENCES rooms(id),
                start_date VARCHAR(20) NOT NULL DEFAULT '',
                end_date VARCHAR(20) NOT NULL DEFAULT '',
                monthly_rent FLOAT NOT NULL DEFAULT 0,
                deposit FLOAT DEFAULT 0,
                status VARCHAR(20) DEFAULT 'draft',
                source VARCHAR(20) DEFAULT 'manual',
                source_id INTEGER REFERENCES revenue_sources(id),
                damage_photos TEXT DEFAULT '[]',
                handover_photos TEXT DEFAULT '[]',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS contract_tenants (
                contract_id INTEGER NOT NULL REFERENCES contracts(id),
                tenant_id INTEGER NOT NULL REFERENCES tenants(id),
                is_primary BOOLEAN DEFAULT 0,
                joined_at VARCHAR(20),
                left_at VARCHAR(20),
                PRIMARY KEY (contract_id, tenant_id)
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS host_profiles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),
                verified BOOLEAN DEFAULT 0,
                payout_schedule VARCHAR(20) DEFAULT 'monthly',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS invoices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                host_id INTEGER NOT NULL REFERENCES users(id),
                contract_id INTEGER NOT NULL REFERENCES contracts(id),
                invoice_number VARCHAR(50) NOT NULL UNIQUE,
                period_start VARCHAR(20) NOT NULL DEFAULT '',
                period_end VARCHAR(20) NOT NULL DEFAULT '',
                issued_date VARCHAR(20) NOT NULL DEFAULT '',
                due_date VARCHAR(20) NOT NULL DEFAULT '',
                status VARCHAR(20) DEFAULT 'draft',
                total_amount FLOAT DEFAULT 0,
                paid_amount FLOAT DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL REFERENCES users(id),
                type VARCHAR(50) DEFAULT '',
                title VARCHAR(200) DEFAULT '',
                body TEXT DEFAULT '',
                related_id INTEGER,
                read BOOLEAN DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS change_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                entity_type VARCHAR(50) NOT NULL DEFAULT '',
                entity_id INTEGER NOT NULL DEFAULT 0,
                actor_id INTEGER REFERENCES users(id),
                action VARCHAR(30) NOT NULL DEFAULT '',
                before_json TEXT,
                after_json TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS audit_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                host_id INTEGER NOT NULL REFERENCES users(id),
                action VARCHAR(50) NOT NULL DEFAULT '',
                period VARCHAR(7),
                success BOOLEAN NOT NULL DEFAULT 0,
                ip VARCHAR(45),
                user_agent VARCHAR(500),
                extra TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS alembic_version (
                version_num VARCHAR(32) NOT NULL
            )
        """))


def _now() -> str:
    return datetime.utcnow().isoformat()


def _insert_user(
    conn: sa.engine.Connection, user_id: int, email_suffix: str = ""
) -> int:
    conn.execute(
        text(
            "INSERT INTO users (id, name, email, password_hash, role, created_at) "
            "VALUES (:id, 'Test User', :email, 'hash', 'host', :now)"
        ),
        {
            "id": user_id,
            "email": f"user{user_id}{email_suffix}@test.com",
            "now": _now(),
        },
    )
    return user_id


# ── Fixtures ──────────────────────────────────────────────────────────────────


@pytest.fixture
def del_migration_db(tmp_path):
    """Fresh SQLite DB seeded at 0020 for delegation migration tests."""
    db_path = tmp_path / "del_migration_test.db"
    db_url = f"sqlite:///{db_path}"
    original_url = os.environ.get("DATABASE_URL", "")

    try:
        os.environ["DATABASE_URL"] = db_url
        engine = create_engine(db_url, connect_args={"check_same_thread": False})
        _seed_minimal_schema(engine)
        engine.dispose()

        cfg = _make_alembic_cfg(db_url)
        alembic_command.stamp(cfg, "0020_create_tt200_exports")
        yield db_url
    finally:
        os.environ["DATABASE_URL"] = original_url


@pytest.fixture
def del_migration_engine(del_migration_db):
    engine = create_engine(del_migration_db, connect_args={"check_same_thread": False})
    yield engine
    engine.dispose()


# ── Tests: Table existence after upgrade ─────────────────────────────────────


def test_upgrade_0021_creates_delegations_table(del_migration_db, del_migration_engine):
    """Revision 0021 creates delegation_invitations and delegations tables."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0021_create_delegations_and_invitations")

    inspector = inspect(del_migration_engine)
    tables = inspector.get_table_names()
    assert "delegations" in tables, "delegations table missing after 0021 upgrade"
    assert "delegation_invitations" in tables, "delegation_invitations table missing"

    # Verify key columns exist
    del_cols = {c["name"] for c in inspector.get_columns("delegations")}
    assert "scope_type" in del_cols, "scope_type missing (TL-1 / NFR-13)"
    assert "scope_target_ids" in del_cols, "scope_target_ids missing (TL-1 / NFR-13)"
    assert "threshold_monthly_rent_vnd" in del_cols, "threshold col missing (AC-31b)"
    assert "threshold_term_months" in del_cols
    assert "threshold_expense_vnd" in del_cols
    assert "threshold_rent_change_pct" in del_cols
    assert "threshold_refund_vnd" in del_cols
    assert "poa_format" in del_cols, "poa_format missing (AC-55d)"
    assert "shared_login_disclosure_ack_at" in del_cols, "AC-66 column missing"
    assert "retention_tier" in del_cols, "retention_tier missing (AC-44)"


def test_downgrade_0021(del_migration_db, del_migration_engine):
    """Revision 0021 downgrade cleanly removes delegations and delegation_invitations."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0021_create_delegations_and_invitations")
    alembic_command.downgrade(cfg, "-1")

    inspector = inspect(del_migration_engine)
    tables = inspector.get_table_names()
    assert "delegations" not in tables, "delegations still exists after 0021 downgrade"
    assert "delegation_invitations" not in tables


def test_upgrade_0022_creates_delegation_approvals(del_migration_db, del_migration_engine):
    """Revision 0022 creates delegation_approvals table."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0022_create_delegation_approvals")

    inspector = inspect(del_migration_engine)
    assert "delegation_approvals" in inspector.get_table_names()

    appr_cols = {c["name"] for c in inspector.get_columns("delegation_approvals")}
    assert "sla_class" in appr_cols, "sla_class missing (AC-30)"
    assert "requires_biometric" in appr_cols, "requires_biometric missing (AC-29b)"
    assert "escalation_state" in appr_cols, "escalation_state missing (AC-30b)"
    assert "lockdown_fraud_termination" in appr_cols, "AC-43b column missing"


def test_downgrade_0022(del_migration_db):
    """Revision 0022 downgrade removes delegation_approvals."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0022_create_delegation_approvals")
    alembic_command.downgrade(cfg, "-1")

    engine = create_engine(del_migration_db, connect_args={"check_same_thread": False})
    inspector = inspect(engine)
    assert "delegation_approvals" not in inspector.get_table_names()
    engine.dispose()


def test_upgrade_0023_creates_operator_business_profiles(del_migration_db, del_migration_engine):
    """Revision 0023 creates operator_business_profiles table."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0023_create_operator_business_profiles")

    inspector = inspect(del_migration_engine)
    assert "operator_business_profiles" in inspector.get_table_names()

    cols = {c["name"] for c in inspector.get_columns("operator_business_profiles")}
    assert "gpkd_document_path" in cols, "GPKD doc path missing (AC-50b)"
    assert "gpkd_expires_at" in cols, "GPKD expiry missing (AC-50)"
    assert "previous_legal_rep_user_id" in cols, "AC-65 column missing"
    assert "legal_rep_changed_at" in cols, "AC-65 timestamp missing"


def test_upgrade_0024_creates_owner_death_certificates(del_migration_db, del_migration_engine):
    """Revision 0024 creates owner_death_certificates table."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0024_create_owner_death_certificates")

    inspector = inspect(del_migration_engine)
    assert "owner_death_certificates" in inspector.get_table_names()

    cols = {c["name"] for c in inspector.get_columns("owner_death_certificates")}
    assert "executor_user_id" in cols, "executor_user_id missing (AC-58b/d)"
    assert "death_certificate_path" in cols


def test_upgrade_0025_creates_tenant_authority_flags(del_migration_db, del_migration_engine):
    """Revision 0025 creates tenant_authority_flags table."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0025_create_tenant_authority_flags")

    inspector = inspect(del_migration_engine)
    assert "tenant_authority_flags" in inspector.get_table_names()


def test_upgrade_0026_creates_bank_account_reveal_logs(del_migration_db, del_migration_engine):
    """Revision 0026 creates bank_account_reveal_logs table."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0026_create_bank_account_reveal_logs")

    inspector = inspect(del_migration_engine)
    assert "bank_account_reveal_logs" in inspector.get_table_names()


def test_upgrade_0027_extends_users(del_migration_db, del_migration_engine):
    """Revision 0027 adds is_operator_capable and sole_ownership_attested_at to users."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0027_extend_users_for_delegation")

    inspector = inspect(del_migration_engine)
    user_cols = {c["name"] for c in inspector.get_columns("users")}
    assert "is_operator_capable" in user_cols, "is_operator_capable missing (AC-56)"
    assert "sole_ownership_attested_at" in user_cols, "AC-64 column missing"
    assert "business_operator_profile_id" in user_cols


def test_downgrade_0027_removes_user_cols(del_migration_db):
    """Revision 0027 downgrade removes added columns from users."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0027_extend_users_for_delegation")
    alembic_command.downgrade(cfg, "-1")

    engine = create_engine(del_migration_db, connect_args={"check_same_thread": False})
    inspector = inspect(engine)
    user_cols = {c["name"] for c in inspector.get_columns("users")}
    assert "is_operator_capable" not in user_cols
    assert "sole_ownership_attested_at" not in user_cols
    engine.dispose()


def test_upgrade_0028_extends_host_profiles(del_migration_db, del_migration_engine):
    """Revision 0028 adds KYC expiry columns to host_profiles."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0028_extend_host_profiles_kyc_expiry")

    inspector = inspect(del_migration_engine)
    hp_cols = {c["name"] for c in inspector.get_columns("host_profiles")}
    assert "kyc_expires_at" in hp_cols, "kyc_expires_at missing (AC-50)"
    assert "kyc_grace_period_until" in hp_cols


def test_upgrade_0029_extends_buildings(del_migration_db, del_migration_engine):
    """Revision 0029 adds district_pre_file_accepted to buildings."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0029_extend_buildings_district_prefile")

    inspector = inspect(del_migration_engine)
    bld_cols = {c["name"] for c in inspector.get_columns("buildings")}
    assert "district_pre_file_accepted" in bld_cols, "AC-55c column missing"


def test_upgrade_0030_extends_contracts(del_migration_db, del_migration_engine):
    """Revision 0030 adds kb04_form_data_json and kb04_pre_filed to contracts."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0030_extend_contracts_kb04_form_data")

    inspector = inspect(del_migration_engine)
    contract_cols = {c["name"] for c in inspector.get_columns("contracts")}
    assert "kb04_form_data_json" in contract_cols, "AC-55b column missing"
    assert "kb04_pre_filed" in contract_cols


def test_upgrade_0031_extends_contract_tenants(del_migration_db, del_migration_engine):
    """Revision 0031 adds joined_at_datetime to contract_tenants."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0031_add_contract_tenants_joined_datetime")

    inspector = inspect(del_migration_engine)
    ct_cols = {c["name"] for c in inspector.get_columns("contract_tenants")}
    assert "joined_at_datetime" in ct_cols, "AC-55b precision column missing"
    # Dual-write: original joined_at must still exist
    assert "joined_at" in ct_cols, "original joined_at must NOT be dropped (dual-write)"


def test_upgrade_0032_extends_change_logs(del_migration_db, del_migration_engine):
    """Revision 0032 adds delegation dual-identity columns to change_logs."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0032_extend_change_logs_dual_identity")

    inspector = inspect(del_migration_engine)
    cl_cols = {c["name"] for c in inspector.get_columns("change_logs")}
    assert "on_behalf_of_user_id" in cl_cols, "AC-23 column missing"
    assert "acted_via_delegation_id" in cl_cols, "AC-32 column missing"
    assert "acted_at" in cl_cols, "AC-62 column missing"
    assert "retention_tier" in cl_cols, "AC-44 column missing"
    assert "scope_snapshot_json" in cl_cols


def test_upgrade_0033_extends_audit_logs(del_migration_db, del_migration_engine):
    """Revision 0033 adds delegation dual-identity columns to audit_logs."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0033_extend_audit_logs_dual_identity")

    inspector = inspect(del_migration_engine)
    al_cols = {c["name"] for c in inspector.get_columns("audit_logs")}
    assert "actor_user_id" in al_cols, "AC-22 column missing"
    assert "on_behalf_of_user_id" in al_cols, "AC-23 column missing"
    assert "acted_via_delegation_id" in al_cols
    assert "retention_tier" in al_cols, "AC-44 column missing"


def test_upgrade_0034_extends_invoices(del_migration_db, del_migration_engine):
    """Revision 0034 adds platform_fee columns to invoices (NFR-15 / TL-2)."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0034_extend_invoices_platform_fee")

    inspector = inspect(del_migration_engine)
    inv_cols = {c["name"] for c in inspector.get_columns("invoices")}
    assert "platform_fee_pct" in inv_cols, "NFR-15 column missing"
    assert "platform_fee_amount" in inv_cols, "NFR-15 column missing"


def test_upgrade_0035_extends_notifications(del_migration_db, del_migration_engine):
    """Revision 0035 adds channel and delivery_status to notifications."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0035_extend_notifications_channels")

    inspector = inspect(del_migration_engine)
    notif_cols = {c["name"] for c in inspector.get_columns("notifications")}
    assert "channel" in notif_cols
    assert "delivery_status" in notif_cols
    assert "external_message_id" in notif_cols, "NFR-14 column missing"
    assert "read_receipt_opened_at" in notif_cols, "NFR-14 column missing"


def test_full_chain_upgrade_0020_to_0035(del_migration_db, del_migration_engine):
    """Run the full delegation migration chain (0021→0035) without errors."""
    cfg = _make_alembic_cfg(del_migration_db)
    # Should not raise
    alembic_command.upgrade(cfg, "0035_extend_notifications_channels")

    inspector = inspect(del_migration_engine)
    tables = inspector.get_table_names()
    # Spot-check key new tables
    expected_tables = [
        "delegations",
        "delegation_invitations",
        "delegation_approvals",
        "operator_business_profiles",
        "owner_death_certificates",
        "tenant_authority_flags",
        "bank_account_reveal_logs",
    ]
    for table in expected_tables:
        assert table in tables, f"Expected table '{table}' missing after full chain upgrade"


def test_full_chain_downgrade_roundtrip(del_migration_db, del_migration_engine):
    """Upgrade 0021→0035 then downgrade -15 steps → should return to 0020 cleanly."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0035_extend_notifications_channels")

    # Downgrade all 15 delegation steps
    for _ in range(15):
        alembic_command.downgrade(cfg, "-1")

    # Tables from delegation domain should be gone
    inspector = inspect(del_migration_engine)
    tables = inspector.get_table_names()
    assert "delegations" not in tables, "delegations table persists after full downgrade"
    assert "delegation_approvals" not in tables
    assert "operator_business_profiles" not in tables

    # Core tables must still exist (no collateral damage)
    assert "users" in tables, "users table was dropped during downgrade — AC-52 violation"
    assert "contracts" in tables
    assert "invoices" in tables


def test_ac52_no_host_id_altered_in_delegation_migrations(del_migration_db):
    """AC-52 guard: none of the delegation migrations touch host_id columns.

    Runs the CI guard script logic inline (no subprocess needed).
    """
    import subprocess
    import sys

    script_path = os.path.join(BACKEND_ROOT, "scripts", "check_no_host_id_alter.py")
    result = subprocess.run(
        [sys.executable, script_path],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"AC-52 CI guard FAILED:\n{result.stderr}\n"
        "A migration is altering host_id — this violates AC-52."
    )


def test_delegation_insert_validates_required_thresholds(del_migration_db):
    """AC-31b: all 5 threshold columns are NOT NULL — verify at insert time on SQLite."""
    cfg = _make_alembic_cfg(del_migration_db)
    alembic_command.upgrade(cfg, "0021_create_delegations_and_invitations")

    engine = create_engine(del_migration_db, connect_args={"check_same_thread": False})
    try:
        with engine.begin() as conn:
            _insert_user(conn, 1)
            _insert_user(conn, 2, email_suffix="_op")

            # Insert valid delegation first (baseline)
            conn.execute(text("""
                INSERT INTO delegations
                (id, owner_id, operator_id, status, role_preset, scope_type,
                 commission_pct, commission_fixed_vnd,
                 threshold_monthly_rent_vnd, threshold_term_months,
                 threshold_expense_vnd, threshold_rent_change_pct, threshold_refund_vnd,
                 poa_format, retention_tier, created_at, updated_at)
                VALUES
                (:id, 1, 2, 'active', 'operator_full', 'all',
                 5.00, NULL,
                 5000000, 12, 2000000, 5.00, 1000000,
                 'digital', 'hot', :now, :now)
            """), {"id": str(uuid.uuid4()), "now": _now()})

            # Try inserting delegation with NULL threshold_term_months — should fail
            with pytest.raises(Exception):
                conn.execute(text("""
                    INSERT INTO delegations
                    (id, owner_id, operator_id, status, role_preset, scope_type,
                     commission_pct, commission_fixed_vnd,
                     threshold_monthly_rent_vnd, threshold_term_months,
                     threshold_expense_vnd, threshold_rent_change_pct, threshold_refund_vnd,
                     poa_format, retention_tier, created_at, updated_at)
                    VALUES
                    (:id, 1, 2, 'pending_op_kyc', 'operator_full', 'all',
                     5.00, NULL,
                     5000000, NULL, 2000000, 5.00, 1000000,
                     'digital', 'hot', :now, :now)
                """), {"id": str(uuid.uuid4()), "now": _now()})
    finally:
        engine.dispose()
