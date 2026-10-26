"""WebSocket connection manager — broadcast event theo user_id."""

import asyncio
from collections import defaultdict
from typing import Any

from fastapi import WebSocket


class Hub:
    def __init__(self):
        self._lock = asyncio.Lock()
        self._clients: dict[int, set[WebSocket]] = defaultdict(set)
        # The domain services are synchronous SQLAlchemy functions and often
        # run in FastAPI's threadpool.  Keep the worker event loop captured by
        # the first WS connection so those services can safely enqueue a
        # broadcast after their transaction commits.
        self._loop: asyncio.AbstractEventLoop | None = None

    async def add(self, user_id: int, ws: WebSocket):
        self._loop = asyncio.get_running_loop()
        async with self._lock:
            self._clients[user_id].add(ws)

    async def remove(self, user_id: int, ws: WebSocket):
        async with self._lock:
            self._clients[user_id].discard(ws)
            if not self._clients[user_id]:
                self._clients.pop(user_id, None)

    def is_online(self, user_id: int) -> bool:
        return bool(self._clients.get(user_id))

    async def send_to(self, user_id: int, event_type: str, payload: Any):
        """Send 1 event đến tất cả ws của user_id."""
        targets = list(self._clients.get(user_id, []))
        if not targets:
            return
        msg = {"type": event_type, "payload": payload}
        for ws in targets:
            try:
                await ws.send_json(msg)
            except Exception:
                # Connection chết — sẽ được clear khi loop next iteration
                pass

    def send_to_sync(self, user_id: int, event_type: str, payload: Any) -> None:
        """Queue a WS event from a synchronous service/threadpool.

        Realtime delivery is best-effort; the persisted notification remains
        the source of truth for reconnects and clients that were offline.
        """
        loop = self._loop
        if loop is None or loop.is_closed() or not self.is_online(user_id):
            return
        try:
            asyncio.run_coroutine_threadsafe(
                self.send_to(user_id, event_type, payload), loop
            )
        except RuntimeError:
            # The server is shutting down or the loop was replaced.
            return


hub = Hub()
