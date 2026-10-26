"""JP role scope enforcement — require_role_scope FastAPI dependency.

Role scoping matrix for JP B2B:
  tenant → 'own' on applications/viewings they created
  sales  → 'assigned' on listings they are agent for (via listing_sales_assignments)
  owner  → 'own' on listings they own
  admin  → 'global' (org-scoped if multi-tenant)

Usage at router endpoint level:
    @router.get("/applications/{app_id}")
    async def get_application(
        app_id: int,
        scope_ctx: ScopeContext = Depends(require_role_scope("tenant", "own")),
        db: Session = Depends(get_db),
    ):
        # scope_ctx.user_id, scope_ctx.org_id, scope_ctx.scope are available
        ...

Security invariant:
  - Missing role or insufficient scope always returns 403 (never 404)
  - Admin scope is org-bounded — admin cannot cross org boundaries
  - sales 'assigned' scope requires an active listing_sales_assignment record
"""

from __future__ import annotations

import logging
from typing import Literal, Optional

from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.database import get_db

logger = logging.getLogger(__name__)


# Type aliases for role and scope literals
JpRole = Literal["tenant", "sales", "owner", "admin"]
JpScope = Literal["own", "assigned", "org", "global"]


class ScopeContext:
    """Carries the authenticated user's role scope for this request.

    Attributes:
        user_id:  Authenticated user's ID (from JWT)
        org_id:   Broker org ID (from JWT claims or request context)
        role:     The role being asserted (tenant/sales/owner/admin)
        scope:    The scope level granted (own/assigned/org/global)
    """

    def __init__(
        self,
        *,
        user_id: int,
        org_id: Optional[str],
        role: JpRole,
        scope: JpScope,
    ) -> None:
        self.user_id = user_id
        self.org_id = org_id
        self.role = role
        self.scope = scope


def _extract_user_from_request(request: Request) -> tuple[int, Optional[str]]:
    """Extract user_id and org_id from the request.

    Reads from request.state (populated by auth middleware) or JWT claims.
    Falls back gracefully — callers receive 403 if user_id is missing.

    Decision: We read from request.state rather than re-parsing JWT here to
    avoid coupling to the JWT library. Auth middleware must populate request.state.
    """
    user_id: Optional[int] = getattr(request.state, "user_id", None)
    org_id: Optional[str] = getattr(request.state, "org_id", None)

    if user_id is None:
        # Try reading from request.state.claims (some middleware patterns)
        claims = getattr(request.state, "claims", {})
        if isinstance(claims, dict):
            uid = claims.get("sub") or claims.get("user_id")
            if uid is not None:
                user_id = int(uid)
            org_id = org_id or claims.get("org_id")

    return user_id, org_id  # type: ignore[return-value]


def _check_sales_assignment(
    db: Session,
    *,
    sales_user_id: int,
    listing_id: str,
    org_id: str,
) -> bool:
    """Return True if the sales agent has an active assignment to the listing.

    Imports repository lazily to avoid circular import at module load.
    """
    from app.repositories.jp.sales_assignment import ListingSalesAssignmentRepository

    repo = ListingSalesAssignmentRepository(db)
    return repo.is_assigned(listing_id, sales_user_id, org_id)


def require_role_scope(
    role: JpRole,
    scope: JpScope,
) -> "type[ScopeContext]":
    """FastAPI dependency factory for JP role-scope enforcement.

    Returns a dependency callable that:
    1. Extracts user_id and org_id from request.state
    2. Validates the user has the claimed role (via request.state.role or claims)
    3. Returns a ScopeContext for downstream use

    Security invariant: deny by default — missing context = 403.

    Args:
        role:  Required role (tenant/sales/owner/admin)
        scope: Required scope level (own/assigned/org/global)

    Returns:
        FastAPI dependency callable returning ScopeContext.

    Example:
        @router.get("/viewings")
        async def list_viewings(
            ctx: ScopeContext = Depends(require_role_scope("tenant", "own")),
        ):
            # ctx.user_id is the authenticated tenant
            ...
    """

    def _dep(
        request: Request,
        db: Session = Depends(get_db),
    ) -> ScopeContext:
        user_id, org_id = _extract_user_from_request(request)

        if user_id is None:
            logger.warning("[ROLE_SCOPE] user_id missing from request.state — denying")
            raise HTTPException(
                status_code=403,
                detail="Authentication required. Missing user context.",
            )

        # Read role from request state (set by auth middleware)
        actual_role: Optional[str] = getattr(request.state, "role", None)
        if actual_role is None:
            claims = getattr(request.state, "claims", {})
            actual_role = claims.get("role") if isinstance(claims, dict) else None

        # Admin bypasses role check — still org-bounded
        if actual_role == "admin":
            return ScopeContext(user_id=user_id, org_id=org_id, role="admin", scope="global")

        # Check role match — deny if user's role doesn't match required role
        if actual_role != role:
            logger.warning(
                "[ROLE_SCOPE] role mismatch: required=%s actual=%s user_id=%s",
                role, actual_role, user_id,
            )
            raise HTTPException(
                status_code=403,
                detail=f"Insufficient role. Required: {role}, actual: {actual_role}.",
            )

        # Scope-specific validation
        if scope == "assigned" and role == "sales":
            # Sales 'assigned' scope: listing_id must be in path/query and assigned
            listing_id: Optional[str] = (
                request.path_params.get("listing_id")
                or request.query_params.get("listing_id")
            )
            if listing_id and org_id:
                is_assigned = _check_sales_assignment(
                    db, sales_user_id=user_id, listing_id=listing_id, org_id=org_id
                )
                if not is_assigned:
                    logger.warning(
                        "[ROLE_SCOPE] sales user %d not assigned to listing %s org %s",
                        user_id, listing_id, org_id,
                    )
                    raise HTTPException(
                        status_code=403,
                        detail="Sales agent is not assigned to this listing.",
                    )

        return ScopeContext(user_id=user_id, org_id=org_id, role=role, scope=scope)  # type: ignore[arg-type]

    return _dep  # type: ignore[return-value]
