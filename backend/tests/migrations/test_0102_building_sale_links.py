"""Exercise the migration itself, including pre-migration data and reruns."""

import importlib.util
import os
import uuid
from pathlib import Path

import pytest
import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy.exc import IntegrityError


@pytest.fixture
def migration_db():
    engine = sa.create_engine(os.getenv("BUILDING_LINK_MIGRATION_TEST_URL", "sqlite://"))
    with engine.connect() as db:
        transaction = db.begin()
        if db.dialect.name == "sqlite":
            db.exec_driver_sql("PRAGMA foreign_keys=ON")
        else:
            schema = "link_test_" + uuid.uuid4().hex
            db.exec_driver_sql(f"CREATE SCHEMA {schema}")
            db.exec_driver_sql(f"SET search_path TO {schema}")
        db.exec_driver_sql("CREATE TABLE users (id INTEGER PRIMARY KEY)")
        db.exec_driver_sql(
            "CREATE TABLE buildings (id INTEGER PRIMARY KEY, host_id INTEGER, sale_id INTEGER)"
        )
        db.exec_driver_sql(
            "CREATE TABLE rooms (id INTEGER PRIMARY KEY, building_id INTEGER, managed_by_sale_id INTEGER)"
        )
        db.exec_driver_sql(
            "CREATE TABLE sale_owner_links (id INTEGER PRIMARY KEY, owner_id INTEGER, sale_id INTEGER, status VARCHAR(20), linked_at TIMESTAMP, ended_at TIMESTAMP, created_by INTEGER REFERENCES users(id), end_reason VARCHAR(300))"
        )
        db.exec_driver_sql(
            "CREATE UNIQUE INDEX uq_sale_owner_links_owner_active ON sale_owner_links(owner_id) WHERE status = 'active'"
        )
        for uid in range(1, 10):
            db.execute(sa.text("INSERT INTO users VALUES (:id)"), {"id": uid})
        path = Path(__file__).parents[2] / "alembic/versions/0102_building_sale_links.py"
        spec = importlib.util.spec_from_file_location("migration_0102", path)
        migration = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(migration)
        with Operations.context(MigrationContext.configure(db)):
            try:
                yield db, migration
            finally:
                transaction.rollback()
    engine.dispose()


def test_backfill_is_unambiguous_and_idempotent(migration_db):
    db, migration = migration_db
    # Sole unassigned building; one matching out of two; two matching (ambiguous);
    # sole conflicting building; no building. Only first two links can be scoped.
    db.exec_driver_sql(
        "INSERT INTO buildings VALUES (10,1,NULL),(20,2,8),(21,2,9),(30,3,8),(31,3,8),(40,4,9)"
    )
    db.exec_driver_sql(
        "INSERT INTO rooms VALUES (1,10,9),(2,10,NULL),(3,20,9),(4,21,9),(5,30,8)"
    )
    db.exec_driver_sql(
        "INSERT INTO sale_owner_links (id,owner_id,sale_id,status) VALUES (1,1,8,'active'),(2,2,8,'active'),(3,3,8,'active'),(4,4,8,'active'),(5,5,8,'active'),(6,1,9,'ended')"
    )
    migration.upgrade()
    migration.upgrade()
    assert dict(db.exec_driver_sql("SELECT id,building_id FROM sale_owner_links").all()) == {
        1: 10,
        2: 20,
        3: None,
        4: None,
        5: None,
        6: None,
    }
    assert db.exec_driver_sql(
        "SELECT managed_by_sale_id FROM rooms ORDER BY id"
    ).scalars().all() == [8, 8, 8, 9, 8]
    assert db.exec_driver_sql("SELECT sale_id FROM buildings WHERE id=10").scalar() == 8
    indexes = {i["name"] for i in sa.inspect(db).get_indexes("sale_owner_links")}
    assert "uq_sale_owner_links_owner_active" not in indexes
    assert {"ix_sale_owner_links_building_id", "uq_sale_owner_links_building_active"} <= indexes
    fk = sa.inspect(db).get_foreign_keys("sale_owner_links")[0]
    assert fk["referred_table"] == "buildings" and fk["options"]["ondelete"] == "CASCADE"
    assert next(
        c for c in sa.inspect(db).get_columns("sale_owner_links") if c["name"] == "building_id"
    )["nullable"]


def test_unique_per_building_and_cascade(migration_db):
    db, migration = migration_db
    migration.upgrade()
    db.exec_driver_sql("INSERT INTO buildings VALUES (1,1,8),(2,1,9)")
    db.exec_driver_sql(
        "INSERT INTO sale_owner_links (id,owner_id,sale_id,status,building_id) VALUES (1,1,8,'active',1),(2,1,9,'active',2),(3,1,9,'ended',1),(4,1,9,'active',NULL)"
    )
    with pytest.raises(IntegrityError), db.begin_nested():
        db.exec_driver_sql(
            "INSERT INTO sale_owner_links (id,owner_id,sale_id,status,building_id) VALUES (5,2,9,'active',1)"
        )
    with pytest.raises(IntegrityError), db.begin_nested():
        db.exec_driver_sql(
            "INSERT INTO sale_owner_links (id,owner_id,sale_id,status,building_id) VALUES (6,2,9,'ended',999)"
        )
    db.exec_driver_sql("DELETE FROM buildings WHERE id=1")
    assert db.exec_driver_sql(
        "SELECT id FROM sale_owner_links ORDER BY id"
    ).scalars().all() == [
        2,
        4,
    ]


def test_partial_migration_does_not_overwrite_scoped_link(migration_db):
    db, migration = migration_db
    db.exec_driver_sql("ALTER TABLE sale_owner_links ADD COLUMN building_id INTEGER")
    db.exec_driver_sql("DROP INDEX uq_sale_owner_links_owner_active")
    db.exec_driver_sql("INSERT INTO buildings VALUES (1,1,8)")
    db.exec_driver_sql(
        "INSERT INTO sale_owner_links (id,owner_id,sale_id,status,building_id) VALUES (1,1,8,'active',NULL),(2,1,9,'active',1)"
    )
    migration.upgrade()
    assert (
        db.exec_driver_sql("SELECT building_id FROM sale_owner_links WHERE id=1").scalar()
        is None
    )
    assert (
        db.exec_driver_sql("SELECT sale_id FROM sale_owner_links WHERE building_id=1").scalar()
        == 9
    )


@pytest.mark.parametrize("populated", [False, True])
def test_downgrade_preserves_history_and_restores_owner_uniqueness(migration_db, populated):
    db, migration = migration_db
    assert migration.down_revision == "0101_hang_doi_push"
    migration.upgrade()
    if populated:
        db.exec_driver_sql("INSERT INTO buildings VALUES (10,1,8),(11,1,9),(20,2,8)")
        db.exec_driver_sql("INSERT INTO rooms VALUES (1,10,8),(2,11,9),(3,20,8)")
        # Out-of-order inserts and NULL building links exercise deterministic
        # reduction for every owner, including unresolved legacy history.
        db.exec_driver_sql(
            "INSERT INTO sale_owner_links (id,owner_id,sale_id,status,building_id,linked_at,ended_at,created_by,end_reason) VALUES "
            "(5,1,9,'active',11,'2026-08-01',NULL,1,NULL),"
            "(2,1,8,'active',10,'2026-09-01',NULL,1,NULL),"
            "(8,1,9,'active',NULL,'2026-09-02','2026-09-03',1,'Existing reason'),"
            "(1,1,9,'ended',10,'2026-07-01','2026-07-02',1,'Historical reason'),"
            "(7,2,8,'active',20,'2026-09-01',NULL,2,NULL),"
            "(9,2,9,'transfer_pending',NULL,'2026-09-01',NULL,2,NULL),"
            "(11,3,9,'active',NULL,'2026-09-01',NULL,3,NULL),"
            "(10,3,8,'active',NULL,'2026-09-01',NULL,3,NULL)"
        )
    before = {
        row.id: dict(row)
        for row in db.exec_driver_sql("SELECT * FROM sale_owner_links").mappings()
    }
    buildings = db.exec_driver_sql("SELECT * FROM buildings ORDER BY id").all()
    rooms = db.exec_driver_sql("SELECT * FROM rooms ORDER BY id").all()
    migration.downgrade()
    migration.downgrade()
    inspector = sa.inspect(db)
    assert "building_id" not in {c["name"] for c in inspector.get_columns("sale_owner_links")}
    indexes = {i["name"]: i for i in inspector.get_indexes("sale_owner_links")}
    assert indexes["uq_sale_owner_links_owner_active"]["unique"]
    assert "uq_sale_owner_links_building_active" not in indexes
    assert "ix_sale_owner_links_building_id" not in indexes
    fks = inspector.get_foreign_keys("sale_owner_links")
    assert all(fk["referred_table"] != "buildings" for fk in fks)
    assert any(fk["constrained_columns"] == ["created_by"] for fk in fks)
    after = {
        row.id: dict(row)
        for row in db.exec_driver_sql("SELECT * FROM sale_owner_links").mappings()
    }
    assert after.keys() == before.keys()
    for id, old in before.items():
        old.pop("building_id")
        if id in (5, 8, 11):
            assert after[id]["status"] == "ended"
            assert after[id]["ended_at"] is not None
            assert after[id]["end_reason"] == (
                old["end_reason"] or "Downgrade 0102: retained lowest-id active link per owner"
            )
            if old["ended_at"]:
                assert after[id]["ended_at"] == old["ended_at"]
            for field in ("status", "ended_at", "end_reason"):
                old.pop(field)
            assert all(after[id][field] == value for field, value in old.items())
        else:
            assert after[id] == old
    assert db.exec_driver_sql("SELECT * FROM buildings ORDER BY id").all() == buildings
    assert db.exec_driver_sql("SELECT * FROM rooms ORDER BY id").all() == rooms
    if populated:
        assert db.exec_driver_sql(
            "SELECT id FROM sale_owner_links WHERE status='active' ORDER BY id"
        ).scalars().all() == [2, 7, 10]
        with pytest.raises(IntegrityError), db.begin_nested():
            db.exec_driver_sql(
                "INSERT INTO sale_owner_links (id,owner_id,sale_id,status) VALUES (12,1,9,'active')"
            )
        # Historical duplicates remain valid under the restored partial index.
        db.exec_driver_sql(
            "INSERT INTO sale_owner_links (id,owner_id,sale_id,status) VALUES (12,1,9,'ended')"
        )
    migration.upgrade()
    assert db.exec_driver_sql("SELECT COUNT(*) FROM sale_owner_links").scalar() == len(
        before
    ) + int(populated)
    assert "uq_sale_owner_links_building_active" in {
        i["name"] for i in sa.inspect(db).get_indexes("sale_owner_links")
    }


def test_roundtrip_with_preexisting_unnamed_building_foreign_key(migration_db):
    db, migration = migration_db
    db.exec_driver_sql(
        "ALTER TABLE sale_owner_links ADD COLUMN building_id INTEGER REFERENCES buildings(id) ON DELETE CASCADE"
    )
    migration.upgrade()
    migration.downgrade()
    inspector = sa.inspect(db)
    assert "building_id" not in {c["name"] for c in inspector.get_columns("sale_owner_links")}
    assert all(
        fk["referred_table"] != "buildings"
        for fk in inspector.get_foreign_keys("sale_owner_links")
    )
    assert "uq_sale_owner_links_owner_active" in {
        i["name"] for i in inspector.get_indexes("sale_owner_links")
    }
