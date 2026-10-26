"""Audit log service — Phase 02 (dual-identity extension).

Records per-action audit rows for legal compliance.

Phase 02 change: `record()` now accepts an optional `actor_ctx` (ActorContext)
to populate dual-identity columns (actor_user_id, on_behalf_of_user_id,
acted_via_delegation_id) for delegation-aware writes.

Backward compat: existing callers that pass only host_id continue to work
unchanged (actor_ctx defaults to None).
"""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any, Optional

from sqlalchemy.orm import Session

from app import models

if TYPE_CHECKING:
    from app.services.actor_context import ActorContext


def record(
    db: Session,
    *,
    host_id: int,
    action: str,
    success: bool,
    period: Optional[str] = None,
    ip: Optional[str] = None,
    user_agent: Optional[str] = None,
    extra: Optional[dict[str, Any]] = None,
    # Phase 02: dual-identity for delegation-aware audit rows (AC-23, AC-32, AC-39).
    # Default None = backward-compat with existing self-host callers (AC-48).
    actor_ctx: Optional["ActorContext"] = None,
) -> models.AuditLog:
    """Insert an AuditLog row. Caller is responsible for commit boundary.

    When actor_ctx is provided, the following columns are filled:
      - actor_user_id  = actor_ctx.actor_user_id  (who performed the action)
      - on_behalf_of_user_id = actor_ctx.on_behalf_of_user_id (owner when delegated)
      - acted_via_delegation_id = actor_ctx.delegation_id

    Args:
        db:         SQLAlchemy session.
        host_id:    ID of the host (owner) associated with this action.
                    For operator-initiated actions, use actor_ctx.effective_owner_id.
        action:     Action name, e.g. 'export_tt200'.
        success:    Whether the action succeeded.
        period:     Optional "YYYY-MM" for export actions.
        ip:         Requester IP address (up to 45 chars for IPv6).
        user_agent: Requester User-Agent string.
        extra:      Optional dict serialized to JSON for future extensibility.
        actor_ctx:  ActorContext from resolve_actor_context; fills dual-identity
                    columns for delegation-aware rows.
    """
    extra_json: Optional[str] = None
    if extra is not None:
        try:
            extra_json = json.dumps(extra, ensure_ascii=False)
        except (TypeError, ValueError):
            extra_json = str(extra)

    # Resolve dual-identity from ActorContext if provided.
    actor_user_id: Optional[int] = None
    on_behalf_of_user_id: Optional[int] = None
    delegation_id: Optional[str] = None

    if actor_ctx is not None:
        actor_user_id = actor_ctx.actor_user_id
        on_behalf_of_user_id = actor_ctx.on_behalf_of_user_id
        delegation_id = actor_ctx.delegation_id

    row = models.AuditLog(
        host_id=host_id,
        action=action,
        success=success,
        period=period,
        ip=ip,
        user_agent=user_agent[:500] if user_agent else None,
        extra=extra_json,
        actor_user_id=actor_user_id,
        on_behalf_of_user_id=on_behalf_of_user_id,
        acted_via_delegation_id=delegation_id,
    )
    db.add(row)
    db.flush()
    return row
