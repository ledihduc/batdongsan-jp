"""Pydantic request/response schemas for Japanese address operations.

Used by:
  - GET /api/jp/address/lookup?postal_code=... → list[AddressCandidate]
  - app/repositories/jp/address.py for DB serialization
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AddressCandidate(BaseModel):
    """A single address candidate returned by the 日本郵便 postal lookup API.

    Matches the zipcloud.ibsnet.co.jp /api/search response structure.
    All fields except postal_code are optional — some postal codes resolve to
    town level only (chome/banchi/go may be absent).
    """

    postal_code: str = Field(
        ...,
        description="7-digit postal code without hyphen (e.g. '1500001')",
        examples=["1500001"],
    )
    prefecture: Optional[str] = Field(
        None,
        description="都道府県 (prefecture), e.g. '東京都'",
        examples=["東京都"],
    )
    city: Optional[str] = Field(
        None,
        description="市区町村 (city/ward), e.g. '渋谷区'",
        examples=["渋谷区"],
    )
    town: Optional[str] = Field(
        None,
        description="町域 (town/neighborhood), e.g. '神南'",
        examples=["神南"],
    )
    chome: Optional[str] = Field(None, description="丁目")
    banchi: Optional[str] = Field(None, description="番地")
    go: Optional[str] = Field(None, description="号")
    building: Optional[str] = Field(None, description="建物名")
    prefecture_kana: Optional[str] = Field(None, description="都道府県 フリガナ")
    city_kana: Optional[str] = Field(None, description="市区町村 フリガナ")
    town_kana: Optional[str] = Field(None, description="町域 フリガナ")

    model_config = {"from_attributes": True}


class AddressLookupResponse(BaseModel):
    """Response envelope for address lookup — contains a list of candidates.

    Multiple candidates can share the same postal code when a code maps to
    multiple town divisions (e.g. large districts split at town level).
    """

    postal_code: str = Field(..., description="The queried postal code (normalized)")
    candidates: list[AddressCandidate] = Field(
        ..., description="Address candidates (empty list when code not found)"
    )


class JpAddressCreate(BaseModel):
    """Request body for creating a jp_address DB record (internal use)."""

    postal_code: str
    prefecture: Optional[str] = None
    city: Optional[str] = None
    town: Optional[str] = None
    chome: Optional[str] = None
    banchi: Optional[str] = None
    go: Optional[str] = None
    building: Optional[str] = None
    prefecture_kana: Optional[str] = None
    city_kana: Optional[str] = None
    town_kana: Optional[str] = None


class JpAddressResponse(BaseModel):
    """Full DB record response (includes id + timestamps)."""

    id: int
    postal_code: str
    prefecture: Optional[str] = None
    city: Optional[str] = None
    town: Optional[str] = None
    chome: Optional[str] = None
    banchi: Optional[str] = None
    go: Optional[str] = None
    building: Optional[str] = None
    prefecture_kana: Optional[str] = None
    city_kana: Optional[str] = None
    town_kana: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
