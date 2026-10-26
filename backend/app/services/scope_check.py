"""Scope resolution helpers for delegation-aware endpoints (Phase 02).

Provides _resolve_to_building_id() which maps a request-level entity
(building / room / contract / invoice) to a canonical building_id so
ActorContext.is_in_scope() can validate it.

Per-request cache (request.state.scope_cache) prevents N+1 queries when
the same scope entity appears multiple times within one request (NFR-05).

Target latency: p95 < 20ms for scope check (single indexed lookup).
"""

from __future__ import annotations

from typing import Optional

from fastapi import Request
from sqlalchemy.orm import Session

from app import models


# ---------------------------------------------------------------------------
# Supported scope kinds
# ---------------------------------------------------------------------------

SCOPE_KIND_BUILDING: str = "building"
SCOPE_KIND_ROOM: str = "room"
SCOPE_KIND_CONTRACT: str = "contract"
SCOPE_KIND_INVOICE: str = "invoice"

_VALID_SCOPE_KINDS: frozenset[str] = frozenset(
    [SCOPE_KIND_BUILDING, SCOPE_KIND_ROOM, SCOPE_KIND_CONTRACT, SCOPE_KIND_INVOICE]
)


# ---------------------------------------------------------------------------
# Per-request cache
# ---------------------------------------------------------------------------


def _get_or_init_cache(request: Request) -> dict[tuple[str, int], Optional[int]]:
    """Return the scope resolution cache stored in request.state."""
    if not hasattr(request.state, "scope_cache"):
        request.state.scope_cache = {}
    return request.state.scope_cache  # type: ignore[return-value]


# ---------------------------------------------------------------------------
# Core resolver
# ---------------------------------------------------------------------------


def resolve_to_building_id(
    db: Session,
    request: Request,
    scope_kind: str,
    target_id: int,
) -> Optional[int]:
    """Map (scope_kind, target_id) → building_id using a single indexed DB lookup.

    Returns None if the entity does not exist or has no building association.
    Results are cached in request.state.scope_cache for the duration of the
    request to avoid N+1 queries (NFR-05).

    Args:
        db:         Active SQLAlchemy session.
        request:    FastAPI Request (used as cache container).
        scope_kind: One of 'building' | 'room' | 'contract' | 'invoice'.
        target_id:  PK of the entity to resolve.

    Raises:
        ValueError: if scope_kind is not one of the supported values.
    """
    if scope_kind not in _VALID_SCOPE_KINDS:
        raise ValueError(
            f"Unknown scope_kind '{scope_kind}'. "
            f"Valid values: {sorted(_VALID_SCOPE_KINDS)}"
        )

    cache = _get_or_init_cache(request)
    cache_key = (scope_kind, target_id)

    if cache_key in cache:
        return cache[cache_key]

    building_id = _do_resolve(db, scope_kind, target_id)
    cache[cache_key] = building_id
    return building_id


def _do_resolve(db: Session, scope_kind: str, target_id: int) -> Optional[int]:
    """Execute DB lookup — called only on cache miss."""
    if scope_kind == SCOPE_KIND_BUILDING:
        # building is its own scope root — just verify it exists.
        row = db.query(models.Building.id).filter(models.Building.id == target_id).first()
        return target_id if row is not None else None

    if scope_kind == SCOPE_KIND_ROOM:
        row = (
            db.query(models.Room.building_id)
            .filter(models.Room.id == target_id)
            .first()
        )
        return int(row.building_id) if row is not None else None

    if scope_kind == SCOPE_KIND_CONTRACT:
        row = (
            db.query(models.Room.building_id)
            .join(models.Contract, models.Contract.room_id == models.Room.id)
            .filter(models.Contract.id == target_id)
            .first()
        )
        return int(row.building_id) if row is not None else None

    if scope_kind == SCOPE_KIND_INVOICE:
        # Invoice → Contract (via contract_id) → Room (via room_id) → building_id
        row = (
            db.query(models.Room.building_id)
            .select_from(models.Invoice)
            .join(models.Contract, models.Contract.id == models.Invoice.contract_id)
            .join(models.Room, models.Room.id == models.Contract.room_id)
            .filter(models.Invoice.id == target_id)
            .first()
        )
        return int(row.building_id) if row is not None else None

    return None  # unreachable — scope_kind validated above
