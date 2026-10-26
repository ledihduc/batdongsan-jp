"""JP address lookup endpoint.

Route: GET /api/jp/address/lookup?postal_code=1500001

Returns a list of address candidates for the given Japanese postal code.
Uses the zipcloud.ibsnet.co.jp free API (no key required) with 15-min
in-memory TTL cache.

Gate: This router is intended for JP region only. Mount with require_region('jp')
dependency in main.py to return 404 when region=vn.

Security:
  - postal_code validated by regex before use (no injection risk).
  - No PII logged.
  - 5s HTTP timeout enforced in jp_postal_client.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Query

from app.schemas.jp.address import AddressCandidate, AddressLookupResponse
from app.services.address.jp_postal_client import (
    lookup_postal_code,
    validate_postal_code,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/jp", tags=["jp-address"])


@router.get(
    "/address/lookup",
    response_model=AddressLookupResponse,
    summary="Look up Japanese address by postal code",
    description=(
        "Returns address candidates for a 7-digit Japanese postal code. "
        "Data sourced from zipcloud.ibsnet.co.jp (no API key required). "
        "Results are cached in-memory for 15 minutes. "
        "Accepts formats: '1500001' or '150-0001'."
    ),
)
async def lookup_address(
    postal_code: str = Query(
        ...,
        description="7-digit JP postal code (e.g. '1500001' or '150-0001')",
        examples=["1500001"],
        min_length=7,
        max_length=8,
    ),
) -> AddressLookupResponse:
    """Look up a Japanese postal code and return address candidates.

    Returns HTTP 422 if postal code format is invalid.
    Returns HTTP 200 with empty candidates list if postal code not found.
    Returns HTTP 503 if the upstream postal API is unreachable.
    """
    # Validate format before hitting the external API.
    if not validate_postal_code(postal_code.strip()):
        raise HTTPException(
            status_code=422,
            detail=(
                f"Invalid postal code format: '{postal_code}'. "
                "Expected 7 digits (e.g. '1500001' or '150-0001')."
            ),
        )

    try:
        candidates_raw = await lookup_postal_code(postal_code.strip())
    except ValueError as exc:
        # Should not happen after the validate_postal_code guard, but be safe.
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        logger.error(
            "jp_address_lookup: upstream postal API error for postal_code=%s: %s",
            postal_code,
            exc,
        )
        raise HTTPException(
            status_code=503,
            detail="Postal lookup service temporarily unavailable. Please try again.",
        ) from exc

    normalized = postal_code.strip().replace("-", "")
    candidates = [AddressCandidate(**c) for c in candidates_raw]

    return AddressLookupResponse(postal_code=normalized, candidates=candidates)
