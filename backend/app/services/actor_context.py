"""Actor context dataclass for Owner-Operator Delegation (Phase 02).

Provides:
  - ActorContext: frozen, per-request identity snapshot.
  - build_owner_context: construct self-acting (no delegation) context.
  - build_operator_context: construct on-behalf-of context from a Delegation row.

Consumed by:
  - app/api/dependencies/actor.py (FastAPI dependency that resolves per-request)
  - Route handlers via Depends(get_actor_context)
  - app/repositories/audit.py (write_change_log dual-identity)
  - app/services/audit_log_service.py (record dual-identity)

Security notes:
  - permission_set is a frozenset — cannot be mutated in handler code.
  - effective_owner_id is the field to use for DB queries (replaces raw JWT sub
    for delegation-aware endpoints).
  - JWT NEVER caches delegation state (NFR-07); context is built per-request
    from a live DB lookup.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from typing import Optional

from app.services.permission_set import (
    owner_self_permissions,
    preset_to_permissions,
)


@dataclass(frozen=True)
class ActorContext:
    """Immutable, per-request snapshot of who is acting and on whose behalf.

    Fields:
        actor_user_id:              JWT sub — the authenticated user performing the request.
        on_behalf_of_user_id:       Owner's user.id when acting via delegation; None for self.
        delegation_id:              The active Delegation.id (UUID str) or None for self.
        scope_type:                 'all' | 'building_list' | None for self-acting.
        scope_target_building_ids:  List of building IDs in scope; None when scope_type='all'.
        permission_set:             Frozen set of allowed action strings.
        actor_role:                 JWT role claim ('host' | 'admin' | 'operator' | 'guest').
        request_id:                 UUID for log correlation (injected by dependency).
    """

    actor_user_id: int
    on_behalf_of_user_id: Optional[int]
    delegation_id: Optional[str]
    scope_type: Optional[str]
    scope_target_building_ids: Optional[list[int]]
    permission_set: frozenset[str]
    actor_role: str
    request_id: str

    # ------------------------------------------------------------------
    # Convenience properties
    # ------------------------------------------------------------------

    @property
    def effective_owner_id(self) -> int:
        """ID to use for host_id / owner_id DB filters.

        Returns on_behalf_of_user_id when acting as operator, otherwise
        actor_user_id (self-acting owner path — AC-47/48 backward compat).
        """
        return self.on_behalf_of_user_id or self.actor_user_id

    @property
    def is_acting_on_behalf(self) -> bool:
        """True when this request carries a valid delegation context."""
        return self.on_behalf_of_user_id is not None

    # ------------------------------------------------------------------
    # Permission checks
    # ------------------------------------------------------------------

    def has_permission(self, action: str) -> bool:
        """Check if this context grants the given action.

        For owner self-acting contexts, owner_self_permissions() returns all
        known actions so this is always True — preserving legacy behavior.
        """
        return action in self.permission_set

    def is_in_scope(self, building_id: int) -> bool:
        """Check if building_id is within this delegation's scope.

        Self-acting owners always pass (scope determined by host_id DB filter).
        Delegations with scope_type='all' always pass.
        Delegations with scope_type='building_list' check scope_target_building_ids.
        """
        if not self.is_acting_on_behalf:
            # Owner self-acting: scope is governed by host_id filter, not scope list.
            return True
        if self.scope_type == "all":
            return True
        building_ids = self.scope_target_building_ids or []
        return building_id in building_ids


# ---------------------------------------------------------------------------
# Factory helpers
# ---------------------------------------------------------------------------


def build_owner_context(
    actor_user_id: int,
    actor_role: str,
    request_id: Optional[str] = None,
) -> ActorContext:
    """Build an ActorContext for an owner acting for themselves (no delegation).

    Used when X-Acting-As-Delegation-Id header is absent.  Preserves legacy
    require_host behavior — effective_owner_id == actor_user_id, full access.
    """
    return ActorContext(
        actor_user_id=actor_user_id,
        on_behalf_of_user_id=None,
        delegation_id=None,
        scope_type=None,
        scope_target_building_ids=None,
        permission_set=owner_self_permissions(),
        actor_role=actor_role,
        request_id=request_id or str(uuid.uuid4()),
    )


def build_operator_context(
    actor_user_id: int,
    actor_role: str,
    delegation: object,  # app.domain.delegation.Delegation — typed as object to avoid circular import
    request_id: Optional[str] = None,
) -> ActorContext:
    """Build an ActorContext for an operator acting on behalf of an owner.

    delegation.role_preset determines the permission set.
    delegation.scope_type / scope_target_ids determine scope boundaries.

    Raises ValueError if delegation.role_preset is unknown.
    """
    # Narrow scope_target_ids from JSON to list[int] safely.
    raw_scope_ids = getattr(delegation, "scope_target_ids", None)
    if raw_scope_ids is None:
        building_ids = None
    elif isinstance(raw_scope_ids, list):
        building_ids = [int(x) for x in raw_scope_ids]
    else:
        # Unexpected type — treat as empty list so scope check fails safely.
        building_ids = []

    return ActorContext(
        actor_user_id=actor_user_id,
        on_behalf_of_user_id=int(delegation.owner_id),  # type: ignore[attr-defined]
        delegation_id=str(delegation.id),  # type: ignore[attr-defined]
        scope_type=delegation.scope_type,  # type: ignore[attr-defined]
        scope_target_building_ids=building_ids,
        permission_set=preset_to_permissions(delegation.role_preset),  # type: ignore[attr-defined]
        actor_role=actor_role,
        request_id=request_id or str(uuid.uuid4()),
    )
