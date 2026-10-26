"""True concurrent PostgreSQL writers and additive migration round trips.

Run only on a disposable database migrated to HEAD, using SHORT_STAY_TEST_URL.
Each test uses its own schema or UUID users; never points to deployment databases.
"""

import importlib.util
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from pathlib import Path
from threading import Barrier
from uuid import uuid4

import pytest
import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations
from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models
from app.services import (
    reservation_service,
    short_stay_service as stays,
    source_service,
)

URL = os.getenv("SHORT_STAY_TEST_URL")
pytestmark = pytest.mark.skipif(
    not URL, reason="SHORT_STAY_TEST_URL requires disposable PostgreSQL"
)


@pytest.fixture
def engine():
    eng = sa.create_engine(URL)
    yield eng
    eng.dispose()


@pytest.fixture
def migration_db(engine):
    with engine.connect() as conn:
        tx = conn.begin()
        schema = "short_stay_" + uuid4().hex
        conn.exec_driver_sql(f"CREATE SCHEMA {schema}")
        conn.exec_driver_sql(f"SET search_path TO {schema},public")
        conn.exec_driver_sql(
            "CREATE TABLE reservations (id serial PRIMARY KEY, room_id integer, check_in_date date, check_out_date date, status text)"
        )
        conn.exec_driver_sql(
            "CREATE TABLE room_chiem_dung (id serial PRIMARY KEY, room_id integer, tu_ngay date, den_ngay date)"
        )
        conn.exec_driver_sql(
            "CREATE TABLE room_kenh (id serial PRIMARY KEY, gia float)"
        )
        for table, name, a, b, pred in [
            (
                "reservations",
                "excl_reservations_room_overlap",
                "check_in_date",
                "check_out_date",
                " WHERE (status IN ('pending','approved','checked_in'))",
            ),
            (
                "room_chiem_dung",
                "excl_room_chiem_dung_trung",
                "tu_ngay",
                "den_ngay",
                "",
            ),
        ]:
            conn.exec_driver_sql(
                f"ALTER TABLE {table} ADD CONSTRAINT {name} EXCLUDE USING gist (room_id WITH =, daterange({a},{b},'[)') WITH &&){pred}"
            )
        path = Path(__file__).parents[1] / "alembic/versions/0105_short_stays.py"
        spec = importlib.util.spec_from_file_location("short_stay_migration", path)
        migration = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(migration)
        with Operations.context(MigrationContext.configure(conn)):
            yield conn, migration
        tx.rollback()


def test_upgrade_preserves_legacy_and_downgrade_restores(migration_db):
    c, m = migration_db
    c.exec_driver_sql(
        "INSERT INTO reservations(room_id,check_in_date,check_out_date,status) VALUES (1,'2030-01-01','2030-01-03','approved')"
    )
    c.exec_driver_sql(
        "INSERT INTO room_chiem_dung(room_id,tu_ngay,den_ngay) VALUES (1,'2030-01-03','2030-02-01')"
    )
    m.upgrade()
    assert c.exec_driver_sql("SELECT booking_mode FROM reservations").scalar() is None
    with pytest.raises(IntegrityError), c.begin_nested():
        c.exec_driver_sql(
            "INSERT INTO reservations(room_id,check_in_date,check_out_date,status,booking_mode,check_in_at,check_out_at,booking_code) VALUES (1,'2030-01-02','2030-01-03','pending','theo_gio','2030-01-02 10:00','2030-01-02 12:00','AC-test')"
        )
    with pytest.raises(IntegrityError), c.begin_nested():
        c.exec_driver_sql(
            "INSERT INTO room_chiem_dung(room_id,tu_ngay,den_ngay,tu_luc,den_luc) VALUES (1,'2030-01-04','2030-01-05','2030-01-04 10:00','2030-01-04 12:00')"
        )
    with pytest.raises(IntegrityError), c.begin_nested():
        c.exec_driver_sql(
            "INSERT INTO reservations(room_id,check_in_date,check_out_date,status,check_in_at,check_out_at) VALUES (2,'2030-01-01','2030-01-02','pending','2030-01-01 10:00','2030-01-01 12:00')"
        )
    m.downgrade()
    assert "booking_mode" not in {
        col["name"] for col in sa.inspect(c).get_columns("reservations")
    }
    assert c.exec_driver_sql("SELECT count(*) FROM reservations").scalar() == 1
    with pytest.raises(IntegrityError), c.begin_nested():
        c.exec_driver_sql(
            "INSERT INTO reservations(room_id,check_in_date,check_out_date,status) VALUES (1,'2030-01-02','2030-01-04','pending')"
        )
    m.upgrade()


def test_downgrade_refuses_lossy_intraday_data(migration_db):
    c, m = migration_db
    m.upgrade()
    c.exec_driver_sql(
        "INSERT INTO room_chiem_dung(room_id,tu_ngay,den_ngay,tu_luc,den_luc) VALUES (1,'2030-01-01','2030-01-02','2030-01-01 10:00','2030-01-01 12:00'),(1,'2030-01-01','2030-01-02','2030-01-01 12:00','2030-01-01 14:00')"
    )
    with pytest.raises(RuntimeError, match="Không thể hạ phiên bản"):
        m.downgrade()
    assert c.exec_driver_sql("SELECT count(tu_luc) FROM room_chiem_dung").scalar() == 2
    c.exec_driver_sql("DELETE FROM room_chiem_dung")
    m.downgrade()


@pytest.fixture
def room(engine):
    with Session(engine) as db:
        suffix = uuid4().hex
        host = models.User(
            name="Chủ test",
            email=f"{suffix}@test.vn",
            password_hash="x",
            role="host",
            is_active=True,
        )
        guest = models.User(
            name="Khách test",
            email=f"g{suffix}@test.vn",
            password_hash="x",
            role="user",
            is_active=True,
        )
        db.add_all([host, guest])
        db.flush()
        building = models.Building(
            host_id=host.id,
            name="Concurrency",
            address="1",
            city="Đà Nẵng",
            district="Hải Châu",
        )
        db.add(building)
        db.flush()
        room = models.Room(
            building_id=building.id,
            code="TEST",
            base_price=9000000,
            status="vacant",
            capacity=2,
        )
        db.add(room)
        db.flush()
        db.add(
            models.RoomKenh(
                room_id=room.id,
                kenh="ngan_han",
                don_vi="dem",
                gia=500000,
                gia_theo_gio=80000,
            )
        )
        source_service.resolve_default_source_id(db, host.id, "marketplace")
        db.commit()
        yield room.id, host.id, guest.id


def test_two_simultaneous_requests_one_booking(engine, room):
    room_id, host, guest = room
    ci = datetime.combine(
        stays.local_now().date() + timedelta(days=5), datetime.min.time()
    ).replace(hour=14)
    co = ci + timedelta(hours=2)
    barrier = Barrier(2)

    def worker():
        with Session(engine) as db:
            q = stays.quote(db, room_id, "theo_gio", stays.iso(ci), stays.iso(co))
            barrier.wait(timeout=10)
            try:
                res = reservation_service.create_reservation(
                    db,
                    host,
                    dict(
                        room_id=room_id,
                        booking_mode="theo_gio",
                        check_in_at=stays.iso(ci),
                        check_out_at=stays.iso(co),
                        quote_token=q["quote_token"],
                        guest_name="Khách",
                        guest_user_id=guest,
                    ),
                    guest,
                    "marketplace",
                )
                db.commit()
                # This executes PostgreSQL DATE → guest response, not a mocked model.
                from app.routers.guest_reservation import _serialise

                assert _serialise(res, db).check_in_date == ci.date().isoformat()
                return 201
            except HTTPException as exc:
                db.rollback()
                return exc.status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: worker(), range(2)))
    assert sorted(results) == [201, 409]
    with Session(engine) as db:
        assert db.query(models.Reservation).filter_by(room_id=room_id).count() == 1
        assert db.query(models.RoomChiemDung).filter_by(room_id=room_id).count() == 1


def test_database_exclusion_rejects_direct_concurrent_mixed_writers(engine, room):
    room_id, _, _ = room
    barrier = Barrier(2)

    def worker(precise):
        with engine.connect() as c:
            tx = c.begin()
            barrier.wait(timeout=10)
            try:
                c.execute(
                    sa.text(
                        "INSERT INTO room_chiem_dung(room_id,tu_ngay,den_ngay,tu_luc,den_luc,kenh,nguon,created_at) VALUES (:room,'2031-01-01','2031-01-03',:ci,:co,:kenh,'thu_cong',now())"
                    ),
                    {
                        "room": room_id,
                        "ci": datetime(2031, 1, 2, 10) if precise else None,
                        "co": datetime(2031, 1, 2, 12) if precise else None,
                        "kenh": "ngan_han" if precise else "dai_han",
                    },
                )
                tx.commit()
                return "ok"
            except IntegrityError as exc:
                tx.rollback()
                assert exc.orig.pgcode == "23P01"
                return "conflict"

    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(worker, [True, False])) == ["conflict", "ok"]
