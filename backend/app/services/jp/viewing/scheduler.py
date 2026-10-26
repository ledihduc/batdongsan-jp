"""JP 内見 (naiken) scheduler — slot validation and state machine.

Business rules:
  - requested_slots: 1-3 entries
  - Each slot must be during business hours 10:00-19:00 JST
  - Confirmed slot must be ≥24h from creation time (lead_time_hours ≥ 24)
  - Only agent can confirm or complete a viewing
  - Only tenant (creator) or agent can cancel
  - State machine: requested → confirmed → completed | cancelled

This service is idempotent on confirm: calling confirm twice with the same
slot_ts is a no-op if already in 'confirmed' state.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import HTTPException

from app.domain.jp.viewing import JpViewing, VIEWING_STATUS_VALUES
from app.repositories.jp.viewing import JpViewingRepository

logger = logging.getLogger(__name__)

# Business hours in JST (UTC+9)
_JST = timezone(timedelta(hours=9))
_BUSINESS_HOUR_START = 10  # 10:00 JST
_BUSINESS_HOUR_END = 19    # 19:00 JST (exclusive)
_LEAD_TIME_HOURS = 24      # Minimum hours before a slot can be confirmed


class ViewingSchedulerError(Exception):
    """Raised for business rule violations in the viewing scheduler."""


class ViewingStateError(ViewingSchedulerError):
    """Raised for invalid state machine transitions."""


def validate_slots(
    slots: list[str],
    *,
    reference_time: Optional[datetime] = None,
) -> list[datetime]:
    """Validate requested viewing slots.

    Checks:
    1. Count: 1-3 slots
    2. Parse: each slot is a valid ISO 8601 datetime
    3. Business hours: each slot is 10:00-19:00 JST
    4. Lead time: each slot is ≥24h from reference_time (defaults to now)

    Returns: list of parsed datetime objects (timezone-aware UTC)

    Raises ViewingSchedulerError on validation failure.
    """
    if not 1 <= len(slots) <= 3:
        raise ViewingSchedulerError(
            f"requested_slots must have 1-3 entries, got {len(slots)}"
        )

    ref = reference_time or datetime.now(timezone.utc)
    lead_cutoff = ref + timedelta(hours=_LEAD_TIME_HOURS)
    parsed: list[datetime] = []

    for raw_slot in slots:
        try:
            dt = datetime.fromisoformat(raw_slot.replace("Z", "+00:00"))
        except (ValueError, AttributeError) as exc:
            raise ViewingSchedulerError(
                f"Invalid slot timestamp '{raw_slot}': {exc}"
            ) from exc

        # Normalize to UTC for lead-time check
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)

        # Lead time check
        if dt < lead_cutoff:
            raise ViewingSchedulerError(
                f"Slot {raw_slot} is less than {_LEAD_TIME_HOURS}h in advance. "
                f"Earliest allowed: {lead_cutoff.isoformat()}"
            )

        # Business hours check in JST
        dt_jst = dt.astimezone(_JST)
        if not (_BUSINESS_HOUR_START <= dt_jst.hour < _BUSINESS_HOUR_END):
            raise ViewingSchedulerError(
                f"Slot {raw_slot} is outside business hours "
                f"({_BUSINESS_HOUR_START}:00-{_BUSINESS_HOUR_END}:00 JST). "
                f"Slot in JST: {dt_jst.strftime('%H:%M')}"
            )

        parsed.append(dt)

    return parsed


def create_viewing_request(
    repo: JpViewingRepository,
    *,
    org_id: Optional[str],
    listing_id: str,
    tenant_id: int,
    agent_id: Optional[int] = None,
    requested_slots: list[str],
    notes: Optional[str] = None,
    reference_time: Optional[datetime] = None,
) -> JpViewing:
    """Create a new viewing request with slot validation.

    Validates slots before writing to DB. Raises ViewingSchedulerError or HTTPException
    on validation failure.

    Idempotency: no deduplication check — each call creates a new record.
    Caller should check for existing active requests if desired.
    """
    try:
        validate_slots(requested_slots, reference_time=reference_time)
    except ViewingSchedulerError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return repo.create(
        org_id=org_id,
        listing_id=listing_id,
        tenant_id=tenant_id,
        agent_id=agent_id,
        requested_slots=requested_slots,
        notes=notes,
    )


def confirm_viewing(
    repo: JpViewingRepository,
    *,
    viewing: JpViewing,
    confirmed_slot_ts: str,
    agent_user_id: int,
    org_id: str,
) -> JpViewing:
    """Agent confirms one of the requested slots.

    State machine: requested → confirmed
    - Only allowed from 'requested' state (idempotent if already 'confirmed' with same slot)
    - confirmed_slot_ts must be one of the requested_slots values

    Raises HTTPException (400/403/422) on violation.
    """
    if viewing.status == "confirmed":
        # Idempotent: already confirmed — check slot matches
        existing_ts = viewing.confirmed_slot_ts
        try:
            requested_dt = datetime.fromisoformat(confirmed_slot_ts.replace("Z", "+00:00"))
        except (ValueError, AttributeError) as exc:
            raise HTTPException(status_code=422, detail=f"Invalid slot timestamp: {exc}") from exc

        if existing_ts and abs((existing_ts - requested_dt.replace(tzinfo=None)).total_seconds()) < 1:
            return viewing  # Already confirmed with same slot
        raise HTTPException(
            status_code=400,
            detail="Viewing already confirmed with a different slot. Cancel and re-request.",
        )

    if viewing.status != "requested":
        raise HTTPException(
            status_code=400,
            detail=f"Cannot confirm viewing in status '{viewing.status}'. "
                   "Only 'requested' viewings can be confirmed.",
        )

    # Validate confirmed slot is one of the requested options
    slots = viewing.requested_slots or []
    if isinstance(slots, list):
        slot_strings = [str(s) for s in slots]
    else:
        slot_strings = []

    if confirmed_slot_ts not in slot_strings:
        raise HTTPException(
            status_code=422,
            detail=f"confirmed_slot_ts '{confirmed_slot_ts}' is not in the requested_slots list.",
        )

    try:
        dt = datetime.fromisoformat(confirmed_slot_ts.replace("Z", "+00:00"))
    except (ValueError, AttributeError) as exc:
        raise HTTPException(status_code=422, detail=f"Invalid slot timestamp: {exc}") from exc

    # Strip timezone for storage (stored as naive UTC in DB)
    dt_naive = dt.replace(tzinfo=None)

    return repo.update_status(
        viewing,
        status="confirmed",
        confirmed_slot_ts=dt_naive,
        agent_id=agent_user_id,
    )


def cancel_viewing(
    repo: JpViewingRepository,
    *,
    viewing: JpViewing,
    actor_user_id: int,
    org_id: str,
) -> JpViewing:
    """Cancel a viewing. Allowed by tenant (creator) or agent.

    State machine: requested | confirmed → cancelled
    Raises HTTPException on invalid state or unauthorized actor.
    """
    if viewing.status in ("completed", "cancelled"):
        raise HTTPException(
            status_code=400,
            detail=f"Cannot cancel viewing in status '{viewing.status}'.",
        )

    # Authorization: only tenant or agent can cancel
    is_tenant = viewing.tenant_id == actor_user_id
    is_agent = viewing.agent_id is not None and viewing.agent_id == actor_user_id

    if not (is_tenant or is_agent):
        raise HTTPException(
            status_code=403,
            detail="Only the tenant or assigned agent can cancel this viewing.",
        )

    return repo.update_status(viewing, status="cancelled")


def complete_viewing(
    repo: JpViewingRepository,
    *,
    viewing: JpViewing,
    agent_user_id: int,
) -> JpViewing:
    """Mark a confirmed viewing as completed.

    State machine: confirmed → completed
    Only the assigned agent can complete a viewing.
    """
    if viewing.status != "confirmed":
        raise HTTPException(
            status_code=400,
            detail=f"Cannot complete viewing in status '{viewing.status}'. "
                   "Only 'confirmed' viewings can be marked complete.",
        )

    if viewing.agent_id != agent_user_id:
        raise HTTPException(
            status_code=403,
            detail="Only the assigned agent can mark this viewing as completed.",
        )

    return repo.update_status(viewing, status="completed")
