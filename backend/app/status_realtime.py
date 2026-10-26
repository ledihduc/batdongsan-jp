"""Realtime, privacy-safe status events.

Status changes are broadcast only to the participants of the entity.  The
event contains identifiers and state labels, never phone numbers, payment
proofs, or other private projections.  Notifications are still persisted by
the domain service, so a reconnecting client can reconcile from REST.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Iterable, Mapping, Any

from app.chat_hub import hub


def publish_status_change(
    *,
    entity: str,
    entity_id: int,
    from_status: str | None,
    to_status: str,
    participant_ids: Iterable[int | None],
    actor_id: int | None = None,
    action: str | None = None,
    extra: Mapping[str, Any] | None = None,
) -> None:
    """Fan out one committed status transition to each allowed participant."""
    payload: dict[str, Any] = {
        "entity": entity,
        "entity_id": entity_id,
        "from_status": from_status,
        "to_status": to_status,
        "actor_id": actor_id,
        "action": action,
        "occurred_at": datetime.now(timezone.utc).isoformat(),
    }
    if extra:
        # Only callers in this module's trusted backend code can add fields;
        # keep this an additive, JSON-safe projection.
        payload.update(dict(extra))
    seen: set[int] = set()
    for participant_id in participant_ids:
        if participant_id is None:
            continue
        uid = int(participant_id)
        if uid in seen:
            continue
        seen.add(uid)
        hub.send_to_sync(uid, "status:changed", payload)
