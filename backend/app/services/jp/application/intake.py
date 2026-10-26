"""JP 入居申込 (tenant application) intake service — validation + status transitions.

State machine:
  draft → submitted → in_review → approved | rejected

Transition rules:
  - draft → submitted: tenant action; application must have listing_id and applicant_user_id
  - submitted → in_review: agent/reviewer action
  - in_review → approved: reviewer decision
  - in_review → rejected: reviewer decision
  - Once approved/rejected, no further transitions allowed

NOTE: Document upload URL issuance deferred to P2 (Supabase Storage integration).
The 'documents' field accepts pre-signed URLs issued by the client's own upload call.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException

from app.domain.jp.application import JpTenantApplication, APPLICATION_STATUS_VALUES
from app.repositories.jp.application import (
    JpApplicationReviewRepository,
    JpTenantApplicationRepository,
)

logger = logging.getLogger(__name__)


class ApplicationIntakeError(Exception):
    """Raised for application business rule violations."""


# Valid state transitions — (current_status, allowed_next_statuses)
_TRANSITIONS: dict[str, list[str]] = {
    "draft": ["submitted"],
    "submitted": ["in_review"],
    "in_review": ["approved", "rejected"],
    "approved": [],
    "rejected": [],
}


def _assert_transition(app: JpTenantApplication, target_status: str) -> None:
    """Raise HTTPException if the status transition is not valid."""
    allowed = _TRANSITIONS.get(app.status, [])
    if target_status not in allowed:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Cannot transition application from '{app.status}' to '{target_status}'. "
                f"Allowed transitions from '{app.status}': {allowed or 'none (terminal)'}"
            ),
        )


def submit_application(
    app_repo: JpTenantApplicationRepository,
    *,
    app: JpTenantApplication,
    actor_user_id: int,
) -> JpTenantApplication:
    """Tenant submits their draft application.

    Transition: draft → submitted
    - Only the applicant can submit their own application.
    - Validates required fields are present before submission.

    Raises HTTPException on violation.
    """
    # Authorization: only the applicant can submit
    if app.applicant_user_id != actor_user_id:
        raise HTTPException(
            status_code=403,
            detail="Only the applicant can submit their own application.",
        )

    _assert_transition(app, "submitted")

    # Validate minimum required fields for submission
    if not app.listing_id:
        raise HTTPException(status_code=422, detail="listing_id is required for submission")

    return app_repo.update_status(
        app,
        status="submitted",
        submitted_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )


def start_review(
    app_repo: JpTenantApplicationRepository,
    *,
    app: JpTenantApplication,
    reviewer_user_id: int,
    org_id: str,
) -> JpTenantApplication:
    """Move application from submitted to in_review.

    Transition: submitted → in_review
    - Reviewer must be in the same org.
    - Any sales/owner user in the org can start a review.
    """
    _assert_transition(app, "in_review")

    # Org check
    if app.org_id and app.org_id != org_id:
        raise HTTPException(status_code=403, detail="Application does not belong to your org.")

    return app_repo.update_status(app, status="in_review")


def record_review_decision(
    app_repo: JpTenantApplicationRepository,
    review_repo: JpApplicationReviewRepository,
    *,
    app: JpTenantApplication,
    reviewer_user_id: int,
    org_id: str,
    decision: str,
    notes: Optional[str] = None,
) -> tuple[JpTenantApplication, object]:
    """Record a review decision and transition application to terminal status.

    For 'approved' or 'rejected': transitions application status to match decision.
    For 'needs_info': application stays in 'in_review' (reviewer must request more info).

    Returns (updated_application, review_record).
    """
    from app.domain.jp.application import REVIEW_DECISION_VALUES
    if decision not in REVIEW_DECISION_VALUES:
        raise HTTPException(
            status_code=422,
            detail=f"decision must be one of: {', '.join(REVIEW_DECISION_VALUES)}",
        )

    # Org check
    if app.org_id and app.org_id != org_id:
        raise HTTPException(status_code=403, detail="Application does not belong to your org.")

    # For terminal decisions, validate transition
    if decision in ("approved", "rejected"):
        _assert_transition(app, decision)

    # Create review record first
    review = review_repo.create(
        application_id=app.id,
        reviewer_user_id=reviewer_user_id,
        decision=decision,
        org_id=org_id,
        notes=notes,
    )

    # Update application status for terminal decisions
    if decision in ("approved", "rejected"):
        app = app_repo.update_status(app, status=decision)
        logger.info(
            "[APPLICATION] id=%d decision=%s reviewer=%d",
            app.id, decision, reviewer_user_id,
        )

    return app, review
