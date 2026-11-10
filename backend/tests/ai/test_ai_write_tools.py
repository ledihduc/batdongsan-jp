"""Handler action ghi: lưu yêu thích, đặt lịch xem — ghi thật / dry-run (Phase 09, AC14)."""

from __future__ import annotations

import pytest

from tests.ai.write_test_utils import WRITE_TABLES, make_user, valid_slot

from app.ai_capabilities.context import ActionContext
from app.domain.jp.viewing import JpViewing
from app.models import Wishlist
from app.services.jp_search.ai_write_tools import tool_request_viewing, tool_save_favorite
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture


@pytest.fixture()
def db():
    session = make_sqlite_session(extra_tables=WRITE_TABLES)
    yield session
    session.close()


@pytest.fixture()
def ids(db):
    return seed_search_fixture(db)


@pytest.fixture()
def uid(db):
    return make_user(db)


@pytest.fixture()
def ctx(uid):
    return ActionContext(channel="confirm", user={"sub": uid, "role": "guest"})


def test_ai_write_tools_save_favorite_creates_wishlist_row(db, ids, uid, ctx):
    # Act
    out = tool_save_favorite(db, {"listing_id": ids["[SBY-OK1]"]}, ctx)
    # Assert
    assert out["saved"] is True and out["created"] is True and out["wishlist_id"]
    assert db.query(Wishlist).filter_by(user_id=uid, house_id=ids["[SBY-OK1]"]).count() == 1


def test_ai_write_tools_save_favorite_twice_returns_existing_not_duplicate(db, ids, uid, ctx):
    # Arrange
    first = tool_save_favorite(db, {"listing_id": ids["[SBY-OK1]"]}, ctx)
    # Act
    second = tool_save_favorite(db, {"listing_id": ids["[SBY-OK1]"]}, ctx)
    # Assert
    assert second["created"] is False and second["wishlist_id"] == first["wishlist_id"]
    assert db.query(Wishlist).filter_by(user_id=uid).count() == 1


def test_ai_write_tools_save_favorite_unknown_listing_raises_lookup(db, ids, ctx):
    # Act / Assert
    with pytest.raises(LookupError):
        tool_save_favorite(db, {"listing_id": 999999}, ctx)


def test_ai_write_tools_dry_run_writes_nothing(db, ids, uid):
    # Arrange — dry-run lúc tạo pending: MCP chưa có user
    dry = ActionContext(channel="mcp", dry_run=True)
    # Act
    fav = tool_save_favorite(db, {"listing_id": ids["[SBY-OK1]"]}, dry)
    view = tool_request_viewing(db, {"listing_id": ids["[SBY-OK1]"], "slots": [valid_slot()]}, dry)
    # Assert
    assert "preview" in fav and "preview" in view
    assert db.query(Wishlist).count() == 0 and db.query(JpViewing).count() == 0


def test_ai_write_tools_request_viewing_creates_requested_row_with_ai_note(db, ids, uid, ctx):
    # Act
    out = tool_request_viewing(db, {"listing_id": ids["[SBY-OK1]"], "slots": [valid_slot()], "note": "午前希望"}, ctx)
    # Assert
    row = db.query(JpViewing).one()
    assert out == {"viewing_id": row.id, "status": "requested", "created": True}
    assert row.status == "requested" and row.tenant_id == uid and row.listing_id == str(ids["[SBY-OK1]"])
    assert row.notes == "[AI] 午前希望"


def test_ai_write_tools_request_viewing_slot_outside_hours_raises_value_error(db, ids, ctx):
    # Act / Assert
    with pytest.raises(ValueError):
        tool_request_viewing(db, {"listing_id": ids["[SBY-OK1]"], "slots": [valid_slot(hour=21)]}, ctx)
    assert db.query(JpViewing).count() == 0
