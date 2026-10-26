"""JP tenant application (入居申込) endpoints.

Routes:
  POST /api/jp/applications              — tenant creates draft application
  GET  /api/jp/applications              — list applications (reviewer view)
  GET  /api/jp/applications/{id}         — get single application
  POST /api/jp/applications/{id}/submit  — tenant submits draft
  POST /api/jp/applications/{id}/review  — reviewer puts in_review (optional step)
  GET  /api/jp/applications/{id}/upload-url — document upload URL stub (TODO P2)

All routes guarded by require_region('jp').
Status transitions enforced in app/services/jp/application/intake.py.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.application import (
    JpApplicationReviewRepository,
    JpTenantApplicationRepository,
)
from app.schemas.jp.application import (
    JpTenantApplicationCreate,
    JpTenantApplicationResponse,
    JpTenantApplicationUpdate,
)
from app.services.jp.application.intake import (
    record_review_decision,
    start_review,
    submit_application,
)

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/applications",
    tags=["jp-applications"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_actor(request: Request) -> tuple[Optional[int], Optional[str]]:
    user_id = getattr(request.state, "user_id", None)
    org_id = getattr(request.state, "org_id", None)
    return user_id, org_id


@router.post("", response_model=JpTenantApplicationResponse, status_code=201)
async def create_application(
    body: JpTenantApplicationCreate,
    request: Request,
    db: Session = Depends(get_db),
) -> JpTenantApplicationResponse:
    """Tenant creates a draft rental application."""
    user_id, org_id = _get_actor(request)
    if user_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpTenantApplicationRepository(db)
    app = repo.create(
        org_id=org_id,
        listing_id=body.listing_id,
        applicant_user_id=user_id,
        employer_name=body.employer_name,
        annual_income_jpy=body.annual_income_jpy,
        guarantor_name=body.guarantor_name,
        guarantor_phone=body.guarantor_phone,
        emergency_contact_name=body.emergency_contact_name,
        emergency_contact_phone=body.emergency_contact_phone,
        documents=body.documents,
    )
    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error("[JP_APPLICATIONS] create failed: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to create application") from exc

    return JpTenantApplicationResponse.model_validate(app)


@router.get("", response_model=list[JpTenantApplicationResponse])
async def list_applications(
    request: Request,
    status: Optional[str] = Query(None),
    listing_id: Optional[str] = Query(None),
    applicant_user_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
) -> list[JpTenantApplicationResponse]:
    """List applications for reviewers (sales/owner/admin). Org-scoped."""
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpTenantApplicationRepository(db)
    apps = repo.list_by_org(
        org_id, status=status, listing_id=listing_id, applicant_user_id=applicant_user_id
    )
    return [JpTenantApplicationResponse.model_validate(a) for a in apps]


@router.get("/{app_id}", response_model=JpTenantApplicationResponse)
async def get_application(
    app_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> JpTenantApplicationResponse:
    """Get a single application by ID."""
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpTenantApplicationRepository(db)
    app = repo.get_by_id_org(app_id, org_id)
    if app is None:
        raise HTTPException(status_code=404, detail="Application not found")

    return JpTenantApplicationResponse.model_validate(app)


@router.post("/{app_id}/submit", response_model=JpTenantApplicationResponse)
async def submit_application_endpoint(
    app_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> JpTenantApplicationResponse:
    """Tenant submits their draft application.

    Transition: draft → submitted
    """
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpTenantApplicationRepository(db)
    app = repo.get_by_id_org(app_id, org_id)
    if app is None:
        raise HTTPException(status_code=404, detail="Application not found")

    updated = submit_application(repo, app=app, actor_user_id=user_id)
    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to submit application") from exc

    return JpTenantApplicationResponse.model_validate(updated)


@router.post("/{app_id}/start-review", response_model=JpTenantApplicationResponse)
async def start_review_endpoint(
    app_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> JpTenantApplicationResponse:
    """Reviewer moves application to in_review.

    Transition: submitted → in_review
    """
    user_id, org_id = _get_actor(request)
    if user_id is None or org_id is None:
        raise HTTPException(status_code=403, detail="Authentication required")

    repo = JpTenantApplicationRepository(db)
    app = repo.get_by_id_org(app_id, org_id)
    if app is None:
        raise HTTPException(status_code=404, detail="Application not found")

    updated = start_review(repo, app=app, reviewer_user_id=user_id, org_id=org_id)
    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to start review") from exc

    return JpTenantApplicationResponse.model_validate(updated)


@router.get("/{app_id}/upload-url")
async def get_upload_url(
    app_id: int,
    doc_type: str = Query(..., description="Document type key (e.g. income_cert, id_front)"),
    request: Request = None,
    db: Session = Depends(get_db),
) -> dict:
    """Get a pre-signed upload URL for a document.

    TODO P2: Implement Supabase Storage pre-signed URL issuance.
    See app/services/storage/ for the existing Supabase pattern.
    This stub returns 501 to indicate the feature is not yet implemented.
    """
    raise HTTPException(
        status_code=501,
        detail=(
            "Document upload URL issuance not yet implemented. "
            "Tracked as P2 work item: integrate Supabase Storage pre-signed URLs."
        ),
    )
