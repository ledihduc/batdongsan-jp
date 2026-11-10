"""Handler `rest`: action trỏ `(method, path)` của chính app, gọi in-process qua ASGI (T6, AC15).

Request đi qua toàn bộ middleware + dependency như request thật, không mở cổng mạng.
Chỉ endpoint trong `settings.ai_rest_whitelist`; mọi path phải dưới `/api/` và không
dưới `/api/ai/` (không gọi lại chat/xác nhận). `Authorization` chuyển tiếp nguyên văn.
"""

from __future__ import annotations

import asyncio
import re
from typing import TYPE_CHECKING, Iterable, Optional
from urllib.parse import quote

import httpx

from app.ai_capabilities.action_errors import ActionError
from app.ai_capabilities.context import ActionContext
from app.config import settings

if TYPE_CHECKING:
    from app.ai_capabilities.loader import HandlerSpec

REST_MAX_RESPONSE_BYTES = 50_000
PATH_PARAM_RE = re.compile(r"\{([a-z_][a-z0-9_]*)\}")
_INTERNAL_BASE_URL = "http://ai-internal"
_STATUS_CODES = {401: "login_required", 403: "login_required", 404: "not_found", 422: "invalid_arguments",
                 429: "rate_limited"}


def parse_rest_whitelist(entries: Iterable[str]) -> frozenset[tuple[str, str]]:
    """`"GET /api/jp/listings"` ⇒ `("GET", "/api/jp/listings")`. Mục sai dạng ⇒ ValueError (QA L4)."""
    pairs = set()
    for entry in entries:
        method, _, path = entry.strip().partition(" ")
        path = path.strip()
        if not method or not path.startswith("/"):
            raise ValueError(f"AI_REST_WHITELIST entry must be 'METHOD /path': {entry!r}")
        pairs.add((method.upper(), path))
    return frozenset(pairs)


def rest_path_allowed(path: str) -> bool:
    return path.startswith("/api/") and not path.startswith("/api/ai/")


def _default_whitelist() -> frozenset[tuple[str, str]]:
    return parse_rest_whitelist(settings.ai_rest_whitelist)


def _query_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, list):
        return ",".join(str(v) for v in value)
    return value


def _path_value(value) -> str:
    text = str(value)
    # quote() để nguyên "." / ".." ⇒ chuẩn hoá URL sẽ nhảy đoạn path (QA M1).
    if text in ("", ".", ".."):
        raise ActionError("invalid_arguments", f"invalid path param value {text!r}")
    return quote(text, safe="")


def _build_request(handler: "HandlerSpec", params: dict) -> tuple[str, dict]:
    rest = dict(params)
    path = PATH_PARAM_RE.sub(lambda m: _path_value(rest.pop(m.group(1))), handler.path)
    if not rest_path_allowed(path):  # giá trị thay vào không được đưa path vào /api/ai/ (QA M1)
        raise ActionError("endpoint_not_allowed", "resolved path is not allowed")
    if handler.method == "GET":
        return path, {"params": {k: _query_value(v) for k, v in rest.items() if v is not None}}
    return path, {"json": rest}


def _error_detail(resp: httpx.Response) -> str:
    """Câu lỗi ngắn từ body 422 để model tự sửa tham số (QA M2); không đọc được ⇒ rỗng."""
    try:
        detail = resp.json().get("detail")
    except (ValueError, AttributeError):
        return ""
    if isinstance(detail, list) and detail and isinstance(detail[0], dict):
        loc = ".".join(str(p) for p in detail[0].get("loc", [])[1:])
        return f"{loc}: {detail[0].get('msg', '')}".strip(": ")
    if isinstance(detail, dict):
        return str(detail.get("message", ""))
    return detail if isinstance(detail, str) else ""


def _decode(resp: httpx.Response) -> dict:
    if resp.status_code >= 400:
        message = f"upstream status {resp.status_code}"
        if resp.status_code == 422 and (detail := _error_detail(resp)):
            message = f"{message}: {detail}"[:300]
        raise ActionError(_STATUS_CODES.get(resp.status_code, "upstream_error"), message)
    if len(resp.content) > REST_MAX_RESPONSE_BYTES:
        raise ActionError("upstream_error", "upstream response too large")
    try:
        body = resp.json()
    except ValueError as exc:
        raise ActionError("upstream_error", "upstream response is not JSON") from exc
    if isinstance(body, list):
        return {"items": body}
    if not isinstance(body, dict):
        raise ActionError("upstream_error", "upstream response is not an object")
    return body


async def call_rest(
    handler: "HandlerSpec", params: dict, ctx: ActionContext, *, timeout_s: float,
    whitelist: Optional[frozenset[tuple[str, str]]] = None,
) -> dict:
    allowed = _default_whitelist() if whitelist is None else whitelist
    # Kiểm lại lúc gọi (phòng thủ 2 lớp): không tin riêng loader đã chặn.
    if (handler.method, handler.path) not in allowed or not rest_path_allowed(handler.path):
        raise ActionError("endpoint_not_allowed", f"{handler.method} {handler.path} is not allowed")
    if ctx.asgi_app is None:
        raise ActionError("upstream_error", "rest handler needs the app")
    try:
        path, kwargs = _build_request(handler, params)
    except KeyError as exc:  # loader đã bắt {x} phải required — chỉ tới đây khi registry bị lách
        raise ActionError("invalid_arguments", f"missing path param {exc.args[0]}") from exc
    headers = {"authorization": ctx.authorization} if ctx.authorization else {}
    transport = httpx.ASGITransport(app=ctx.asgi_app, raise_app_exceptions=False)
    async with httpx.AsyncClient(transport=transport, base_url=_INTERNAL_BASE_URL) as client:
        try:
            # ASGITransport bỏ qua timeout của httpx ⇒ chặn trần bằng wait_for.
            resp = await asyncio.wait_for(client.request(handler.method, path, headers=headers, **kwargs), timeout_s)
        except asyncio.TimeoutError as exc:
            raise ActionError("upstream_error", "upstream timeout") from exc
    return _decode(resp)
