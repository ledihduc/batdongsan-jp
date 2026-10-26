"""Fixture dùng chung cho test Admin V2.

SQLite in-memory + app tối giản chỉ mount router admin_v2. `staff("MODERATOR")`
tạo một nhân viên có đúng vai đó và trả header Bearer của PHIÊN ADMIN thật
(đi qua đường đăng nhập/guard như production).
"""

from __future__ import annotations

import itertools
import uuid
from typing import Generator

import pytest
from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker
from starlette.exceptions import HTTPException as StarletteHTTPException

import app.domain  # noqa: F401 — đăng ký bảng domain (KYC, uỷ quyền…)
import app.models as models
from app.auth import hash_password, sign_token
from app.database import Base, get_db
from app.middleware.error_handler import http_exception_handler, validation_handler
from app.middleware.rate_limit import limiter
from app.services.admin_v2 import rbac, sessions

_ids = itertools.count(91000)
PASSWORD = "matkhau-test-123"
_PW_HASH = hash_password(PASSWORD)


@pytest.fixture(scope="module")
def engine():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})

    @event.listens_for(eng, "connect")
    def _fk(dbapi_conn, _rec):  # pragma: no cover
        dbapi_conn.execute("PRAGMA foreign_keys=OFF")

    Base.metadata.create_all(eng)
    yield eng
    eng.dispose()


@pytest.fixture
def db(engine) -> Generator[Session, None, None]:
    conn = engine.connect()
    tx = conn.begin()
    session = sessionmaker(bind=conn)()
    rbac.ensure_catalog(session)
    session.commit()
    yield session
    session.close()
    tx.rollback()
    conn.close()


@pytest.fixture(autouse=True)
def _no_rate_limit():
    limiter.enabled = False
    yield
    limiter.enabled = True


@pytest.fixture
def app_(db):
    from app.api.routes.admin_v2 import router

    api = FastAPI()
    api.add_exception_handler(RequestValidationError, validation_handler)
    api.add_exception_handler(StarletteHTTPException, http_exception_handler)
    api.state.limiter = limiter
    api.include_router(router)

    def override():
        yield db

    api.dependency_overrides[get_db] = override
    return api


@pytest.fixture
def client(app_):
    with TestClient(app_) as c:
        yield c


def make_user(db: Session, *, name="Người dùng", role="guest", active=True, **kw) -> models.User:
    uid = next(_ids)
    u = models.User(
        id=uid, name=name, email=kw.pop("email", f"u{uid}@test.vn"), phone=kw.pop("phone", f"09{uid:08d}"),
        password_hash=_PW_HASH, role=role, is_active=active, **kw,
    )
    db.add(u)
    db.commit()
    return u


@pytest.fixture
def user(db):
    def _make(**kw):
        return make_user(db, **kw)

    return _make


@pytest.fixture
def staff(db):
    """staff("MODERATOR", "FINANCE") → (user, headers) với phiên admin thật."""

    def _make(*roles: str, name: str | None = None, reauth: bool = True):
        u = make_user(db, name=name or "+".join(roles))
        for r in roles:
            rbac.grant_role(db, user_id=u.id, role_code=r, granted_by=None, reason="test")
        s = sessions.open_session(db, user_id=u.id, ip_hash=None, user_agent="pytest")
        if not reauth:
            s.reauth_at = None
        db.commit()
        token = sessions.sign_admin_token(u.id, s.id, s.expires_at)
        return u, {"Authorization": f"Bearer {token}"}

    return _make


def key() -> str:
    return f"test-{uuid.uuid4().hex}"


def w(headers: dict, version: str | None = None) -> dict:
    """Header cho lệnh ghi: thêm Idempotency-Key (+ If-Match)."""
    out = {**headers, "Idempotency-Key": key()}
    if version is not None:
        out["If-Match"] = version
    return out


def app_token(u: models.User) -> dict:
    return {"Authorization": f"Bearer {sign_token(u.id, u.role, u.password_changed_at)}"}
