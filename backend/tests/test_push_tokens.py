from __future__ import annotations

from unittest.mock import MagicMock

from app.routers.users import register_push_token, unregister_push_token


def _query_returning(row):
    query = MagicMock()
    query.filter.return_value = query
    query.first.return_value = row
    return query


def test_register_push_token_creates_row():
    db = MagicMock()
    db.query.return_value = _query_returning(None)

    result = register_push_token(
        {
            "token": "fcm-token",
            "deviceId": "install-1",
            "platform": "ios",
        },
        db=db,
        claims={"sub": "42"},
    )

    assert result["success"] is True
    db.add.assert_called_once()
    row = db.add.call_args.args[0]
    assert row.user_id == 42
    assert row.token == "fcm-token"
    assert row.device_id == "install-1"
    assert row.platform == "ios"
    db.commit.assert_called_once()


def test_register_push_token_updates_existing_row():
    existing = MagicMock()
    db = MagicMock()
    db.query.return_value = _query_returning(existing)

    register_push_token(
        {
            "token": "new-token",
            "deviceId": "install-1",
            "platform": "android",
        },
        db=db,
        claims={"sub": "42"},
    )

    assert existing.token == "new-token"
    assert existing.platform == "android"
    assert existing.is_active is True
    db.add.assert_not_called()
    db.commit.assert_called_once()


def test_unregister_push_token_is_idempotent_when_missing():
    db = MagicMock()
    db.query.return_value = _query_returning(None)

    result = unregister_push_token(
        {"deviceId": "install-1"},
        db=db,
        claims={"sub": "42"},
    )

    assert result == {"success": True}
    db.commit.assert_not_called()


def test_unregister_push_token_deactivates_existing_row():
    existing = MagicMock()
    db = MagicMock()
    db.query.return_value = _query_returning(existing)

    result = unregister_push_token(
        {"deviceId": "install-1"},
        db=db,
        claims={"sub": "42"},
    )

    assert result == {"success": True}
    assert existing.is_active is False
    db.commit.assert_called_once()
