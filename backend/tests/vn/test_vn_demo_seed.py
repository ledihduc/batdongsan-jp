"""Seed 20 tin demo VN: idempotent, loại hình phải có sẵn, gỡ đúng tin demo (Phase 13, S12)."""

from __future__ import annotations

import pytest

from tests.vn.vn_fixtures import VN_DEMO_JSON, make_vn_categories

from app.models import Category, House, User, Wishlist
from app.services.vn_demo_seed import VN_DEMO_HOST_EMAIL, load_vn_demo_listings, seed_vn_demo, undo_vn_demo
from tests.jp.search.jp_search_fixtures import make_sqlite_session


@pytest.fixture()
def db():
    session = make_sqlite_session(extra_tables=("wishlists",))
    make_vn_categories(session)
    yield session
    session.close()


def test_vn_demo_seed_twice_creates_no_duplicates(db):
    # Arrange
    rows = load_vn_demo_listings(VN_DEMO_JSON)
    # Act
    first = seed_vn_demo(db, rows)
    second = seed_vn_demo(db, rows)
    # Assert
    assert first.houses_created == 20 and second.houses_created == 0 and second.houses_updated == 20
    assert db.query(House).count() == 20
    assert {h.status for h in db.query(House)} == {"published"}


def test_vn_demo_seed_unknown_category_raises_value_error(db):
    # Arrange
    rows = load_vn_demo_listings(VN_DEMO_JSON)[:1]
    rows[0] = {**rows[0], "category": "Không có"}
    # Act / Assert
    with pytest.raises(ValueError):
        seed_vn_demo(db, rows)
    assert db.query(House).count() == 0


def test_vn_demo_seed_undo_removes_only_demo_rows(db):
    # Arrange — 1 tin của host khác + 1 wishlist trỏ tin demo
    other = User(name="Khác", email="other@example.invalid", password_hash="x", role="host")
    db.add(other)
    db.flush()
    db.add(House(host_id=other.id, title="Tin thật", category_id=1, price=1, status="published",
                 images=[], amenities=[]))
    db.commit()
    seed_vn_demo(db, load_vn_demo_listings(VN_DEMO_JSON))
    demo_house = db.query(House).filter(House.title.startswith("[Q1-OK1]")).one()
    db.add(Wishlist(user_id=other.id, house_id=demo_house.id))
    db.commit()
    categories_before = db.query(Category).count()
    # Act
    removed = undo_vn_demo(db)
    # Assert
    assert removed == 20
    assert [h.title for h in db.query(House)] == ["Tin thật"]
    assert db.query(Category).count() == categories_before
    assert db.query(User).filter(User.email == VN_DEMO_HOST_EMAIL).count() == 0
    assert db.query(Wishlist).count() == 0


def test_vn_demo_seed_undo_without_seed_returns_zero(db):
    # Act / Assert
    assert undo_vn_demo(db) == 0
