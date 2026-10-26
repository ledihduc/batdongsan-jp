"""SQLAlchemy 2.0 models for JP tenant applications and review decisions.

Tables:
  jp_tenant_applications — 入居申込 (tenant rental application)
  jp_application_reviews — 審査決定 (application review decision)

入居申込 flow:
  tenant creates draft → submits → agent/owner reviews → approved | rejected

PII NOTICE: Fields annual_income_jpy, guarantor_name, guarantor_phone,
emergency_contact_name, emergency_contact_phone contain personal information
subject to APPI (個人情報保護法). Field-level encryption deferred to P2 APPI
work item. These fields are tagged with comment "pii=True" for discovery tooling.

Design decisions:
- Managed by migration 0147_jp_applications (additive, nullable, idempotent).
- documents stored as JSON (JSONB on Postgres) — dict keyed by doc type.
- No FK constraints on listing_id/applicant_user_id to keep JP domain isolated.
- org_id: multi-tenant isolation. Every repository list() MUST filter by org_id.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any, Optional

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


# Valid application status values — state machine truth table.
APPLICATION_STATUS_VALUES = ("draft", "submitted", "in_review", "approved", "rejected")

# Valid review decision values.
REVIEW_DECISION_VALUES = ("approved", "rejected", "needs_info")


class JpTenantApplication(Base):
    """JP rental application submitted by a tenant (入居申込).

    State machine: draft → submitted → in_review → approved | rejected
    Transitions are enforced in app/services/jp/application/intake.py.

    PII fields: employer_name, annual_income_jpy, guarantor_name, guarantor_phone,
    emergency_contact_name, emergency_contact_phone — see module docstring.

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(JpTenantApplication.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_tenant_applications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Multi-tenant broker org isolation
    org_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    # Target listing (no FK to keep JP domain isolated)
    listing_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Listing UUID for this application",
    )

    # Tenant applicant
    applicant_user_id: Mapped[int] = mapped_column(
        Integer, nullable=False, index=True,
        comment="User ID of the tenant applicant",
    )

    # --- Employment info (PII) ---
    employer_name: Mapped[Optional[str]] = mapped_column(
        String(200), nullable=True,
        comment="勤務先会社名. pii=True",
    )
    # Annual income in JPY — MUST be positive if provided (validated in schema)
    annual_income_jpy: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(12, 0), nullable=True,
        comment="年収 in JPY. pii=True. Must be positive if provided.",
    )

    # --- 連帯保証人 (guarantor) (PII) ---
    guarantor_name: Mapped[Optional[str]] = mapped_column(
        String(200), nullable=True,
        comment="連帯保証人氏名. pii=True",
    )
    guarantor_phone: Mapped[Optional[str]] = mapped_column(
        String(20), nullable=True,
        comment="連帯保証人電話番号. pii=True",
    )

    # --- 緊急連絡先 (emergency contact) (PII) ---
    emergency_contact_name: Mapped[Optional[str]] = mapped_column(
        String(200), nullable=True,
        comment="緊急連絡先氏名. pii=True",
    )
    emergency_contact_phone: Mapped[Optional[str]] = mapped_column(
        String(20), nullable=True,
        comment="緊急連絡先電話番号. pii=True",
    )

    # Document upload references — dict keyed by doc type string
    # e.g. {"income_cert": "https://...", "id_front": "https://..."}
    documents: Mapped[Optional[Any]] = mapped_column(
        JSON, nullable=True,
        comment="JSON dict of document URLs keyed by doc type",
    )

    # State machine status
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="draft",
        comment="State: draft | submitted | in_review | approved | rejected",
    )

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=_now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
    submitted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True,
        comment="When tenant submitted the application (draft → submitted transition)",
    )

    # One-to-many: an application may have multiple review iterations
    reviews: Mapped[list["JpApplicationReview"]] = relationship(
        "JpApplicationReview", back_populates="application", lazy="select",
    )


class JpApplicationReview(Base):
    """Review decision record for a JP tenant application (審査決定).

    Multiple reviews may exist per application (e.g. needs_info → re-submit → approved).
    The latest review with a terminal decision (approved/rejected) is authoritative.

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(JpApplicationReview.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_application_reviews"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # FK to parent application
    application_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("jp_tenant_applications.id"), nullable=False, index=True,
    )

    # Reviewer (sales agent or owner)
    reviewer_user_id: Mapped[int] = mapped_column(
        Integer, nullable=False, index=True,
        comment="User ID of the reviewer (sales or owner role)",
    )

    # Decision
    decision: Mapped[str] = mapped_column(
        String(20), nullable=False,
        comment="approved | rejected | needs_info",
    )

    # Notes — may be shared with applicant for needs_info cases
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # When reviewer finalized the decision
    decided_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True,
        comment="When reviewer finalized the decision",
    )

    # Multi-tenant isolation
    org_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=_now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )

    # Relationship back to parent application
    application: Mapped[JpTenantApplication] = relationship(
        "JpTenantApplication", back_populates="reviews", lazy="select",
    )
