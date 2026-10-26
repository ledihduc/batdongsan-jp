"""FastAPI dependency: resolve_actor_context (Phase 02).

Reads `X-Acting-As-Delegation-Id` header, validates delegation, populates
request.state.actor_ctx and returns an ActorContext.

Design decisions:
  - JWT remains user-identity only (NFR-07): delegation state NOT cached in JWT.
  - Per-request DB lookup ensures revocation propagates on next call (NFR-02).
  - Missing header → owner-mode (backward compat with existing require_host).
  - Invalid/revoked delegation → 401/403 with typed error codes for Flutter handler.

Error codes (returned in detail dict):
  INVALID_DELEGATION_HEADER  — header value is not a valid UUID4 format.
  DELEGATION_NOT_FOUND       — UUID valid but no DB row found.
  NOT_YOUR_DELEGATION        — delegation.operator_id != JWT sub.
  DELEGATION_REVOKED         — status in ('terminated', 'archived').
  DELEGATION_PAUSED          — status == 'paused'.
  OPERATOR_OUT_OF_OFFICE     — out-of-office window active + action is a mutation (AC-57).
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import Depends, Header, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.auth import optional_user, require_user
from app.database import get_db
from app.domain.delegation import Delegation
from app.services.actor_context import (
    ActorContext,
    build_operator_context,
    build_owner_context,
)


# ---------------------------------------------------------------------------
# Header extractor
# ---------------------------------------------------------------------------


def _parse_delegation_header(value: Optional[str]) -> Optional[str]:
    """Validate that the header value is a UUID4 string.

    Returns the lowercased UUID string or None if value is absent.
    Raises HTTPException(400) if value is present but malformed.
    """
    if value is None:
        return None
    try:
        parsed = uuid.UUID(value, version=4)
        return str(parsed)
    except (ValueError, AttributeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": "INVALID_DELEGATION_HEADER",
                "message": "X-Acting-As-Delegation-Id must be a valid UUID4",
            },
        ) from exc


# ---------------------------------------------------------------------------
# Core dependency
# ---------------------------------------------------------------------------


async def resolve_actor_context(
    request: Request,
    claims: dict = Depends(require_user),
    db: Session = Depends(get_db),
    x_acting_as_delegation_id: Optional[str] = Header(
        default=None,
        alias="X-Acting-As-Delegation-Id",
        description="UUID4 of the active Delegation; absent = owner self-acting mode.",
    ),
) -> ActorContext:
    """Resolve actor context per request.

    Two paths:
      1. Header absent  → owner self-acting (AC-47/48 backward compat).
      2. Header present → validate delegation, build operator context.

    Stores result in request.state.actor_ctx for optional access in middleware.
    """
    actor_user_id: int = int(claims["sub"])
    actor_role: str = claims.get("role", "guest")
    # Per-request correlation ID (reuse if already set by a tracing middleware).
    request_id: str = getattr(request.state, "request_id", None) or str(uuid.uuid4())

    delegation_header = _parse_delegation_header(x_acting_as_delegation_id)

    if delegation_header is None:
        # --- Owner self-acting path ---
        ctx = build_owner_context(
            actor_user_id=actor_user_id,
            actor_role=actor_role,
            request_id=request_id,
        )
        request.state.actor_ctx = ctx
        return ctx

    # --- Operator acting on behalf of owner ---
    delegation = (
        db.query(Delegation)
        .filter(Delegation.id == delegation_header)
        .first()
    )

    if delegation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": "DELEGATION_NOT_FOUND",
                "message": "No delegation found for the provided ID",
            },
        )

    if int(delegation.operator_id) != actor_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "NOT_YOUR_DELEGATION",
                "message": "This delegation does not belong to you",
            },
        )

    if delegation.status in ("terminated", "archived"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "code": "DELEGATION_REVOKED",
                "message": "This delegation has been revoked",
            },
        )

    if delegation.status == "paused":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "code": "DELEGATION_PAUSED",
                "message": "This delegation is currently paused",
            },
        )

    # Out-of-office check (AC-57): logged but not hard-blocked here.
    # Hard block is deferred to require_actor_with_permission for mutation actions.
    _check_out_of_office(delegation, actor_user_id)

    ctx = build_operator_context(
        actor_user_id=actor_user_id,
        actor_role=actor_role,
        delegation=delegation,
        request_id=request_id,
    )
    request.state.actor_ctx = ctx
    return ctx


def _check_out_of_office(delegation: Delegation, actor_user_id: int) -> None:
    """Check if delegation is in an out-of-office window.

    Raises HTTPException(423) if both OOF timestamps are set and now is within
    the window (AC-57).  Note: 423 Locked is appropriate here per BA v4 §8.
    Callers (require_actor_with_permission) may use this signal for mutations.
    """
    oof_start = delegation.out_of_office_start
    oof_end = delegation.out_of_office_end
    if oof_start is None or oof_end is None:
        return

    now = datetime.now(timezone.utc)
    # Make oof_start / oof_end timezone-aware if stored as naive UTC datetimes.
    if oof_start.tzinfo is None:
        oof_start = oof_start.replace(tzinfo=timezone.utc)
    if oof_end.tzinfo is None:
        oof_end = oof_end.replace(tzinfo=timezone.utc)

    if oof_start <= now <= oof_end:
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail={
                "code": "OPERATOR_OUT_OF_OFFICE",
                "message": "Operator is in out-of-office window; no mutations allowed",
                "oof_start": oof_start.isoformat(),
                "oof_end": oof_end.isoformat(),
            },
        )


# ---------------------------------------------------------------------------
# Optional context getter (no 401 if no JWT)
# ---------------------------------------------------------------------------


async def get_optional_actor_context(
    request: Request,
    claims: Optional[dict] = Depends(optional_user),
    db: Session = Depends(get_db),
    x_acting_as_delegation_id: Optional[str] = Header(
        default=None,
        alias="X-Acting-As-Delegation-Id",
    ),
) -> Optional[ActorContext]:
    """Like resolve_actor_context but returns None if no JWT is present.

    Used for public endpoints that optionally enrich responses when authenticated.
    """
    if claims is None:
        return None
    # Reuse the main resolver logic by constructing a temporary mock request
    # with the same state — simpler to call resolve logic inline.
    actor_user_id: int = int(claims["sub"])
    actor_role: str = claims.get("role", "guest")
    request_id: str = getattr(request.state, "request_id", None) or str(uuid.uuid4())

    delegation_header = _parse_delegation_header(x_acting_as_delegation_id)
    if delegation_header is None:
        ctx = build_owner_context(
            actor_user_id=actor_user_id,
            actor_role=actor_role,
            request_id=request_id,
        )
        request.state.actor_ctx = ctx
        return ctx

    delegation = db.query(Delegation).filter(Delegation.id == delegation_header).first()
    if delegation is None or delegation.status not in ("active", "terminating"):
        return None

    if int(delegation.operator_id) != actor_user_id:
        return None

    ctx = build_operator_context(
        actor_user_id=actor_user_id,
        actor_role=actor_role,
        delegation=delegation,
        request_id=request_id,
    )
    request.state.actor_ctx = ctx
    return ctx


# ---------------------------------------------------------------------------
# Shorthand: get actor_ctx from request.state (for middleware / handlers)
# ---------------------------------------------------------------------------


def get_actor_context(request: Request) -> Optional[ActorContext]:
    """Retrieve actor context already resolved by resolve_actor_context.

    Returns None if the dependency has not run (e.g., unauthenticated route).
    Use as Depends(get_actor_context) only in routes that also depend on
    resolve_actor_context or where the context is optional.
    """
    return getattr(request.state, "actor_ctx", None)


# ---------------------------------------------------------------------------
# require_actor_with_permission — decorator factory (AC-19/20/21/22)
# ---------------------------------------------------------------------------


def require_actor_with_permission(
    action: str,
    *,
    scope_kind: Optional[str] = None,
    scope_param: str = "building_id",
):
    """FastAPI dependency factory.

    Returns a dependency that:
      1. Resolves actor context.
      2. Checks permission (AC-19/20/21).
      3. Checks scope (NFR-05) if scope_kind is provided.
      4. Checks 30d termination lockdown (AC-43).
      5. Checks owner-self-mutate block (AC-18).

    Usage:
        @router.post("/contracts")
        async def create_contract(
            actor_ctx: ActorContext = Depends(require_actor_with_permission(
                CONTRACT_CREATE, scope_kind="building", scope_param="building_id"
            )),
        ):
            ...
    """
    from app.services.scope_check import resolve_to_building_id
    from app.services.permission_set import is_lockdown_blocked, is_mutation_action

    async def _check(
        request: Request,
        actor_ctx: ActorContext = Depends(resolve_actor_context),
        db: Session = Depends(get_db),
    ) -> ActorContext:
        # 1. Permission check (AC-19/20/21)
        if not actor_ctx.has_permission(action):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"code": "PERMISSION_DENIED", "action": action},
            )

        # 2. Scope check (NFR-05)
        if scope_kind and actor_ctx.is_acting_on_behalf:
            raw_target_id = (
                request.path_params.get(scope_param)
                or request.query_params.get(scope_param)
            )
            if raw_target_id is not None:
                try:
                    target_id = int(raw_target_id)
                except (ValueError, TypeError) as exc:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail={
                            "code": "INVALID_SCOPE_PARAM",
                            "param": scope_param,
                        },
                    ) from exc

                building_id = resolve_to_building_id(db, request, scope_kind, target_id)
                if building_id is None or not actor_ctx.is_in_scope(building_id):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail={
                            "code": "OUT_OF_SCOPE",
                            "building_id": building_id,
                            "delegation_id": actor_ctx.delegation_id,
                        },
                    )

        # 3. Lockdown check (AC-43) — terminating-phase blocks certain actions
        if actor_ctx.delegation_id and actor_ctx.is_acting_on_behalf:
            delegation = (
                db.query(Delegation)
                .filter(Delegation.id == actor_ctx.delegation_id)
                .first()
            )
            if delegation and delegation.status == "terminating":
                if is_lockdown_blocked(action):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail={"code": "LOCKDOWN_BLOCKED", "action": action},
                    )

        # 4. Owner-self-mutate block (AC-18)
        # If owner is acting for themselves AND this action is a mutation AND
        # they have an active delegation, block with a 409 prompt.
        if not actor_ctx.is_acting_on_behalf and is_mutation_action(action):
            active_delegation = (
                db.query(Delegation)
                .filter(
                    Delegation.owner_id == actor_ctx.actor_user_id,
                    Delegation.status == "active",
                )
                .first()
            )
            if active_delegation is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={
                        "code": "OWNER_MUTATION_WHILE_DELEGATED",
                        "hint": (
                            "Pause delegation before mutating, "
                            "or send instruction to operator."
                        ),
                        "delegation_id": active_delegation.id,
                    },
                )

        return actor_ctx

    return _check
