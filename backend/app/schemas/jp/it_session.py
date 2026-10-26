"""Pydantic schemas for IT重説 session endpoints."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class CreateItSessionRequest(BaseModel):
    """POST /api/jp/it-sessions"""
    viewing_id: int
    takken_shi_id: int
    scheduled_at: datetime = Field(..., description="Session start time (UTC ISO8601).")


class ItSessionResponse(BaseModel):
    id: int
    org_id: str
    viewing_id: int
    takken_shi_id: int
    scheduled_at: datetime
    zoom_meeting_id: Optional[str]
    zoom_join_url: Optional[str]
    status: str
    tenant_consent_at: Optional[datetime]
    recording_url: Optional[str]

    class Config:
        from_attributes = True


class CreateEContractRequest(BaseModel):
    """POST /api/jp/econtracts"""
    application_id: int
    template_version: str = "1.0"


class EContractResponse(BaseModel):
    id: int
    org_id: str
    application_id: int
    provider: str
    remote_doc_id: Optional[str]
    status: str
    signed_pdf_url: Optional[str]
    template_version: Optional[str]

    class Config:
        from_attributes = True
