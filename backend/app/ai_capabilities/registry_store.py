"""Giữ registry hiện hành, nạp lại khi file đổi (D15, T12, AC5).

Mỗi `current()` chỉ 1 `os.stat`; dấu `(st_mtime_ns, st_size)` đổi ⇒ nạp lại. Nạp lỗi
hoặc file bị xoá ⇒ giữ bản cũ + log `ai_registry_reload_failed` (nhớ dấu của file hỏng
nên không parse lại mỗi request). Lần nạp đầu lỗi ⇒ ném `RegistryError` (fail-fast).
Backend 1 tiến trình uvicorn (F25) ⇒ 1 store mỗi tiến trình là đủ.
"""

from __future__ import annotations

import logging
import os
import pathlib
import threading
from functools import lru_cache
from typing import Callable, Optional

from app.ai_capabilities.loader import Registry, load_registry, load_region_registry, registry_path_for
from app.config import settings

logger = logging.getLogger(__name__)

Signature = Optional[tuple[int, int]]


def _signature(path: pathlib.Path) -> Signature:
    try:
        st = os.stat(path)
    except OSError:
        return None
    return st.st_mtime_ns, st.st_size


class RegistryStore:
    def __init__(
        self, path, *, loader: Callable[[pathlib.Path], Registry] = load_registry,
    ) -> None:
        self._path = pathlib.Path(path)
        self._loader = loader
        self._lock = threading.Lock()
        self._sig = _signature(self._path)
        self._registry = loader(self._path)
        self._last_error: Optional[str] = None

    @property
    def last_error(self) -> Optional[str]:
        return self._last_error

    def current(self) -> Registry:
        sig = _signature(self._path)
        if sig == self._sig:
            return self._registry
        with self._lock:
            if sig != self._sig:
                self._sig = sig
                self._reload(sig)
            return self._registry

    def _reload(self, sig: Signature) -> None:
        if sig is None:
            self._fail("registry file missing")
            return
        try:
            registry = self._loader(self._path)
        except Exception as exc:  # noqa: BLE001 — mọi lỗi nạp lại đều giữ bản cũ
            self._fail(str(exc)[:500])
            return
        self._registry = registry
        self._last_error = None
        logger.info("ai_registry_reloaded", extra={
            "event": "ai_registry_reloaded", "actions": registry.names(),
            "version": registry.version, "path": str(self._path),
        })

    def _fail(self, message: str) -> None:
        self._last_error = message
        logger.warning("ai_registry_reload_failed", extra={
            "event": "ai_registry_reload_failed", "error": message,
            "path": str(self._path), "kept_version": self._registry.version,
        })


@lru_cache(maxsize=1)
def get_registry_store() -> RegistryStore:
    return RegistryStore(registry_path_for(settings.region), loader=load_region_registry)
