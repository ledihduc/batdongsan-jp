"""Audit trail writer for change_logs table.

Usage (Phase 03+):
    from app.repositories.audit import write_change_log

    write_change_log(
        db,
        entity_type="contract",
        entity_id=contract.id,
        actor_id=claims["sub"],
        action="create",
        before=None,
        after=contract_dict,
    )

    # With delegation context (dual-identity):
    write_change_log(
        db,
        entity_type="contract",
        entity_id=contract.id,
        action="create",
        before=None,
        after=contract_dict,
        actor_ctx=actor_ctx,
    )
"""

from __future__ import annotations

import json
from datetime import datetime
from typing import TYPE_CHECKING, Any, Optional

from sqlalchemy.orm import Session

from app import models

if TYPE_CHECKING:
    # Avoid circular import at runtime — ActorContext imported only for type checking.
    from app.services.actor_context import ActorContext


def write_change_log(
    db: Session,
    entity_type: str,
    entity_id: int,
    action: str,
    before: Optional[Any] = None,
    after: Optional[Any] = None,
    *,
    # Dual-identity (Phase 02): pass actor_ctx for delegation-aware writes.
    # Default None preserves backward compat with existing self-host callers (AC-48).
    actor_ctx: Optional["ActorContext"] = None,
    # Fallback for system jobs without a request-scoped actor_ctx.
    explicit_actor_id: Optional[int] = None,
    # Backward-compat alias: nhiều caller cũ truyền actor_id= (contract/invoice/
    # khai_bao/reservation/host_profile). Coi như explicit_actor_id để không vỡ.
    actor_id: Optional[int] = None,
) -> models.ChangeLog:
    """Write a ChangeLog row. Flushes but does NOT commit — caller owns transaction.

    Dual-identity (AC-23/32/39):
      - If actor_ctx is provided, actor_id, on_behalf_of_user_id,
        acted_via_delegation_id, and scope_snapshot_json are auto-filled.
      - If actor_ctx is None, explicit_actor_id is used as actor_id (legacy path).

    Args:
        db:                 SQLAlchemy session.
        entity_type:        one of 'contract' | 'invoice' | 'host_profile' | ...
        entity_id:          PK of the affected row.
        action:             one of 'create' | 'update' | 'status_change' | 'delete'.
        before:             dict/object representing state before change (None for create).
        after:              dict/object representing state after change (None for delete).
        actor_ctx:          ActorContext from resolve_actor_context (fills dual-identity).
        explicit_actor_id:  Fallback actor id when no actor_ctx (system jobs, cron).
    """
    # Resolve identity fields from ActorContext or fallback.
    if actor_ctx is not None:
        actor_id: Optional[int] = actor_ctx.actor_user_id
        on_behalf_of_user_id: Optional[int] = actor_ctx.on_behalf_of_user_id
        delegation_id: Optional[str] = actor_ctx.delegation_id
        scope_snapshot: Optional[dict] = None
        if actor_ctx.delegation_id is not None:
            scope_snapshot = {
                "type": actor_ctx.scope_type,
                "target_ids": actor_ctx.scope_target_building_ids,
            }
    else:
        actor_id = explicit_actor_id if explicit_actor_id is not None else actor_id
        on_behalf_of_user_id = None
        delegation_id = None
        scope_snapshot = None

    entry = models.ChangeLog(
        entity_type=entity_type,
        entity_id=entity_id,
        actor_id=actor_id,
        action=action,
        before_json=json.dumps(before, default=str) if before is not None else None,
        after_json=json.dumps(after, default=str) if after is not None else None,
        on_behalf_of_user_id=on_behalf_of_user_id,
        acted_via_delegation_id=delegation_id,
        scope_snapshot_json=scope_snapshot,
        created_at=datetime.utcnow(),
    )
    db.add(entry)
    db.flush()
    return entry
