"""Integration tests: RequestContextMiddleware + /api/client-logs endpoint.

Dựng app FastAPI tối thiểu (không đụng main.py / DB) — mirror cách
tests/conftest.py build test app cho planning.
"""

from __future__ import annotations

import base64
import json
import logging

import pytest
from fastapi import FastAPI
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from starlette.testclient import TestClient

from app.middleware.rate_limit import limiter
from app.observability.context import request_id_var, user_hash_var
from app.observability.middleware import RequestContextMiddleware, _hash_user
from app.routers import client_logs as client_logs_module
from app.routers.client_logs import router as client_logs_router


def _make_jwt(payload: dict) -> str:
    """JWT giả (không ký thật) — middleware chỉ base64-decode payload, không verify."""
    def b64(raw: bytes) -> str:
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

    header = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    body = b64(json.dumps(payload).encode())
    return f"{header}.{body}.sig-not-verified"


# ── Middleware ───────────────────────────────────────────────────────────────

@pytest.fixture()
def mw_client() -> TestClient:
    app = FastAPI()
    app.add_middleware(RequestContextMiddleware, hash_salt="testsalt")

    @app.get("/ping")
    def ping() -> dict:
        return {"rid": request_id_var.get(), "uh": user_hash_var.get()}

    return TestClient(app)


class TestRequestContextMiddleware:
    def test_request_id_passthrough(self, mw_client: TestClient) -> None:
        r = mw_client.get("/ping", headers={"X-Request-ID": "fixedid00000abcd"})
        assert r.status_code == 200
        assert r.headers["X-Request-ID"] == "fixedid00000abcd"
        assert r.json()["rid"] == "fixedid00000abcd"

    def test_request_id_generated_when_absent(self, mw_client: TestClient) -> None:
        r = mw_client.get("/ping")
        rid = r.headers["X-Request-ID"]
        assert len(rid) == 16
        assert r.json()["rid"] == rid

    def test_user_hash_derived_from_jwt(self, mw_client: TestClient) -> None:
        token = _make_jwt({"sub": "42"})
        r = mw_client.get("/ping", headers={"Authorization": f"Bearer {token}"})
        assert r.json()["uh"] == _hash_user("42", "testsalt")

    def test_no_user_hash_without_bearer(self, mw_client: TestClient) -> None:
        assert mw_client.get("/ping").json()["uh"] is None

    def test_hash_user_deterministic_12_hex(self) -> None:
        h = _hash_user("42", "testsalt")
        assert h == _hash_user("42", "testsalt")
        assert len(h) == 12
        int(h, 16)


# ── /api/client-logs ─────────────────────────────────────────────────────────

@pytest.fixture()
def logs_client() -> TestClient:
    app = FastAPI()
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    app.include_router(client_logs_router)
    return TestClient(app)


@pytest.fixture()
def capture_client_logs():
    records: list[logging.LogRecord] = []

    class _Grab(logging.Handler):
        def emit(self, record: logging.LogRecord) -> None:
            records.append(record)

    logger = logging.getLogger("app.client")
    handler = _Grab()
    logger.addHandler(handler)
    prev_level = logger.level
    logger.setLevel(logging.DEBUG)
    try:
        yield records
    finally:
        logger.removeHandler(handler)
        logger.setLevel(prev_level)


class TestClientLogsEndpoint:
    def test_returns_204(self, logs_client: TestClient) -> None:
        r = logs_client.post(
            "/api/client-logs",
            json={"level": "error", "message": "boom", "error_type": "E"},
        )
        assert r.status_code == 204

    def test_message_is_redacted_before_log(
        self, logs_client: TestClient, capture_client_logs
    ) -> None:
        logs_client.post(
            "/api/client-logs",
            json={"level": "error", "message": "crash for secret@x.com"},
        )
        assert capture_client_logs, "expected a captured log record"
        rec = capture_client_logs[-1]
        assert "secret@x.com" not in rec.getMessage()
        assert getattr(rec, "event", None) == "client_error"
        assert getattr(rec, "fingerprint", None)

    def test_disabled_flag_skips_logging(
        self, logs_client: TestClient, capture_client_logs, monkeypatch
    ) -> None:
        monkeypatch.setattr(
            client_logs_module.settings, "client_logs_enabled", False, raising=False
        )
        r = logs_client.post(
            "/api/client-logs", json={"level": "error", "message": "boom"}
        )
        assert r.status_code == 204
        assert not capture_client_logs
