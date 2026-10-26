"""Repository for jp_tenant_applications and jp_application_reviews.

Multi-tenant isolation: every list query MUST filter by org_id.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.domain.jp.application import JpApplicationReview, JpTenantApplication


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpTenantApplicationRepository:
    """Org-scoped CRUD for jp_tenant_applications.

    Multi-tenant isolation: every list query MUST filter by org_id.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id(self, app_id: int) -> Optional[JpTenantApplication]:
        """Fetch single record by PK. Returns None if not found."""
        return (
            self.db.query(JpTenantApplication)
            .filter(JpTenantApplication.id == app_id)
            .first()
        )

    def get_by_id_org(self, app_id: int, org_id: str) -> Optional[JpTenantApplication]:
        """Fetch single record — org-scoped.

        # MULTI-TENANT ISOLATION: org_id filter enforced here.
        """
        return (
            self.db.query(JpTenantApplication)
            .filter(
                JpTenantApplication.id == app_id,
                JpTenantApplication.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def get_by_id_applicant(
        self, app_id: int, applicant_user_id: int
    ) -> Optional[JpTenantApplication]:
        """Fetch application — scoped to the applicant (tenant own-scope)."""
        return (
            self.db.query(JpTenantApplication)
            .filter(
                JpTenantApplication.id == app_id,
                JpTenantApplication.applicant_user_id == applicant_user_id,
            )
            .first()
        )

    def list_by_org(
        self,
        org_id: str,
        *,
        status: Optional[str] = None,
        listing_id: Optional[str] = None,
        applicant_user_id: Optional[int] = None,
    ) -> list[JpTenantApplication]:
        """List applications for an org with optional filters.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        q = (
            self.db.query(JpTenantApplication)
            .filter(JpTenantApplication.org_id == org_id)  # MULTI-TENANT ISOLATION
        )
        if status:
            q = q.filter(JpTenantApplication.status == status)
        if listing_id:
            q = q.filter(JpTenantApplication.listing_id == listing_id)
        if applicant_user_id is not None:
            q = q.filter(JpTenantApplication.applicant_user_id == applicant_user_id)
        return q.order_by(JpTenantApplication.created_at.desc()).all()

    def list_by_applicant_org(self, applicant_user_id: int, org_id: str) -> list[JpTenantApplication]:
        """List all applications by a specific tenant in an org.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        return (
            self.db.query(JpTenantApplication)
            .filter(
                JpTenantApplication.applicant_user_id == applicant_user_id,
                JpTenantApplication.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .order_by(JpTenantApplication.created_at.desc())
            .all()
        )

    def create(
        self,
        *,
        org_id: Optional[str],
        listing_id: str,
        applicant_user_id: int,
        employer_name: Optional[str] = None,
        annual_income_jpy: Optional[Decimal] = None,
        guarantor_name: Optional[str] = None,
        guarantor_phone: Optional[str] = None,
        emergency_contact_name: Optional[str] = None,
        emergency_contact_phone: Optional[str] = None,
        documents: Optional[dict] = None,
    ) -> JpTenantApplication:
        """Create and flush a new application in draft status."""
        now = _now_utc()
        app = JpTenantApplication(
            org_id=org_id,
            region="jp",
            listing_id=listing_id,
            applicant_user_id=applicant_user_id,
            employer_name=employer_name,
            annual_income_jpy=annual_income_jpy,
            guarantor_name=guarantor_name,
            guarantor_phone=guarantor_phone,
            emergency_contact_name=emergency_contact_name,
            emergency_contact_phone=emergency_contact_phone,
            documents=documents,
            status="draft",
            created_at=now,
            updated_at=now,
        )
        self.db.add(app)
        self.db.flush()
        return app

    def update_status(
        self,
        app: JpTenantApplication,
        *,
        status: str,
        submitted_at: Optional[datetime] = None,
    ) -> JpTenantApplication:
        """Update application status. Service layer must validate transitions."""
        app.status = status
        if submitted_at is not None:
            app.submitted_at = submitted_at
        app.updated_at = _now_utc()
        self.db.flush()
        return app

    def update(self, app: JpTenantApplication, **fields: object) -> JpTenantApplication:
        """Apply field updates and flush. Only allowed on draft applications."""
        allowed = {
            "employer_name", "annual_income_jpy", "guarantor_name",
            "guarantor_phone", "emergency_contact_name", "emergency_contact_phone",
            "documents",
        }
        for key, value in fields.items():
            if key in allowed:
                setattr(app, key, value)
        app.updated_at = _now_utc()
        self.db.flush()
        return app


class JpApplicationReviewRepository:
    """Org-scoped CRUD for jp_application_reviews.

    Multi-tenant isolation: every list query MUST filter by org_id.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id_org(self, review_id: int, org_id: str) -> Optional[JpApplicationReview]:
        """Fetch single record — org-scoped.

        # MULTI-TENANT ISOLATION: org_id filter enforced here.
        """
        return (
            self.db.query(JpApplicationReview)
            .filter(
                JpApplicationReview.id == review_id,
                JpApplicationReview.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def list_by_application_org(
        self, application_id: int, org_id: str
    ) -> list[JpApplicationReview]:
        """List all reviews for an application within an org.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        return (
            self.db.query(JpApplicationReview)
            .filter(
                JpApplicationReview.application_id == application_id,
                JpApplicationReview.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .order_by(JpApplicationReview.created_at.desc())
            .all()
        )

    def list_by_org(
        self,
        org_id: str,
        *,
        decision: Optional[str] = None,
    ) -> list[JpApplicationReview]:
        """List all reviews for an org with optional decision filter.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        q = (
            self.db.query(JpApplicationReview)
            .filter(JpApplicationReview.org_id == org_id)  # MULTI-TENANT ISOLATION
        )
        if decision:
            q = q.filter(JpApplicationReview.decision == decision)
        return q.order_by(JpApplicationReview.created_at.desc()).all()

    def create(
        self,
        *,
        application_id: int,
        reviewer_user_id: int,
        decision: str,
        org_id: Optional[str],
        notes: Optional[str] = None,
    ) -> JpApplicationReview:
        """Create and flush a new review decision."""
        now = _now_utc()
        review = JpApplicationReview(
            application_id=application_id,
            reviewer_user_id=reviewer_user_id,
            decision=decision,
            notes=notes,
            decided_at=now,
            org_id=org_id,
            region="jp",
            created_at=now,
            updated_at=now,
        )
        self.db.add(review)
        self.db.flush()
        return review
