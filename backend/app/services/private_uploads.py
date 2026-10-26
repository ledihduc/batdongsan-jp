"""Cổng chặn `/uploads` cho chứng từ đã chuyển vào kho riêng.

`/uploads` là mount tĩnh: ai có link là xem được. Chứng từ riêng tư cũ (hợp
đồng, ảnh cọc…) nằm chung ở đó. Script `scripts/migrate_private_uploads.py`
chép chúng sang kho riêng và ghi tên cũ vào `private_documents.legacy_upload_name`.
Khi bật `PRIVATE_UPLOADS_ENFORCED`, đúng các tên đó trả 404 ở `/uploads`; ảnh tin
đăng, avatar… (không đăng ký) vẫn phục vụ như cũ.

Cờ TẮT mặc định → hành vi giống hệt StaticFiles gốc. Danh sách chặn cache ~30s;
bảng chưa có / DB lỗi thì KHÔNG làm sập phục vụ ảnh (giữ danh sách cũ).
"""

from __future__ import annotations

import logging
import os
import threading
import time
from typing import Callable, Optional

from starlette.concurrency import run_in_threadpool
from starlette.exceptions import HTTPException
from starlette.staticfiles import StaticFiles

logger = logging.getLogger(__name__)

CACHE_SECONDS = 30.0

_lock = threading.Lock()
_cache: dict = {"names": frozenset(), "loaded_at": 0.0}


def enforced() -> bool:
    try:
        from app.config import settings

        if getattr(settings, "private_uploads_enforced", False):
            return True
    except Exception:  # noqa: BLE001
        pass
    return os.getenv("PRIVATE_UPLOADS_ENFORCED", "").strip().lower() in ("1", "true", "yes", "on")


def _load_from_db() -> frozenset:
    from sqlalchemy import text

    from app.database import SessionLocal

    db = SessionLocal()
    try:
        rows = db.execute(text(
            "SELECT legacy_upload_name FROM private_documents WHERE legacy_upload_name IS NOT NULL"
        )).fetchall()
        return frozenset(str(r[0]) for r in rows if r[0])
    finally:
        db.close()


#: Có thể thay trong test.
loader: Callable[[], frozenset] = _load_from_db


def denied_names(now: Optional[float] = None) -> frozenset:
    now = time.monotonic() if now is None else now
    if now - _cache["loaded_at"] < CACHE_SECONDS:
        return _cache["names"]
    with _lock:
        if now - _cache["loaded_at"] < CACHE_SECONDS:
            return _cache["names"]
        try:
            _cache["names"] = loader()
        except Exception as exc:  # noqa: BLE001 — bảng chưa migrate / DB chập chờn
            logger.warning("private_uploads: không nạp được danh sách chặn: %s", exc)
        _cache["loaded_at"] = now
        return _cache["names"]


def reset_cache() -> None:
    with _lock:
        _cache["names"] = frozenset()
        _cache["loaded_at"] = 0.0


def is_blocked(path: str) -> bool:
    name = os.path.basename((path or "").replace("\\", "/"))
    return bool(name) and name in denied_names()


class GatedUploadsStaticFiles(StaticFiles):
    """StaticFiles cho `/uploads` — 404 các tên đã chuyển vào kho riêng khi bật cờ."""

    async def get_response(self, path: str, scope):
        if enforced() and await run_in_threadpool(is_blocked, path):
            raise HTTPException(status_code=404)
        return await super().get_response(path, scope)
