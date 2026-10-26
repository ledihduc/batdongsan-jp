"""Pydantic schemas for JP compliance evidence endpoint.

GET /api/jp/compliance/evidence — admin-only audit trail response.
Used by legal team for APPI compliance auditing.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class HmacRotationEntry(BaseModel):
    """Single entry in the HMAC webhook secret rotation ledger."""

    org_id: str
    rotated_at: str = Field(description="ISO datetime of last rotation (UTC)")
    rotation_count: int = Field(ge=0, description="Number of rotations performed")


class ComplianceEvidenceResponse(BaseModel):
    """Response for GET /api/jp/compliance/evidence.

    Provides APPI-mandated audit data points for legal review.
    All timestamps in ISO 8601 UTC.
    """

    # APPI consent coverage
    appi_consented_users_count: int = Field(
        ge=0,
        description="Number of users with at least one active APPI consent (service_use purpose, not revoked)",
    )

    # Deletion cron audit
    last_deletion_cron_run: Optional[str] = Field(
        default=None,
        description="ISO datetime of the last deletion cron execution. Null if never run.",
    )
    last_deletion_purged_count: int = Field(
        ge=0,
        description="Number of users anonymized in the most recent deletion cron run.",
    )

    # PII key rotation
    pii_key_rotation_date: Optional[str] = Field(
        default=None,
        description="ISO date of the last Fernet PII key rotation. Null if key has not been rotated.",
    )

    # Multi-org HMAC ledger
    hmac_rotation_ledger: list[HmacRotationEntry] = Field(
        default_factory=list,
        description="Per-org webhook HMAC secret rotation history.",
    )

    # Metadata
    generated_at: str = Field(
        description="ISO datetime when this evidence snapshot was generated (UTC)",
    )

    model_config = ConfigDict(json_schema_extra={
        "example": {
            "appi_consented_users_count": 342,
            "last_deletion_cron_run": "2026-10-16T18:00:00+00:00",
            "last_deletion_purged_count": 3,
            "pii_key_rotation_date": "2026-09-01",
            "hmac_rotation_ledger": [
                {
                    "org_id": "org-shinjuku-001",
                    "rotated_at": "2026-09-15T10:00:00+00:00",
                    "rotation_count": 2,
                }
            ],
            "generated_at": "2026-10-17T03:00:00+00:00",
        }
    })
