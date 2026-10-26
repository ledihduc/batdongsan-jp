"""Smoke test for the P0 Security Sweep — verifies that previously-unauth
routers now reject anonymous calls with 401.

These tests DON'T need a real DB because the auth dependency runs BEFORE
the route function. We mount each router on a minimal FastAPI app, hit
each endpoint with no Authorization header, and assert 401.

For the role-gated test (admin-only list_users), we sign a guest JWT and
assert 403.

Coverage: users, notifications, chat, upload — the
routers that had 0 auth deps before this sweep (wishlists stripped in
JP fork cluster I chunk-3; reviews stripped in chunk-4).
"""

from __future__ import annotations

import os

# Test env must be set before any app.* import
os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient


@pytest.fixture
def client_users():
    from app.routers.users import router

    app = FastAPI()
    app.include_router(router)
    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture
def client_notifications():
    from app.routers.notifications import router

    app = FastAPI()
    app.include_router(router)
    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture
def client_chat():
    from app.routers.chat import router

    app = FastAPI()
    app.include_router(router)
    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture
def client_upload():
    from app.routers.upload import router

    app = FastAPI()
    app.include_router(router)
    return TestClient(app, raise_server_exceptions=False)


# ── Anonymous access → 401 ───────────────────────────────────────────────────

def _hit(client, method, path):
    """Call TestClient with the right kwargs per method (get/delete don't
    accept json)."""
    m = getattr(client, method)
    if method in ("post", "patch", "put"):
        return m(path, json={})
    return m(path)


@pytest.mark.parametrize(
    "method,path",
    [
        ("get", "/api/users"),
        ("patch", "/api/users/1"),
    ],
)
def test_users_anonymous_blocked(client_users, method, path):
    resp = _hit(client_users, method, path)
    assert resp.status_code == 401, f"{method.upper()} {path} should require auth"


@pytest.mark.parametrize(
    "method,path",
    [
        ("get", "/api/notifications"),
        ("patch", "/api/notifications/1/read"),
        ("patch", "/api/notifications/read-all"),
    ],
)
def test_notifications_anonymous_blocked(client_notifications, method, path):
    resp = _hit(client_notifications, method, path)
    assert resp.status_code == 401, f"{method.upper()} {path} should require auth"


@pytest.mark.parametrize(
    "method,path",
    [
        ("get", "/api/chats"),
        ("get", "/api/chats/2/messages"),
        ("post", "/api/chats/2/messages"),
        ("patch", "/api/chats/2/read"),
    ],
)
def test_chat_anonymous_blocked(client_chat, method, path):
    resp = _hit(client_chat, method, path)
    assert resp.status_code == 401, f"{method.upper()} {path} should require auth"


def test_upload_anonymous_blocked(client_upload):
    resp = client_upload.post("/api/upload", json={"data": "abc"})
    assert resp.status_code == 401


# ── Guest token vs admin-only endpoint → 403 ────────────────────────────────

def test_list_users_requires_admin(client_users):
    """Guest with valid JWT still gets 403 on admin-only list."""
    from app.auth import sign_token

    guest_token = sign_token(user_id=1, role="guest")
    resp = client_users.get(
        "/api/users",
        headers={"Authorization": f"Bearer {guest_token}"},
    )
    assert resp.status_code == 403


def test_host_workspace_requires_an_active_account_without_promoting_role():
    """All active business accounts are admitted; inactive/missing users are not."""
    from fastapi import Depends, FastAPI
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session
    from sqlalchemy.pool import StaticPool
    from app import auth, models
    from app.database import Base, get_db

    app = FastAPI()

    @app.get("/host-only")
    def _h(_claims: dict = Depends(auth.require_host)):
        return {"role": _claims["role"]}

    @app.get("/admin-only")
    def _a(_claims: dict = Depends(auth.require_admin)):
        return {"ok": True}

    engine = create_engine(
        "sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    Base.metadata.create_all(engine)
    try:
        with Session(engine) as db:
            roles = {1: "guest", 2: "host", 3: "admin", 4: "guest"}
            for uid, role in roles.items():
                db.add(models.User(
                    id=uid, name=f"Actor {uid}", email=f"sweep-{uid}@test.invalid",
                    password_hash="unused", role=role, is_active=uid != 4,
                ))
            db.commit()
            app.dependency_overrides[get_db] = lambda: db
            with TestClient(app) as c:
                for uid, role in roles.items():
                    headers = {"Authorization": f"Bearer {auth.sign_token(uid, role)}"}
                    response = c.get("/host-only", headers=headers)
                    assert response.status_code == (403 if uid == 4 else 200)
                    if uid != 4:
                        assert response.json()["role"] == role
                        assert db.get(models.User, uid).role == role
                    if role != "admin":
                        assert c.get("/admin-only", headers=headers).status_code == 403
                missing = {"Authorization": f"Bearer {auth.sign_token(999, 'guest')}"}
                assert c.get("/host-only", headers=missing).status_code == 403
                assert c.get("/host-only").status_code == 401
    finally:
        engine.dispose()


def test_owner_or_admin_helper_blocks_idor():
    """_ensure_owner_or_admin should 403 when actor_id != owner_id (unless admin)."""
    from app.auth import _ensure_owner_or_admin
    from fastapi import HTTPException

    # Same user — passes
    _ensure_owner_or_admin({"sub": 5, "role": "guest"}, 5)
    # Admin on someone else's resource — passes
    _ensure_owner_or_admin({"sub": 99, "role": "admin"}, 5)
    # Guest trying to touch someone else's resource — blocks
    with pytest.raises(HTTPException) as exc:
        _ensure_owner_or_admin({"sub": 5, "role": "guest"}, 6)
    assert exc.value.status_code == 403
