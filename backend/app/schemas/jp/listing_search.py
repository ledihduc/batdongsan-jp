"""Response cho GET /api/jp/listings + /api/jp/listings/{id} (plan 20261027-1102 Phase 04).

Key khớp `JpListingSummary.fromJson` / `JpListing.fromJson` (app Flutter). Khai báo
tường minh để `response_model` chặn mọi trường lạ (SĐT, email chủ tin — AC4).
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel


class JpListingSummaryItem(BaseModel):
    listing_id: int
    title: str
    monthly_rent: int
    layout: str
    floor_area_m2: float
    nearest_station_name: Optional[str] = None
    nearest_station_walk_min: Optional[int] = None
    thumbnail_url: Optional[str] = None
    city: Optional[str] = None
    is_published: bool


class JpListingSearchResponse(BaseModel):
    items: list[JpListingSummaryItem]
    total: int
    page: int
    page_size: int
    ignored_filters: list[str]


class JpListingRentalTermsOut(BaseModel):
    id: int
    monthly_rent: int
    management_fee: Optional[int] = None
    shikikin_months: Optional[float] = None
    reikin_months: Optional[float] = None
    hoshoukin_months: Optional[float] = None
    koushinryo_months: Optional[float] = None
    brokerage_fee_rate: Optional[float] = None
    guarantee_company_fee: Optional[int] = None
    tax_included: bool


class JpListingPropertyInfoOut(BaseModel):
    id: int
    layout: str
    floor_area_m2: float
    structure: Optional[str] = None
    building_year: Optional[int] = None
    floor_number: Optional[int] = None
    orientation: Optional[str] = None
    available_from: Optional[str] = None


class JpListingStationOut(BaseModel):
    id: int
    name: str
    name_kana: str
    line_name: str
    line_id: int
    prefecture_name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class JpListingTransitOut(BaseModel):
    id: int
    listing_id: int
    station: JpListingStationOut
    walk_minutes: int


class JpListingDetailResponse(BaseModel):
    listing_id: int
    title: str
    rental_terms: JpListingRentalTermsOut
    property_info: JpListingPropertyInfoOut
    transit_accesses: list[JpListingTransitOut]
    description: Optional[str] = None
    image_urls: list[str]
    host_name: Optional[str] = None
    prefecture: Optional[str] = None
    city: Optional[str] = None
    address: Optional[str] = None
    is_published: bool
