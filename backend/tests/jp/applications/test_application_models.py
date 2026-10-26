"""Tests for JpTenantApplication and JpApplicationReview ORM models — isolated SQLite."""

from __future__ import annotations

import os
from datetime import datetime
from decimal import Decimal

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest
from sqlalchemy import (
    Column, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text, create_engine,
)
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class _TestBase(DeclarativeBase):
    """Isolated declarative base — avoids full app ORM mapper initialization."""


class _JpTenantApplication(_TestBase):
    __tablename__ = "jp_tenant_applications"
    id = Column(Integer, primary_key=True, autoincrement=True)
    org_id = Column(String(64), nullable=True)
    region = Column(String(3), nullable=False, default="jp")
    listing_id = Column(String(64), nullable=False)
    applicant_user_id = Column(Integer, nullable=False)
    employer_name = Column(String(200), nullable=True)
    annual_income_jpy = Column(Numeric(12, 0), nullable=True)
    guarantor_name = Column(String(200), nullable=True)
    guarantor_phone = Column(String(20), nullable=True)
    emergency_contact_name = Column(String(200), nullable=True)
    emergency_contact_phone = Column(String(20), nullable=True)
    documents = Column(JSON, nullable=True)
    status = Column(String(20), nullable=False, default="draft")
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)
    submitted_at = Column(DateTime, nullable=True)


class _JpApplicationReview(_TestBase):
    __tablename__ = "jp_application_reviews"
    id = Column(Integer, primary_key=True, autoincrement=True)
    application_id = Column(Integer, ForeignKey("jp_tenant_applications.id"), nullable=False)
    reviewer_user_id = Column(Integer, nullable=False)
    decision = Column(String(20), nullable=False)
    notes = Column(Text, nullable=True)
    decided_at = Column(DateTime, nullable=True)
    org_id = Column(String(64), nullable=True)
    region = Column(String(3), nullable=False, default="jp")
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)


@pytest.fixture(scope="module")
def sqlite_session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    _TestBase.metadata.create_all(engine)
    SF = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    with SF() as session:
        yield session
    _TestBase.metadata.drop_all(engine)


class TestJpTenantApplicationModel:
    def test_create_draft(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        app = _JpTenantApplication(
            org_id="org-001",
            listing_id="listing-001",
            applicant_user_id=42,
            employer_name="テスト株式会社",
            annual_income_jpy=Decimal("5000000"),
            status="draft",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(app)
        sqlite_session.flush()

        assert app.id is not None
        assert app.status == "draft"
        assert app.submitted_at is None

    def test_pii_fields_stored(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        app = _JpTenantApplication(
            org_id="org-001",
            listing_id="listing-002",
            applicant_user_id=43,
            guarantor_name="山田太郎",
            guarantor_phone="09012345678",
            emergency_contact_name="山田花子",
            emergency_contact_phone="09087654321",
            status="draft",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(app)
        sqlite_session.flush()
        assert app.guarantor_name == "山田太郎"
        assert app.guarantor_phone == "09012345678"

    def test_documents_stored_as_json(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        docs = {"income_cert": "https://example.com/cert.pdf"}
        app = _JpTenantApplication(
            org_id="org-001",
            listing_id="listing-003",
            applicant_user_id=44,
            documents=docs,
            status="draft",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(app)
        sqlite_session.flush()
        assert isinstance(app.documents, dict)
        assert app.documents["income_cert"] == "https://example.com/cert.pdf"


class TestJpApplicationReviewModel:
    def test_create_review(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        app = _JpTenantApplication(
            org_id="org-001",
            listing_id="listing-review-001",
            applicant_user_id=45,
            status="in_review",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(app)
        sqlite_session.flush()

        review = _JpApplicationReview(
            application_id=app.id,
            reviewer_user_id=99,
            decision="approved",
            notes="All documents verified",
            decided_at=now,
            org_id="org-001",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(review)
        sqlite_session.flush()

        assert review.id is not None
        assert review.decision == "approved"
        assert review.application_id == app.id
