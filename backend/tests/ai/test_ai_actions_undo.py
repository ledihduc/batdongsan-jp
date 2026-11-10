"""Gỡ dữ liệu AI đã ghi theo `result` của pending executed (Phase 09, F-8, rollback)."""

from __future__ import annotations

import secrets

import pytest

from app.ai_capabilities.context import ActionContext
from app.domain.ai_pending_action import AiPendingAction
from app.domain.jp.viewing import JpViewing
from app.models import Wishlist
from app.services.ai_actions.pending_store import hash_token, utcnow
from app.services.ai_actions.undo_service import UndoReport, undo_executed_actions
from app.services.ai_actions.wishlist_writer import save_wishlist
from app.services.jp_search.ai_write_tools import tool_request_viewing
from tests.ai.write_test_utils import WRITE_TABLES, make_user, valid_slot
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_search_fixture


@pytest.fixture()
def db():
    session = make_sqlite_session(extra_tables=WRITE_TABLES)
    yield session
    session.close()


@pytest.fixture()
def ids(db):
    return seed_search_fixture(db)


def _executed(db, action: str, params: dict, result: dict, uid: int) -> None:
    now = utcnow()
    db.add(AiPendingAction(token_sha256=hash_token(secrets.token_urlsafe(32)), action=action, params=params,
                           channel="mcp", status="executed", result=result, executed_by_user_id=uid,
                           created_at=now, expires_at=now, executed_at=now))
    db.commit()


@pytest.fixture()
def seeded(db, ids):
    """User tự lưu [SBY-OK2]; AI lưu [SBY-OK1] (created) + [SBY-OK2] (đã có, created False) + 1 lịch xem."""
    uid = make_user(db)
    ok1, ok2 = ids["[SBY-OK1]"], ids["[SBY-OK2]"]
    save_wishlist(db, user_id=uid, house_id=ok2, dry_run=False)
    db.commit()
    _executed(db, "save_favorite", {"listing_id": ok1}, save_wishlist(db, user_id=uid, house_id=ok1, dry_run=False), uid)
    _executed(db, "save_favorite", {"listing_id": ok2}, save_wishlist(db, user_id=uid, house_id=ok2, dry_run=False), uid)
    ctx = ActionContext(channel="confirm", user={"sub": str(uid)})
    params = {"listing_id": ok1, "slots": [valid_slot()]}
    _executed(db, "request_viewing", params, tool_request_viewing(db, params, ctx), uid)
    return uid


def test_ai_actions_undo_removes_only_ai_created_rows(db, seeded):
    # Act
    rep = undo_executed_actions(db, dry_run=False)
    # Assert
    db.expire_all()
    assert rep == UndoReport(wishlists_deleted=1, viewings_deleted=1, pending_marked=3)
    assert db.query(Wishlist).count() == 1 and db.query(JpViewing).count() == 0
    assert {r.status for r in db.query(AiPendingAction)} == {"undone"}


def test_ai_actions_undo_dry_run_deletes_nothing(db, seeded):
    # Act
    rep = undo_executed_actions(db)
    # Assert
    db.expire_all()
    assert rep == UndoReport(wishlists_deleted=1, viewings_deleted=1, pending_marked=3)
    assert db.query(Wishlist).count() == 2 and db.query(JpViewing).count() == 1
    assert {r.status for r in db.query(AiPendingAction)} == {"executed"}
