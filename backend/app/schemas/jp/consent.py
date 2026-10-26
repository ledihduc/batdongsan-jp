"""Pydantic schemas for JP consent and DSR endpoints."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class GrantConsentRequest(BaseModel):
    """POST /api/jp/consent/grant"""
    purposes: list[str] = Field(
        ...,
        min_length=1,
        description=(
            "List of purposes to grant. Valid: service_use, marketing, analytics, "
            "data_sharing_broker, data_sharing_hoshou"
        ),
    )
    consent_version: str = Field(default="1.0", description="Consent text version shown to user.")

    class Config:
        json_schema_extra = {
            "example": {
                "purposes": ["service_use", "marketing"],
                "consent_version": "1.0",
            }
        }


class RevokeConsentRequest(BaseModel):
    """POST /api/jp/consent/revoke"""
    purpose: str = Field(..., description="Single purpose to revoke.")


class ConsentStatusResponse(BaseModel):
    """GET /api/jp/consent"""
    user_id: int
    consents: dict[str, bool]  # {purpose: is_active}


class DataExportResponse(BaseModel):
    """GET /api/jp/me/data-export"""
    job_id: str
    status: str = "ready"
    expires_at: str
    download_url: Optional[str] = None  # Populated if direct download is offered


class DataDeleteResponse(BaseModel):
    """POST /api/jp/me/data-delete"""
    scheduled_purge_at: str
    message: str
