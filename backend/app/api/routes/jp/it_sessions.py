"""IT重説 session endpoints.

Routes:
  POST /api/jp/it-sessions                    — create session (Zoom meeting request)
  POST /api/jp/it-sessions/{id}/consent       — tenant consent before entry
  GET  /api/jp/it-sessions/{id}               — get session detail

All routes guarded by require_region('jp').
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.it_session import JpItSessionRepository
from app.schemas.jp.it_session import CreateItSessionRequest, ItSessionResponse
from app.services.it_session.scheduler import capture_tenant_consent, create_session

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/it-sessions",
    tags=["jp-it-sessions"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_org_id(request: Request) -> str:
    org_id: Optional[str] = getattr(request.state, "org_id", None)
    if not org_id:
        raise HTTPException(status_code=401, detail="org_id not found in token")
    return org_id


@router.post("", response_model=ItSessionResponse, status_code=201)
async def create_it_session(
    body: CreateItSessionRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> ItSessionResponse:
    """Create an IT重説 session and request a Zoom meeting."""
    org_id = _get_org_id(request)

    try:
        session = await create_session(
            org_id=org_id,
            viewing_id=body.viewing_id,
            takken_shi_id=body.takken_shi_id,
            scheduled_at=body.scheduled_at,
            db=db,
        )
        db.commit()
        db.refresh(session)
    except RuntimeError as exc:
        db.rollback()
        logger.error("create_it_session failed: %s", exc)
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception as exc:
        db.rollback()
        logger.error("create_it_session unexpected error: %s", exc)
        raise HTTPException(status_code=500, detail="Session creation failed") from exc

    return ItSessionResponse.model_validate(session)


@router.post("/{session_id}/consent", response_model=ItSessionResponse)
async def record_tenant_consent(
    session_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> ItSessionResponse:
    """Record tenant's explicit consent before entering IT重説 session.

    Must be called before providing the tenant with the Zoom join URL.
    """
    org_id = _get_org_id(request)

    try:
        session = await capture_tenant_consent(
            session_id=session_id,
            org_id=org_id,
            db=db,
        )
        db.commit()
        db.refresh(session)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        db.rollback()
        logger.error("record_tenant_consent failed: session=%d err=%s", session_id, exc)
        raise HTTPException(status_code=500, detail="Consent recording failed") from exc

    return ItSessionResponse.model_validate(session)


@router.get("/{session_id}", response_model=ItSessionResponse)
async def get_it_session(
    session_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> ItSessionResponse:
    """Get IT重説 session detail."""
    org_id = _get_org_id(request)
    repo = JpItSessionRepository(db)
    session = repo.get_by_id_org(session_id, org_id)
    if session is None:
        raise HTTPException(status_code=404, detail="IT session not found")
    return ItSessionResponse.model_validate(session)
