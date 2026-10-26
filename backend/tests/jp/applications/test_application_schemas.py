"""Tests for JP tenant application Pydantic schemas."""

from __future__ import annotations

import os
from decimal import Decimal

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest
from pydantic import ValidationError

from app.schemas.jp.application import (
    JpApplicationReviewCreate,
    JpTenantApplicationCreate,
    JpTenantApplicationUpdate,
)


class TestJpTenantApplicationCreate:
    """Schema validation for application creation."""

    def test_minimal_valid(self) -> None:
        schema = JpTenantApplicationCreate(listing_id="listing-001")
        assert schema.listing_id == "listing-001"
        assert schema.employer_name is None

    def test_full_valid(self) -> None:
        schema = JpTenantApplicationCreate(
            listing_id="listing-001",
            employer_name="株式会社テスト",
            annual_income_jpy=Decimal("5000000"),
            guarantor_name="山田太郎",
            guarantor_phone="09000000001",
            emergency_contact_name="山田花子",
            emergency_contact_phone="09000000002",
            documents={"income_cert": "https://storage.example.com/cert.pdf"},
        )
        assert schema.annual_income_jpy == Decimal("5000000")
        assert schema.documents == {"income_cert": "https://storage.example.com/cert.pdf"}

    def test_annual_income_must_be_positive(self) -> None:
        with pytest.raises(ValidationError):
            JpTenantApplicationCreate(
                listing_id="listing-001",
                annual_income_jpy=Decimal("0"),
            )

    def test_annual_income_negative_rejected(self) -> None:
        with pytest.raises(ValidationError):
            JpTenantApplicationCreate(
                listing_id="listing-001",
                annual_income_jpy=Decimal("-1000"),
            )

    def test_listing_id_required(self) -> None:
        with pytest.raises(ValidationError):
            JpTenantApplicationCreate()

    def test_empty_listing_id_rejected(self) -> None:
        with pytest.raises(ValidationError):
            JpTenantApplicationCreate(listing_id="")


class TestJpApplicationReviewCreate:
    """Schema validation for review decisions."""

    def test_valid_approved(self) -> None:
        schema = JpApplicationReviewCreate(decision="approved")
        assert schema.decision == "approved"

    def test_valid_rejected(self) -> None:
        schema = JpApplicationReviewCreate(decision="rejected", notes="Income too low")
        assert schema.notes == "Income too low"

    def test_valid_needs_info(self) -> None:
        schema = JpApplicationReviewCreate(decision="needs_info")
        assert schema.decision == "needs_info"

    def test_invalid_decision_rejected(self) -> None:
        with pytest.raises(ValidationError):
            JpApplicationReviewCreate(decision="maybe")

    def test_notes_optional(self) -> None:
        schema = JpApplicationReviewCreate(decision="approved")
        assert schema.notes is None
