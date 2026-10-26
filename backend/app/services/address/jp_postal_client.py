"""HTTP client for 日本郵便 zipcloud postal code lookup API.

Endpoint: https://zipcloud.ibsnet.co.jp/api/search?zipcode=<7-digit>
No API key required. Free public API.

Security controls (per phase-00 spec):
  - postal_code validated by regex `^\\d{3}-?\\d{4}$` before use in URL.
  - No user input injected into URL except the regex-validated postal code.
  - 5-second timeout on all HTTP requests.
  - No PII in logs.

Caching:
  - 15-minute in-memory TTL cache keyed by normalized postal code.
  - Cache is module-level (singleton per process) — simple TTLCache from cachetools.
  - If cachetools not installed, falls back to a simple dict cache (no TTL).

Response format from zipcloud:
  {
    "message": null,
    "results": [
      {
        "address1": "東京都",        // prefecture
        "address2": "渋谷区",        // city
        "address3": "神南",          // town
        "kana1": "ﾄｳｷｮｳﾄ",
        "kana2": "ｼﾌﾞﾔｸ",
        "kana3": "ｼﾞﾝﾅﾝ",
        "prefcode": "13",
        "zipcode": "1500001"
      }
    ],
    "status": 200
  }
  When no result: "results": null.
"""

from __future__ import annotations

import logging
import re
import time
from typing import Any, Optional

import httpx

logger = logging.getLogger(__name__)

# Regex for Japanese postal codes: 7 digits, optional hyphen in position 3-4.
_POSTAL_RE = re.compile(r"^\d{3}-?\d{4}$")

# zipcloud API base URL — no API key, public endpoint.
_ZIPCLOUD_URL = "https://zipcloud.ibsnet.co.jp/api/search"

# HTTP timeout in seconds (per spec).
_TIMEOUT_S = 5.0

# Cache TTL in seconds: 15 minutes.
_CACHE_TTL_S = 15 * 60

# ---------------------------------------------------------------------------
# Simple TTL cache — avoids mandatory cachetools dependency.
# Thread-safety: GIL protects dict reads; worst case is a duplicate API call
# on concurrent first-access (acceptable, idempotent).
# ---------------------------------------------------------------------------
_cache: dict[str, tuple[float, list[dict[str, Any]]]] = {}


def _cache_get(key: str) -> Optional[list[dict[str, Any]]]:
    """Return cached value if it exists and has not expired."""
    entry = _cache.get(key)
    if entry is None:
        return None
    stored_at, value = entry
    if time.monotonic() - stored_at > _CACHE_TTL_S:
        del _cache[key]
        return None
    return value


def _cache_set(key: str, value: list[dict[str, Any]]) -> None:
    """Store value in cache with current timestamp."""
    _cache[key] = (time.monotonic(), value)


def _normalize_postal_code(postal_code: str) -> str:
    """Remove hyphen and return 7-digit normalized code.

    Args:
        postal_code: Raw string from caller (e.g. '150-0001' or '1500001').

    Returns:
        7-digit string without hyphen (e.g. '1500001').
    """
    return postal_code.replace("-", "")


def validate_postal_code(postal_code: str) -> bool:
    """Return True if postal_code matches the expected JP format.

    Accepts:
      - 7 digits without hyphen: '1500001'
      - 7 digits with hyphen at position 3: '150-0001'

    Args:
        postal_code: Raw string to validate.

    Returns:
        True if valid, False otherwise.
    """
    return bool(_POSTAL_RE.match(postal_code.strip()))


def _parse_results(raw_results: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Map zipcloud response fields to our internal schema field names.

    zipcloud field mapping:
      address1 → prefecture
      address2 → city
      address3 → town
      kana1    → prefecture_kana
      kana2    → city_kana
      kana3    → town_kana
      zipcode  → postal_code
    """
    out = []
    for r in raw_results:
        out.append(
            {
                "postal_code": r.get("zipcode", ""),
                "prefecture": r.get("address1") or None,
                "city": r.get("address2") or None,
                "town": r.get("address3") or None,
                "chome": None,  # zipcloud does not return chome
                "banchi": None,
                "go": None,
                "building": None,
                "prefecture_kana": r.get("kana1") or None,
                "city_kana": r.get("kana2") or None,
                "town_kana": r.get("kana3") or None,
            }
        )
    return out


async def lookup_postal_code(
    postal_code: str,
) -> list[dict[str, Any]]:
    """Look up a Japanese postal code via zipcloud API with in-memory TTL cache.

    Security: postal_code is validated by regex before URL construction.
    No other user input touches the URL.

    Args:
        postal_code: JP postal code (format: '1500001' or '150-0001').

    Returns:
        List of address candidate dicts (may be empty if code not found).

    Raises:
        ValueError: If postal_code fails regex validation.
        httpx.HTTPError: On network failure (callers should handle).
        httpx.TimeoutException: On timeout.
    """
    postal_code = postal_code.strip()

    if not validate_postal_code(postal_code):
        raise ValueError(
            f"Invalid JP postal code format: '{postal_code}'. "
            "Expected 7 digits (e.g. '1500001' or '150-0001')."
        )

    normalized = _normalize_postal_code(postal_code)

    # Check in-memory cache first.
    cached = _cache_get(normalized)
    if cached is not None:
        logger.debug("jp_postal_client: cache hit for %s", normalized)
        return cached

    # Build URL with validated + normalized postal code only.
    params = {"zipcode": normalized}

    logger.info("jp_postal_client: fetching postal_code=%s from zipcloud", normalized)

    async with httpx.AsyncClient(timeout=_TIMEOUT_S) as client:
        response = await client.get(_ZIPCLOUD_URL, params=params)
        response.raise_for_status()

    payload: dict[str, Any] = response.json()

    raw_results = payload.get("results") or []
    candidates = _parse_results(raw_results)

    # Store in cache regardless of empty results (negative caching avoids hammering
    # the API for invalid codes sent repeatedly by clients).
    _cache_set(normalized, candidates)

    logger.info(
        "jp_postal_client: postal_code=%s → %d candidate(s)",
        normalized,
        len(candidates),
    )
    return candidates
