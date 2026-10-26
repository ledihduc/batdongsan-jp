"""Geocoding resolver — postal → Nominatim chain with 7-day cache.

Resolution order:
  1. Try 日本郵便 zipcloud (existing jp_postal_client.py).
  2. If postal lookup returns no results, try Nominatim on the address string.
  3. Cache successful Nominatim results via JpAddress upsert (7-day TTL tracked by updated_at).

Cache design:
  JpAddress table already exists (migration 0141). We use updated_at to track
  freshness — if updated_at + 7d < now, we re-query.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

_CACHE_TTL_DAYS = 7


def _cache_fresh(updated_at: Optional[datetime]) -> bool:
    """Return True if the cache entry is within the 7-day TTL."""
    if updated_at is None:
        return False
    now = datetime.now(timezone.utc)
    if updated_at.tzinfo is None:
        updated_at = updated_at.replace(tzinfo=timezone.utc)
    return (now - updated_at) < timedelta(days=_CACHE_TTL_DAYS)


def lookup_postal(postal_code: str, db: Session) -> Optional[dict]:
    """Try postal lookup via existing jp_postal_client.

    Returns the first result dict or None if not found.
    """
    try:
        from app.services.address.jp_postal_client import lookup as postal_lookup
        result = postal_lookup(postal_code)
        return result
    except Exception as exc:
        logger.warning("Postal lookup failed: %s", exc)
        return None


async def lookup(
    address_or_postal: str,
    db: Session,
) -> Optional[dict]:
    """Resolve an address to lat/lon via postal first, then Nominatim.

    Caches Nominatim results in jp_addresses (7-day TTL).

    Args:
        address_or_postal: Postal code (e.g. "150-0001") or free-form address.
        db:                SQLAlchemy session for cache upsert.

    Returns:
        Dict with: lat, lon, display_name, source ('postal'|'nominatim'|'cache').
        Returns None if both lookups fail.
    """
    from app.domain.jp.address import JpAddress

    normalized = address_or_postal.strip()
    if not normalized:
        return None

    # Check cache first (jp_addresses keyed by postal_code or display_name)
    existing = (
        db.query(JpAddress)
        .filter(JpAddress.postal_code == normalized)
        .order_by(JpAddress.updated_at.desc())
        .first()
    )
    if existing and _cache_fresh(existing.updated_at):
        logger.debug("Geocoding cache hit: address=%r", normalized)
        return {
            "lat": None,  # JpAddress doesn't store lat/lon — it's a postal cache
            "lon": None,
            "display_name": f"{existing.prefecture}{existing.city}{existing.town or ''}",
            "source": "cache",
            "prefecture": existing.prefecture,
            "city": existing.city,
            "town": existing.town,
        }

    # Step 1: Postal lookup (synchronous — jp_postal_client uses httpx sync)
    import re
    is_postal = bool(re.match(r"^\d{3}-?\d{4}$", normalized))
    if is_postal:
        postal_result = lookup_postal(normalized, db)
        if postal_result:
            logger.debug("Geocoding: postal hit for %r", normalized)
            return {
                "lat": None,
                "lon": None,
                "display_name": postal_result.get("address", normalized),
                "source": "postal",
                "prefecture": postal_result.get("prefecture"),
                "city": postal_result.get("city"),
                "town": postal_result.get("town"),
            }

    # Step 2: Nominatim fallback
    from app.services.geocoding.nominatim_client import geocode_address
    try:
        nominatim_result = await geocode_address(normalized)
    except Exception as exc:
        logger.error("Nominatim geocode error: %s", exc)
        nominatim_result = None

    if nominatim_result:
        logger.info("Geocoding: Nominatim hit for address=%r", normalized)
        # Cache in jp_addresses if we have a postal code to key on
        _maybe_cache_nominatim(nominatim_result, normalized, db)
        return {
            "lat": nominatim_result["lat"],
            "lon": nominatim_result["lon"],
            "display_name": nominatim_result["display_name"],
            "source": "nominatim",
            "prefecture": nominatim_result.get("address", {}).get("state"),
            "city": nominatim_result.get("address", {}).get("city"),
            "town": nominatim_result.get("address", {}).get("suburb"),
        }

    logger.warning("Geocoding: no result for address=%r (postal=%s)", normalized, is_postal)
    return None


def _maybe_cache_nominatim(
    result: dict,
    query_key: str,
    db: Session,
) -> None:
    """Upsert Nominatim result into jp_addresses for caching.

    Only caches if we can extract a postal code from the result.
    Silently ignores failures (cache write is non-critical).
    """
    try:
        from app.domain.jp.address import JpAddress

        addr = result.get("address", {})
        postcode = addr.get("postcode", "").replace("-", "")
        if not postcode or len(postcode) != 7:
            return  # Can't cache without valid postal code

        existing = db.query(JpAddress).filter(JpAddress.postal_code == postcode).first()
        if existing:
            existing.prefecture = addr.get("state")
            existing.city = addr.get("city") or addr.get("town")
            existing.town = addr.get("suburb") or addr.get("neighbourhood")
            existing.updated_at = datetime.now(timezone.utc)
        else:
            row = JpAddress(
                postal_code=postcode,
                prefecture=addr.get("state"),
                city=addr.get("city") or addr.get("town"),
                town=addr.get("suburb") or addr.get("neighbourhood"),
            )
            db.add(row)
        db.flush()
    except Exception as exc:
        logger.warning("Nominatim cache write failed (non-critical): %s", exc)
