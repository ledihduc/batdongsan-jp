"""JP application review (審査決定) endpoints.

Routes:
  POST /api/jp/applications/{app_id}/reviews  — submit review decision (sales/owner)
  GET  /api/jp/applications/{app_id}/reviews  — list reviews for an application

All routes guarded by require_region('jp').
Decision recording enforced in app/services/jp/application/intake.py.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.application import (
    JpApplicationReviewRepository,
    JpTenantApplicationRepository,
)
from app.schemas.jp.application import (
    JpApplicationReviewCreate,
    JpApplicationReviewResponse,
)
from app.services.jp.application.intake import record_review_decision

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/applications",
    tags=["jp-application-reviews"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_actor(request: Request) -> tuple[Optional[int], Optional[str]]:
    user_id = getattr(request.state, "user_id", None)
    org_id = getattr(request.state, "org_id", None)
    return user_id, org_id


@router.post("/{app_id}/reviews", response_model=JpApplicationReviewResponse, status_code=201)
async def submit_review_decision(
    app_id: int,
    body: JpApplicationReviewCreate,
    request: Request,
    db: Session = Depends(get_db),
) -> JpApplicationReviewResponse:
    """Sales agent or owner submits a review decision on an application.

    Decision: approved | rejected | needs_info
    Terminal decisions (approved/rejected) also transition the application status.
    """
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    app_repo = JpTenantApplicationRepository(db)
    review_repo = JpApplicationReviewRepository(db)

    app = app_repo.get_by_id_org(app_id, org_id)
    if app is None:
        raise HTTPException(status_code=404, detail="Application not found")

    _, review = record_review_decision(
        app_repo,
        review_repo,
        app=app,
        reviewer_user_id=user_id,
        org_id=org_id,
        decision=body.decision,
        notes=body.notes,
    )

    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("[JP_REVIEWS] submit failed app_id=%d: %s", app_id, exc)
        raise HTTPException(status_code=500, detail="Failed to record review decision") from exc

    return JpApplicationReviewResponse.model_validate(review)


@router.get("/{app_id}/reviews", response_model=list[JpApplicationReviewResponse])
async def list_reviews_for_application(
    app_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> list[JpApplicationReviewResponse]:
    """List all review decisions for a given application."""
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    # Verify application belongs to org
    app_repo = JpTenantApplicationRepository(db)
    app = app_repo.get_by_id_org(app_id, org_id)
    if app is None:
        raise HTTPException(status_code=404, detail="Application not found")

    review_repo = JpApplicationReviewRepository(db)
    reviews = review_repo.list_by_application_org(app_id, org_id)
    return [JpApplicationReviewResponse.model_validate(r) for r in reviews]
