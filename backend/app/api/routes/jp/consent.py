"""JP APPI consent management endpoints.

Routes:
  POST /api/jp/consent/grant   — grant consent for one or more purposes
  GET  /api/jp/consent         — get current consent status for the user
  POST /api/jp/consent/revoke  — revoke consent for one purpose

All routes guarded by require_region('jp').
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.schemas.jp.consent import (
    ConsentStatusResponse,
    GrantConsentRequest,
    RevokeConsentRequest,
)
from app.services.consent.capture import get_consent_status, record_consent, revoke_consent

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/consent",
    tags=["jp-consent"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_user_id(request: Request) -> int:
    user_id: Optional[int] = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=401, detail="user_id not found in token")
    return user_id


@router.post("/grant", status_code=201)
async def grant_consent(
    body: GrantConsentRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> ConsentStatusResponse:
    """Grant consent for one or more purposes.

    Returns the updated consent status after granting.
    """
    user_id = _get_user_id(request)

    try:
        record_consent(
            user_id=user_id,
            purposes=body.purposes,
            db=db,
            request=request,
            consent_version=body.consent_version,
        )
        db.commit()
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        db.rollback()
        logger.error("grant_consent failed: user=%d err=%s", user_id, exc)
        raise HTTPException(status_code=500, detail="Failed to record consent") from exc

    status = get_consent_status(user_id, db)
    return ConsentStatusResponse(user_id=user_id, consents=status)


@router.get("", response_model=ConsentStatusResponse)
async def get_current_consent(
    request: Request,
    db: Session = Depends(get_db),
) -> ConsentStatusResponse:
    """Return current active consent status for the authenticated user."""
    user_id = _get_user_id(request)
    status = get_consent_status(user_id, db)
    return ConsentStatusResponse(user_id=user_id, consents=status)


@router.post("/revoke", response_model=ConsentStatusResponse)
async def revoke_consent_endpoint(
    body: RevokeConsentRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> ConsentStatusResponse:
    """Revoke consent for one purpose."""
    user_id = _get_user_id(request)

    try:
        revoke_consent(user_id=user_id, purpose=body.purpose, db=db)
        db.commit()
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        db.rollback()
        logger.error("revoke_consent failed: user=%d err=%s", user_id, exc)
        raise HTTPException(status_code=500, detail="Failed to revoke consent") from exc

    status = get_consent_status(user_id, db)
    return ConsentStatusResponse(user_id=user_id, consents=status)
