"""Hạn mức MCP trong bộ nhớ: tổng request + theo khoá tool/action, cửa sổ cố định 60 s (T9).

Không đếm theo IP: Claude.ai/ChatGPT dùng chung IP egress (X5). Backend 1 tiến trình (F25)
nên bộ đếm trong bộ nhớ là đủ; mất khi restart — chấp nhận cho PoC.
"""

from __future__ import annotations

import threading
import time
from typing import Callable

WINDOW_S = 60.0


class McpRateLimiter:
    def __init__(
        self, total_per_min: int, per_key_per_min: int, clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._total_limit = total_per_min
        self._key_limit = per_key_per_min
        self._clock = clock
        self._lock = threading.Lock()
        self._window_start = clock()
        self._total = 0
        self._per_key: dict[str, int] = {}

    def _roll_window(self) -> None:
        """Gọi khi đang giữ lock: hết 60 s ⇒ mở cửa sổ mới, xoá mọi bộ đếm."""
        now = self._clock()
        if now - self._window_start >= WINDOW_S:
            self._window_start = now
            self._total = 0
            self._per_key.clear()

    def allow_request(self) -> bool:
        """Mỗi POST /mcp gọi 1 lần; False ⇒ trả 429."""
        with self._lock:
            self._roll_window()
            if self._total >= self._total_limit:
                return False
            self._total += 1
            return True

    def allow_key(self, key: str) -> bool:
        """Mỗi tools/call gọi 1 lần với khoá `get_system_skills` | `run_action:<action>`."""
        with self._lock:
            self._roll_window()
            count = self._per_key.get(key, 0)
            if count >= self._key_limit:
                return False
            self._per_key[key] = count + 1
            return True
