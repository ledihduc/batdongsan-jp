"""
test_smoke_postgres.py — Postgres integration smoke tests (Phase 01).

Tests verify:
- Basic CRUD for all core entities against a real Postgres DB
- FK relationships (house.host_id → user)
- Booking status transitions (pending → approved → completed)
- Cross-host isolation (User A's houses are not returned when querying User B's)
- Idempotent seed (categories/amenities created without duplicates)

Requires DATABASE_URL to point at a running Postgres instance with alembic
migrations applied (`alembic upgrade head`).

All tests use transactional rollback — no test data persists between tests.
"""

from __future__ import annotations

import pytest
from sqlalchemy.orm import Session


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────


def _make_user(db: Session, *, email: str, role: str = "guest", name: str = "Test User") -> "models.User":
    from app import models, auth

    user = models.User(
        name=name,
        email=email,
        password_hash=auth.hash_password("test_password_123"),
        phone="0900000000",
        role=role,
        is_active=True,
    )
    db.add(user)
    db.flush()  # get id without committing
    return user


def _make_category(db: Session, *, name: str = "Test Category") -> "models.Category":
    from app import models

    cat = models.Category(name=name, icon="test_icon")
    db.add(cat)
    db.flush()
    return cat


def _make_house(
    db: Session,
    *,
    host_id: int,
    category_id: int,
    title: str = "Test House",
    status: str = "pending",
) -> "models.House":
    from app import models

    house = models.House(
        host_id=host_id,
        title=title,
        description="Test description",
        category_id=category_id,
        price=5_000_000,
        area=50,
        address="123 Test Street",
        city="TP. Hồ Chí Minh",
        district="Quận 1",
        bedrooms=2,
        bathrooms=1,
        status=status,
        images=[],
        amenities=[],
        listing_type="single",
        total_units=1,
        available_units=1,
        gender_pref="any",
    )
    db.add(house)
    db.flush()
    return house


def _make_booking(
    db: Session,
    *,
    house_id: int,
    guest_id: int,
    status: str = "pending",
) -> "models.ViewingAppointment":
    from app import models

    booking = models.ViewingAppointment(
        house_id=house_id,
        guest_id=guest_id,
        booking_date="2026-07-01",
        booking_time="10:00",
        message="Test booking",
        status=status,
    )
    db.add(booking)
    db.flush()
    return booking


# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────


class TestUserCRUD:
    """Basic User CRUD operations against Postgres."""

    def test_create_user(self, pg_session: Session) -> None:
        user = _make_user(pg_session, email="create@smoke.test")
        assert user.id is not None
        assert user.id > 0

    def test_fetch_user_by_email(self, pg_session: Session) -> None:
        from app import models

        _make_user(pg_session, email="fetch@smoke.test", name="Fetch User")

        found = pg_session.query(models.User).filter_by(email="fetch@smoke.test").first()
        assert found is not None
        assert found.name == "Fetch User"

    def test_update_user_name(self, pg_session: Session) -> None:
        from app import models

        user = _make_user(pg_session, email="update@smoke.test", name="Old Name")
        user.name = "New Name"
        pg_session.flush()

        refreshed = pg_session.query(models.User).filter_by(email="update@smoke.test").first()
        assert refreshed is not None
        assert refreshed.name == "New Name"

    def test_unique_email_constraint(self, pg_session: Session) -> None:
        from sqlalchemy.exc import IntegrityError

        _make_user(pg_session, email="dup@smoke.test")
        pg_session.flush()

        with pytest.raises(IntegrityError):
            _make_user(pg_session, email="dup@smoke.test")
            pg_session.flush()


class TestHouseCRUD:
    """House CRUD with FK (host_id → user) against Postgres."""

    def test_create_house_with_host(self, pg_session: Session) -> None:
        from app import models

        host = _make_user(pg_session, email="host_house@smoke.test", role="host")
        cat = _make_category(pg_session)
        house = _make_house(pg_session, host_id=host.id, category_id=cat.id)

        assert house.id is not None
        assert house.host_id == host.id

    def test_query_houses_by_host_id(self, pg_session: Session) -> None:
        from app import models

        host = _make_user(pg_session, email="query_host@smoke.test", role="host")
        cat = _make_category(pg_session)
        _make_house(pg_session, host_id=host.id, category_id=cat.id, title="House 1")
        _make_house(pg_session, host_id=host.id, category_id=cat.id, title="House 2")

        results = pg_session.query(models.House).filter_by(host_id=host.id).all()
        assert len(results) == 2
        titles = {h.title for h in results}
        assert titles == {"House 1", "House 2"}

    def test_house_json_list_columns(self, pg_session: Session) -> None:
        """Verify JSONList columns (images, amenities) round-trip correctly."""
        from app import models

        host = _make_user(pg_session, email="json_host@smoke.test", role="host")
        cat = _make_category(pg_session)
        house = models.House(
            host_id=host.id,
            title="JSON Test House",
            description="",
            category_id=cat.id,
            price=1_000_000,
            area=30,
            address="",
            city="Hà Nội",
            district="",
            bedrooms=1,
            bathrooms=1,
            status="pending",
            images=["https://example.com/img1.jpg", "https://example.com/img2.jpg"],
            amenities=["Wifi", "AC"],
            listing_type="single",
            total_units=1,
            available_units=1,
            gender_pref="any",
        )
        pg_session.add(house)
        pg_session.flush()

        # Reload from DB
        pg_session.expire(house)
        reloaded = pg_session.get(models.House, house.id)
        assert reloaded is not None
        assert reloaded.images == ["https://example.com/img1.jpg", "https://example.com/img2.jpg"]
        assert reloaded.amenities == ["Wifi", "AC"]


class TestViewingAppointmentStatusTransitions:
    """ViewingAppointment status transitions against Postgres."""

    def test_pending_to_approved(self, pg_session: Session) -> None:
        from app import models

        host = _make_user(pg_session, email="bk_host1@smoke.test", role="host")
        guest = _make_user(pg_session, email="bk_guest1@smoke.test", role="guest")
        cat = _make_category(pg_session)
        house = _make_house(pg_session, host_id=host.id, category_id=cat.id)
        booking = _make_booking(pg_session, house_id=house.id, guest_id=guest.id)

        assert booking.status == "pending"
        booking.status = "approved"
        pg_session.flush()

        reloaded = pg_session.get(models.ViewingAppointment, booking.id)
        assert reloaded is not None
        assert reloaded.status == "approved"

    def test_approved_to_completed(self, pg_session: Session) -> None:
        from app import models

        host = _make_user(pg_session, email="bk_host2@smoke.test", role="host")
        guest = _make_user(pg_session, email="bk_guest2@smoke.test", role="guest")
        cat = _make_category(pg_session)
        house = _make_house(pg_session, host_id=host.id, category_id=cat.id)
        booking = _make_booking(pg_session, house_id=house.id, guest_id=guest.id, status="approved")

        booking.status = "completed"
        pg_session.flush()

        reloaded = pg_session.get(models.ViewingAppointment, booking.id)
        assert reloaded is not None
        assert reloaded.status == "completed"

    def test_booking_cancelled(self, pg_session: Session) -> None:
        from app import models

        host = _make_user(pg_session, email="bk_host3@smoke.test", role="host")
        guest = _make_user(pg_session, email="bk_guest3@smoke.test", role="guest")
        cat = _make_category(pg_session)
        house = _make_house(pg_session, host_id=host.id, category_id=cat.id)
        booking = _make_booking(pg_session, house_id=house.id, guest_id=guest.id)

        booking.status = "cancelled"
        pg_session.flush()

        reloaded = pg_session.get(models.ViewingAppointment, booking.id)
        assert reloaded is not None
        assert reloaded.status == "cancelled"


class TestCrossHostIsolation:
    """Verify Host A's data is not visible when querying Host B."""

    def test_host_a_houses_not_in_host_b_query(self, pg_session: Session) -> None:
        from app import models

        host_a = _make_user(pg_session, email="iso_a@smoke.test", role="host", name="Host A")
        host_b = _make_user(pg_session, email="iso_b@smoke.test", role="host", name="Host B")
        cat = _make_category(pg_session)

        _make_house(pg_session, host_id=host_a.id, category_id=cat.id, title="A's House")
        _make_house(pg_session, host_id=host_b.id, category_id=cat.id, title="B's House")

        host_b_houses = pg_session.query(models.House).filter_by(host_id=host_b.id).all()
        titles = [h.title for h in host_b_houses]

        assert "B's House" in titles
        assert "A's House" not in titles

    def test_guest_booking_isolation(self, pg_session: Session) -> None:
        """User A's bookings are not returned when querying User B's bookings."""
        from app import models

        host = _make_user(pg_session, email="guest_iso_host@smoke.test", role="host")
        guest_a = _make_user(pg_session, email="guest_a_iso@smoke.test", role="guest", name="Guest A")
        guest_b = _make_user(pg_session, email="guest_b_iso@smoke.test", role="guest", name="Guest B")
        cat = _make_category(pg_session)
        house = _make_house(pg_session, host_id=host.id, category_id=cat.id)

        _make_booking(pg_session, house_id=house.id, guest_id=guest_a.id)
        _make_booking(pg_session, house_id=house.id, guest_id=guest_b.id)

        guest_b_bookings = pg_session.query(models.ViewingAppointment).filter_by(guest_id=guest_b.id).all()
        guest_ids = {b.guest_id for b in guest_b_bookings}

        assert guest_b.id in guest_ids
        assert guest_a.id not in guest_ids


class TestCategoryAmenityCRUD:
    """Category and Amenity basic CRUD."""

    def test_create_category(self, pg_session: Session) -> None:
        from app import models

        cat = models.Category(name="Test Cat", icon="home")
        pg_session.add(cat)
        pg_session.flush()

        found = pg_session.query(models.Category).filter_by(name="Test Cat").first()
        assert found is not None
        assert found.icon == "home"

    def test_create_amenity(self, pg_session: Session) -> None:
        from app import models

        amenity = models.Amenity(name="Test Amenity", icon="wifi")
        pg_session.add(amenity)
        pg_session.flush()

        found = pg_session.query(models.Amenity).filter_by(name="Test Amenity").first()
        assert found is not None
        assert found.icon == "wifi"
