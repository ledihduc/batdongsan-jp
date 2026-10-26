"""Contextvars mang request-id / user-hash xuyên suốt một request async."""

from __future__ import annotations

from contextvars import ContextVar

request_id_var: ContextVar[str | None] = ContextVar("request_id", default=None)
user_hash_var: ContextVar[str | None] = ContextVar("user_hash", default=None)
route_var: ContextVar[str | None] = ContextVar("route", default=None)
