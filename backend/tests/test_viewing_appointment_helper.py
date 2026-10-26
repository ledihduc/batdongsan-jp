"""
Unit tests for helpers.viewing_appointment_to_dict.

Verifies the response dict includes:
- host_id (derived from house.host_id)
- has_reviewed (computed only when status='completed')

Uses MagicMock to simulate Session.get / Session.query without DB.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock

import pytest

from app.helpers import viewing_appointment_to_dict


def _make_house(host_id=42):
    h = MagicMock()
    h.host_id = host_id
    h.title = "Test house"
    h.address = "123 Test St"
    h.price = 5_000_000
    h.images = ["a.jpg"]
    return h


def _make_user(name="Tester", phone="0900000000"):
    u = MagicMock()
    u.name = name
    u.phone = phone
    return u


def _make_appointment(status="pending"):
    b = MagicMock()
    b.id = 1
    b.house_id = 10
    # This fixture is house-based; an unset MagicMock attribute would create
    # a truthy room_id and trigger an unrelated RoomKenh lookup.
    b.room_id = None
    b.guest_id = 5
    b.booking_date = "2026-06-28"
    b.booking_time = "09:00"
    b.message = "Cho hỏi"
    b.status = status
    b.created_at = datetime(2026, 6, 27, 8, 0, tzinfo=timezone.utc)
    return b


def _build_db(house, guest, host, has_review):
    """Stub a SQLAlchemy Session with predictable get/query results.

    Identity check (`model is House`) is unreliable under full pytest runs
    because earlier suites may reload `app.models`, leading to two distinct
    class objects with the same name. Compare by class name to stay robust.
    """
    db = MagicMock()

    def _get(model, pk):
        model_name = getattr(model, "__name__", "")
        if model_name == "House":
            return house
        if model_name == "User":
            # Return host for the host lookup, guest for the guest lookup.
            return host if pk == (house.host_id if house else None) else guest
        return None

    db.get.side_effect = _get
    # query(Review).filter(...).first() returns truthy when has_review True.
    review_first = MagicMock() if has_review else None
    db.query.return_value.filter.return_value.first.return_value = review_first
    return db


def test_includes_host_id_when_house_exists():
    house = _make_house(host_id=42)
    appt = _make_appointment(status="pending")
    db = _build_db(house, _make_user("Guest"), _make_user("Host"), has_review=False)

    out = viewing_appointment_to_dict(db, appt)

    assert out["host_id"] == 42
    assert out["house_title"] == "Test house"
    assert out["has_reviewed"] is False


def test_host_id_none_when_house_deleted():
    appt = _make_appointment(status="pending")
    db = _build_db(house=None, guest=_make_user(), host=None, has_review=False)

    out = viewing_appointment_to_dict(db, appt)

    assert out["host_id"] is None
    assert out["house_title"] is None
    assert out["has_reviewed"] is False


def test_has_reviewed_true_only_when_completed_and_review_exists():
    house = _make_house()
    appt = _make_appointment(status="completed")
    db = _build_db(house, _make_user(), _make_user(), has_review=True)

    out = viewing_appointment_to_dict(db, appt)

    assert out["has_reviewed"] is True


def test_has_reviewed_false_when_completed_but_no_review():
    house = _make_house()
    appt = _make_appointment(status="completed")
    db = _build_db(house, _make_user(), _make_user(), has_review=False)

    out = viewing_appointment_to_dict(db, appt)

    assert out["has_reviewed"] is False


def test_has_reviewed_not_queried_for_non_completed():
    """Verify Review query is skipped to avoid N+1 on pending/approved lists."""
    house = _make_house()
    appt = _make_appointment(status="pending")
    db = _build_db(house, _make_user(), _make_user(), has_review=True)

    out = viewing_appointment_to_dict(db, appt)

    assert out["has_reviewed"] is False  # ignored because status != completed
    db.query.assert_not_called()


@pytest.mark.parametrize("status", ["approved", "rejected", "cancelled", "locked", "lost"])
def test_other_statuses_skip_review_query(status):
    house = _make_house()
    appt = _make_appointment(status=status)
    db = _build_db(house, _make_user(), _make_user(), has_review=True)

    out = viewing_appointment_to_dict(db, appt)

    assert out["has_reviewed"] is False
    db.query.assert_not_called()
