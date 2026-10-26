"""
RequestContextMiddleware — gán request-id, đo latency, log mọi request.

- Sinh/nhận `X-Request-ID`, đưa vào contextvar để mọi log trong request có id.
- Suy ra `user_hash` (sha256 có salt của 'sub' trong JWT — KHÔNG lưu user id thô).
- Log 1 dòng/request khi hoàn tất: method, path, status, latency_ms.
- KHÔNG log query string (có thể chứa PII); path đi qua RedactionFilter.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import json
import logging
import re
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.observability.context import request_id_var, route_var, user_hash_var

_logger = logging.getLogger("app.request")

_ID_SEG_RE = re.compile(r"/\d+(?=/|$)")


def _hash_user(sub: str, salt: str) -> str:
    return hashlib.sha256(f"{salt}:{sub}".encode()).hexdigest()[:12]


def _extract_user_hash(request: Request, salt: str) -> str | None:
    """Giải mã phần payload JWT (KHÔNG verify — chỉ để tương quan log)."""
    auth = request.headers.get("authorization") or ""
    if not auth.lower().startswith("bearer "):
        return None
    token = auth[7:].strip()
    parts = token.split(".")
    if len(parts) != 3:
        return None
    try:
        payload_b64 = parts[1] + "=" * (-len(parts[1]) % 4)
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))
    except (binascii.Error, ValueError, json.JSONDecodeError):
        return None
    sub = payload.get("sub") or payload.get("user_id") or payload.get("id")
    if sub is None:
        return None
    return _hash_user(str(sub), salt)


class RequestContextMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, *, hash_salt: str = "ancu365"):
        super().__init__(app)
        self._salt = hash_salt

    async def dispatch(self, request: Request, call_next):
        rid = request.headers.get("x-request-id") or uuid.uuid4().hex[:16]
        route_tmpl = _ID_SEG_RE.sub("/{id}", request.url.path)
        tok_r = request_id_var.set(rid)
        tok_route = route_var.set(route_tmpl)
        tok_u = user_hash_var.set(_extract_user_hash(request, self._salt))

        start = time.perf_counter()
        status = 500
        try:
            response: Response = await call_next(request)
            status = response.status_code
            response.headers["X-Request-ID"] = rid
            return response
        finally:
            latency_ms = round((time.perf_counter() - start) * 1000, 1)
            level = (
                logging.ERROR
                if status >= 500
                else logging.WARNING
                if status >= 400
                else logging.INFO
            )
            _logger.log(
                level,
                "request",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "route": route_tmpl,
                    "status": status,
                    "latency_ms": latency_ms,
                    "event": "http_request",
                },
            )
            request_id_var.reset(tok_r)
            route_var.reset(tok_route)
            user_hash_var.reset(tok_u)
