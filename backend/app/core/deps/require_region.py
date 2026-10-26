"""FastAPI dependency: gate endpoints by the configured region.

Usage at router level (in main.py include_router call):
    app.include_router(
        construction_router.router,
        dependencies=[Depends(require_region("vn"))],
    )

Usage within a specific endpoint:
    @router.get("/some-endpoint")
    async def endpoint(_: None = Depends(require_region("jp"))):
        ...

Returns 404 (not 403) on mismatch — JP existence must not be leaked to VN clients
and vice versa. This matches the security spec in phase-00-foundation-backend.md.
"""

from __future__ import annotations

from functools import lru_cache
from typing import Callable

from fastapi import Depends, HTTPException

from app.config import settings


def require_region(expected: str) -> Callable[[], None]:
    """Return a FastAPI dependency that raises HTTP 404 when region != expected.

    `expected` is compared against `settings.region` (case-insensitive).
    The returned callable is cached per `expected` string so FastAPI's
    dependency cache doesn't create duplicate closures.

    Args:
        expected: The region string required for this endpoint (e.g. 'vn', 'jp').

    Returns:
        A callable FastAPI dependency (no arguments needed from request).
    """

    @lru_cache(maxsize=None)
    def _make_dep(region_key: str) -> Callable[[], None]:
        def _dep() -> None:
            if settings.region.lower() != region_key.lower():
                raise HTTPException(
                    status_code=404,
                    detail="Not found",
                )

        return _dep

    return _make_dep(expected)
