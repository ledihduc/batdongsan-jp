"""JP compliance evidence endpoint.

Route:
  GET /api/jp/compliance/evidence

Returns APPI audit data points for legal team review:
  - Count of users with active APPI consent
  - Last deletion cron run timestamp + purged count
  - PII encryption key rotation date
  - Multi-org HMAC webhook secret rotation ledger

Requires: admin role (enforced via request.state.role).
All routes guarded by require_region('jp') from main.py include_router call.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import Optional

from app.core.deps.require_region import require_region
from app.database import get_db
from app.schemas.jp.compliance import ComplianceEvidenceResponse
from app.services.compliance.evidence import build_compliance_evidence

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/compliance",
    tags=["jp-compliance"],
    dependencies=[Depends(require_region("jp"))],
)


@router.get("/evidence", response_model=ComplianceEvidenceResponse)
async def get_compliance_evidence(
    request: Request,
    db: Session = Depends(get_db),
) -> ComplianceEvidenceResponse:
    """Return APPI compliance evidence snapshot for legal audit.

    Admin role required. Returns data aggregated across the JP org for
    the requesting admin's organization.

    Data points returned:
    - appi_consented_users_count: users with active service_use consent
    - last_deletion_cron_run: timestamp of the last deletion cron execution
    - last_deletion_purged_count: users anonymized in last run
    - pii_key_rotation_date: date of last Fernet PII key rotation
    - hmac_rotation_ledger: per-org HMAC rotation history
    - generated_at: snapshot generation timestamp (UTC)
    """
    actual_role: Optional[str] = getattr(request.state, "role", None)
    if actual_role != "admin":
        raise HTTPException(status_code=403, detail="admin role required")

    try:
        evidence = build_compliance_evidence(db)
    except Exception as exc:
        logger.error("Failed to build compliance evidence: %s", exc, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Failed to generate compliance evidence",
        ) from exc

    return evidence
