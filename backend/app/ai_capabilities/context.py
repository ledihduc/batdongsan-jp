"""Ngữ cảnh một lần gọi action — kênh gọi, người dùng, dữ liệu cho handler rest/ghi (P06, P09)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal, Optional


@dataclass(frozen=True)
class ActionContext:
    channel: Literal["mcp", "chat", "confirm"]
    user: Optional[dict] = None  # claims của app.auth.optional_user/require_user (sub: int, role)
    authorization: Optional[str] = field(default=None, repr=False)  # header "Bearer …" nguyên văn — chỉ handler rest chuyển tiếp (P06)
    asgi_app: Any = None  # app chủ (request.app) — handler rest gọi in-process (P06)
    dry_run: bool = False  # handler ghi: chỉ kiểm, không ghi (P09)
