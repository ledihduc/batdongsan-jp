"""Nominatim JP geocoding client — httpx async with rate limiting.

Design decisions:
  - User-Agent identifies us per Nominatim usage policy.
  - 10-second timeout on all requests.
  - Single-flight per address string (asyncio.Lock keyed by normalized address).
  - Global 1 req/s rate limiting (asyncio.Semaphore + time tracking).
  - Returns None on lookup failure instead of raising (caller decides fallback).

Public Nominatim endpoint: https://nominatim.openstreetmap.org
Usage policy: https://operations.osmfoundation.org/policies/nominatim/

In P4: replace with self-hosted Nominatim behind VPC.
"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

_NOMINATIM_BASE = "https://nominatim.openstreetmap.org"
_USER_AGENT = "Ancu365/1.0 (ops@ancu365.com)"
_TIMEOUT_S = 10.0
_MIN_INTERVAL_S = 1.0  # Global 1 req/s floor

# Global rate limiter state
_last_request_time: float = 0.0
_rate_lock = asyncio.Lock()

# Per-address in-flight deduplication
_flight_locks: dict[str, asyncio.Lock] = {}
_flight_locks_meta = asyncio.Lock()  # guards _flight_locks dict


async def _acquire_rate_limit() -> None:
    """Enforce global 1 req/s rate limit."""
    global _last_request_time
    async with _rate_lock:
        now = time.monotonic()
        elapsed = now - _last_request_time
        if elapsed < _MIN_INTERVAL_S:
            await asyncio.sleep(_MIN_INTERVAL_S - elapsed)
        _last_request_time = time.monotonic()


async def _get_flight_lock(key: str) -> asyncio.Lock:
    """Get or create a per-key flight lock (single-flight dedup)."""
    async with _flight_locks_meta:
        if key not in _flight_locks:
            _flight_locks[key] = asyncio.Lock()
        return _flight_locks[key]


async def geocode_address(address: str) -> Optional[dict]:
    """Look up a JP address via Nominatim and return the first result.

    Args:
        address: Free-form address string (e.g. "東京都渋谷区神南1丁目").

    Returns:
        Dict with keys: lat, lon, display_name, address (Nominatim address dict).
        Returns None on lookup failure, timeout, or no results.
    """
    normalized = address.strip()
    if not normalized:
        return None

    # Single-flight: only one concurrent request per unique address
    lock = await _get_flight_lock(normalized)
    async with lock:
        return await _do_geocode(normalized)


async def _do_geocode(address: str) -> Optional[dict]:
    """Execute the actual Nominatim HTTP request."""
    await _acquire_rate_limit()

    params = {
        "q": address,
        "format": "jsonv2",
        "countrycodes": "jp",
        "limit": 1,
        "addressdetails": 1,
    }

    try:
        async with httpx.AsyncClient(
            headers={"User-Agent": _USER_AGENT},
            timeout=httpx.Timeout(_TIMEOUT_S),
        ) as client:
            resp = await client.get(f"{_NOMINATIM_BASE}/search", params=params)
            resp.raise_for_status()
            results = resp.json()

    except httpx.TimeoutException:
        logger.warning("Nominatim timeout: address=%r", address)
        return None
    except httpx.HTTPStatusError as exc:
        logger.warning("Nominatim HTTP error: status=%d address=%r", exc.response.status_code, address)
        return None
    except Exception as exc:
        logger.error("Nominatim unexpected error: %s address=%r", exc, address)
        return None

    if not results:
        logger.debug("Nominatim: no results for address=%r", address)
        return None

    hit = results[0]
    return {
        "lat": float(hit.get("lat", 0)),
        "lon": float(hit.get("lon", 0)),
        "display_name": hit.get("display_name", ""),
        "address": hit.get("address", {}),
    }
