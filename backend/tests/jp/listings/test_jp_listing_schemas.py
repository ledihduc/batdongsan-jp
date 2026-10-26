"""Tests for JP listing Pydantic schemas — rental terms, property info, transit.

Uses in-memory validation only (no DB required).
Covers happy path and key validation failure cases.
"""

from __future__ import annotations

import os
import sys

# Set env BEFORE any app import
os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest
from decimal import Decimal
from pydantic import ValidationError

from app.schemas.jp.rental_terms import JpRentalTermsCreate, JpRentalTermsUpdate
from app.schemas.jp.property_info import JpPropertyInfoCreate
from app.schemas.jp.transit import TransitAccessCreate


class TestJpRentalTermsCreate:
    """Validate JpRentalTermsCreate schema rules."""

    def test_valid_minimal(self) -> None:
        """Happy path: only monthly_rent_jpy required."""
        schema = JpRentalTermsCreate(monthly_rent_jpy=Decimal("100000"))
        assert schema.monthly_rent_jpy == Decimal("100000")
        assert schema.tax_treatment == "included"

    def test_valid_full(self) -> None:
        """Happy path: all fields specified."""
        schema = JpRentalTermsCreate(
            monthly_rent_jpy=Decimal("150000"),
            management_fee_jpy=Decimal("5000"),
            shikikin_months=Decimal("2.0"),
            reikin_months=Decimal("1.0"),
            hoshou_months=Decimal("0.5"),
            koushinryo_months=Decimal("1.0"),
            brokerage_rate=Decimal("1.0"),
            hoshou_fee_jpy=Decimal("30000"),
            tax_treatment="excluded",
        )
        assert schema.shikikin_months == Decimal("2.0")
        assert schema.tax_treatment == "excluded"

    def test_monthly_rent_must_be_positive(self) -> None:
        """monthly_rent_jpy must be > 0."""
        with pytest.raises(ValidationError):
            JpRentalTermsCreate(monthly_rent_jpy=Decimal("0"))

    def test_monthly_rent_negative_rejected(self) -> None:
        with pytest.raises(ValidationError):
            JpRentalTermsCreate(monthly_rent_jpy=Decimal("-1000"))

    def test_brokerage_rate_exceeds_legal_max(self) -> None:
        """brokerage_rate > 1.1 should fail (宅建業法 cap)."""
        with pytest.raises(ValidationError):
            JpRentalTermsCreate(
                monthly_rent_jpy=Decimal("100000"),
                brokerage_rate=Decimal("1.2"),
            )

    def test_brokerage_rate_at_legal_max_ok(self) -> None:
        """brokerage_rate = 1.1 is exactly the legal max — should pass."""
        schema = JpRentalTermsCreate(
            monthly_rent_jpy=Decimal("100000"),
            brokerage_rate=Decimal("1.1"),
        )
        assert schema.brokerage_rate == Decimal("1.1")

    def test_invalid_tax_treatment(self) -> None:
        """tax_treatment must be one of: included, excluded, exempt."""
        with pytest.raises(ValidationError):
            JpRentalTermsCreate(
                monthly_rent_jpy=Decimal("100000"),
                tax_treatment="unknown",
            )

    def test_valid_tax_treatment_values(self) -> None:
        for val in ("included", "excluded", "exempt"):
            schema = JpRentalTermsCreate(monthly_rent_jpy=Decimal("100000"), tax_treatment=val)
            assert schema.tax_treatment == val

    def test_shikikin_months_within_range(self) -> None:
        schema = JpRentalTermsCreate(
            monthly_rent_jpy=Decimal("100000"),
            shikikin_months=Decimal("12.0"),
        )
        assert schema.shikikin_months == Decimal("12.0")

    def test_shikikin_months_exceeds_range(self) -> None:
        with pytest.raises(ValidationError):
            JpRentalTermsCreate(
                monthly_rent_jpy=Decimal("100000"),
                shikikin_months=Decimal("13.0"),  # > 12 max
            )

    def test_management_fee_must_be_non_negative(self) -> None:
        with pytest.raises(ValidationError):
            JpRentalTermsCreate(
                monthly_rent_jpy=Decimal("100000"),
                management_fee_jpy=Decimal("-1"),
            )


class TestJpPropertyInfoCreate:
    """Validate JpPropertyInfoCreate schema."""

    def test_empty_is_valid(self) -> None:
        """All fields optional — empty object is valid."""
        schema = JpPropertyInfoCreate()
        assert schema.layout is None

    def test_valid_layout(self) -> None:
        from app.domain.jp.property_info import LAYOUT_VALUES
        for layout in LAYOUT_VALUES:
            schema = JpPropertyInfoCreate(layout=layout)
            assert schema.layout == layout

    def test_invalid_layout_rejected(self) -> None:
        with pytest.raises(ValidationError):
            JpPropertyInfoCreate(layout="5LDK")  # not in enum

    def test_valid_structure(self) -> None:
        from app.domain.jp.property_info import STRUCTURE_VALUES
        for structure in STRUCTURE_VALUES:
            schema = JpPropertyInfoCreate(structure=structure)
            assert schema.structure == structure

    def test_invalid_structure_rejected(self) -> None:
        with pytest.raises(ValidationError):
            JpPropertyInfoCreate(structure="BRICK")

    def test_valid_orientation(self) -> None:
        from app.domain.jp.property_info import ORIENTATION_VALUES
        for orientation in ORIENTATION_VALUES:
            schema = JpPropertyInfoCreate(orientation=orientation)
            assert schema.orientation == orientation

    def test_invalid_orientation_rejected(self) -> None:
        with pytest.raises(ValidationError):
            JpPropertyInfoCreate(orientation="X")

    def test_building_year_valid_range(self) -> None:
        schema = JpPropertyInfoCreate(building_year=2000)
        assert schema.building_year == 2000

    def test_building_year_too_old(self) -> None:
        with pytest.raises(ValidationError):
            JpPropertyInfoCreate(building_year=1800)  # < 1900 min

    def test_floor_area_must_be_positive(self) -> None:
        with pytest.raises(ValidationError):
            JpPropertyInfoCreate(floor_area_sqm=Decimal("0"))


class TestTransitAccessCreate:
    """Validate TransitAccessCreate schema."""

    def test_valid(self) -> None:
        schema = TransitAccessCreate(station_id=1, walk_min=10)
        assert schema.walk_min == 10

    def test_walk_min_min_1(self) -> None:
        with pytest.raises(ValidationError):
            TransitAccessCreate(station_id=1, walk_min=0)

    def test_walk_min_max_60(self) -> None:
        with pytest.raises(ValidationError):
            TransitAccessCreate(station_id=1, walk_min=61)

    def test_walk_min_boundary_values(self) -> None:
        TransitAccessCreate(station_id=1, walk_min=1)   # OK
        TransitAccessCreate(station_id=1, walk_min=60)  # OK
