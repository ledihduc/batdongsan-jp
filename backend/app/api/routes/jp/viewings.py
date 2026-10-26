"""JP viewing (内見) endpoints.

Routes:
  POST /api/jp/viewings              — tenant creates viewing request
  GET  /api/jp/viewings              — list viewings (filterable)
  GET  /api/jp/viewings/{id}         — get single viewing
  POST /api/jp/viewings/{id}/confirm — agent confirms a slot
  POST /api/jp/viewings/{id}/cancel  — tenant or agent cancels
  POST /api/jp/viewings/{id}/complete — agent marks as completed

All routes guarded by require_region('jp').
State machine enforced in app/services/jp/viewing/scheduler.py.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.viewing import JpViewingRepository
from app.schemas.jp.viewing import (
    JpViewingCancelRequest,
    JpViewingConfirmRequest,
    JpViewingCreate,
    JpViewingResponse,
)
from app.services.jp.viewing.scheduler import (
    cancel_viewing,
    complete_viewing,
    confirm_viewing,
    create_viewing_request,
)

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/viewings",
    tags=["jp-viewings"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_actor(request: Request) -> tuple[Optional[int], Optional[str]]:
    """Extract user_id and org_id from request.state."""
    user_id = getattr(request.state, "user_id", None)
    org_id = getattr(request.state, "org_id", None)
    return user_id, org_id


@router.post("", response_model=JpViewingResponse, status_code=201)
async def create_viewing(
    body: JpViewingCreate,
    request: Request,
    db: Session = Depends(get_db),
) -> JpViewingResponse:
    """Tenant requests a viewing with 1-3 preferred slots."""
    user_id, org_id = _get_actor(request)
    if user_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpViewingRepository(db)
    viewing = create_viewing_request(
        repo,
        org_id=org_id,
        listing_id=body.listing_id,
        tenant_id=user_id,
        requested_slots=body.requested_slots,
        notes=body.notes,
    )
    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("[JP_VIEWINGS] create failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to create viewing request") from exc

    return JpViewingResponse.model_validate(viewing)


@router.get("", response_model=list[JpViewingResponse])
async def list_viewings(
    request: Request,
    status: Optional[str] = Query(None, description="Filter by status"),
    tenant_id: Optional[int] = Query(None),
    agent_id: Optional[int] = Query(None),
    listing_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
) -> list[JpViewingResponse]:
    """List viewings — filterable by status, tenant, agent, listing.

    Org-scoped by default. Admin can see all within org.
    """
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpViewingRepository(db)
    viewings = repo.list_by_org(
        org_id,
        status=status,
        tenant_id=tenant_id,
        agent_id=agent_id,
        listing_id=listing_id,
    )
    return [JpViewingResponse.model_validate(v) for v in viewings]


@router.get("/{viewing_id}", response_model=JpViewingResponse)
async def get_viewing(
    viewing_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> JpViewingResponse:
    """Get a single viewing by ID."""
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpViewingRepository(db)
    viewing = repo.get_by_id_org(viewing_id, org_id)
    if viewing is None:
        raise HTTPException(status_code=404, detail="Viewing not found")

    return JpViewingResponse.model_validate(viewing)


@router.post("/{viewing_id}/confirm", response_model=JpViewingResponse)
async def confirm_viewing_endpoint(
    viewing_id: int,
    body: JpViewingConfirmRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> JpViewingResponse:
    """Agent confirms a slot for the viewing.

    State machine: requested → confirmed
    """
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpViewingRepository(db)
    viewing = repo.get_by_id_org(viewing_id, org_id)
    if viewing is None:
        raise HTTPException(status_code=404, detail="Viewing not found")

    updated = confirm_viewing(
        repo,
        viewing=viewing,
        confirmed_slot_ts=body.confirmed_slot_ts,
        agent_user_id=user_id,
        org_id=org_id,
    )
    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to confirm viewing") from exc

    return JpViewingResponse.model_validate(updated)


@router.post("/{viewing_id}/cancel", response_model=JpViewingResponse)
async def cancel_viewing_endpoint(
    viewing_id: int,
    body: JpViewingCancelRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> JpViewingResponse:
    """Cancel a viewing. Allowed by tenant (creator) or assigned agent."""
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpViewingRepository(db)
    viewing = repo.get_by_id_org(viewing_id, org_id)
    if viewing is None:
        raise HTTPException(status_code=404, detail="Viewing not found")

    updated = cancel_viewing(repo, viewing=viewing, actor_user_id=user_id, org_id=org_id)
    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to cancel viewing") from exc

    return JpViewingResponse.model_validate(updated)


@router.post("/{viewing_id}/complete", response_model=JpViewingResponse)
async def complete_viewing_endpoint(
    viewing_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> JpViewingResponse:
    """Agent marks a confirmed viewing as completed."""
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpViewingRepository(db)
    viewing = repo.get_by_id_org(viewing_id, org_id)
    if viewing is None:
        raise HTTPException(status_code=404, detail="Viewing not found")

    updated = complete_viewing(repo, viewing=viewing, agent_user_id=user_id)
    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to complete viewing") from exc

    return JpViewingResponse.model_validate(updated)
