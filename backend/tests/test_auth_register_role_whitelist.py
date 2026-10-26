"""Tests: POST /register role whitelist (AC4).

Verifies that supplying role=admin or role=host in the registration body
results in user.role='guest' in the DB — never admin/host.
"""

from __future__ import annotations

import os
import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


def _build_auth_app(session_factory):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.database import get_db
    from app.routers.auth_router import router as auth_router

    app = FastAPI()
    app.include_router(auth_router)

    def _override():
        db = session_factory()
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = _override
    return TestClient(app, raise_server_exceptions=False)


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_register_with_role_admin_is_ignored(pg_session):
    """POST /api/auth/register with role=admin → DB stores role=guest."""
    import random

    def _factory():
        return pg_session

    client = _build_auth_app(_factory)
    email = f"attacker_{random.randint(10000,99999)}@evil.com"
    resp = client.post(
        "/api/auth/register",
        json={
            "name": "Attacker",
            "email": email,
            "password": "password123",
            "role": "admin",  # attempted privilege escalation
        },
    )
    assert resp.status_code == 201, f"Register failed: {resp.text}"
    data = resp.json()
    assert data["user"]["role"] == "guest", (
        f"Expected role=guest, got {data['user']['role']}"
    )
    assert data["user"]["account_type"] == "customer"


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_register_with_role_host_is_ignored(pg_session):
    """POST /api/auth/register with role=host → DB stores role=guest."""
    import random

    def _factory():
        return pg_session

    client = _build_auth_app(_factory)
    email = f"wannabehost_{random.randint(10000,99999)}@test.com"
    resp = client.post(
        "/api/auth/register",
        json={
            "name": "Wanna Be Host",
            "email": email,
            "password": "password123",
            "role": "host",
        },
    )
    assert resp.status_code == 201, f"Register failed: {resp.text}"
    data = resp.json()
    assert data["user"]["role"] == "guest", (
        f"Expected role=guest, got {data['user']['role']}"
    )


@pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"),
    reason="SMOKE_DATABASE_URL not set",
)
def test_change_password_uses_jwt_sub(pg_session):
    """POST /api/auth/change-password with body.user_id for another user → only own pwd changes."""
    from app import models, auth as app_auth
    import random
    import datetime

    # Create victim user
    victim = models.User(
        name="Victim",
        email=f"victim_{random.randint(10000,99999)}@test.com",
        password_hash=app_auth.hash_password("victimpass"),
        role="guest",
        is_active=True,
        created_at=datetime.datetime.utcnow(),
    )
    pg_session.add(victim)
    pg_session.flush()

    # Create attacker user
    attacker = models.User(
        name="Attacker",
        email=f"attacker_{random.randint(10000,99999)}@test.com",
        password_hash=app_auth.hash_password("attackerpass"),
        role="guest",
        is_active=True,
        created_at=datetime.datetime.utcnow(),
    )
    pg_session.add(attacker)
    pg_session.flush()

    attacker_token = app_auth.sign_token(attacker.id, "guest")

    def _factory():
        return pg_session

    client = _build_auth_app(_factory)
    # Attacker supplies victim's user_id in body — should be ignored
    resp = client.post(
        "/api/auth/change-password",
        json={
            "user_id": victim.id,  # IDOR attempt — should be ignored
            "old_password": "attackerpass",
            "new_password": "hacked123",
        },
        headers={"Authorization": f"Bearer {attacker_token}"},
    )
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {resp.text}"

    # Victim's password should be unchanged
    pg_session.refresh(victim)
    assert app_auth.verify_password("victimpass", victim.password_hash), (
        "Victim password was changed — IDOR vulnerability present!"
    )
