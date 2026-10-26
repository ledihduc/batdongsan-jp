"""JP electronic contract (eContract) endpoints.

Routes:
  POST /api/jp/econtracts        — create eContract (draft), then send for signing
  GET  /api/jp/econtracts/{id}   — get eContract detail

All routes guarded by require_region('jp').
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.econtract import JpEContractRepository
from app.schemas.jp.it_session import CreateEContractRequest, EContractResponse
from app.services.econtract.cloudsign_adapter import get_cloudsign_adapter

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/econtracts",
    tags=["jp-econtracts"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_org_id(request: Request) -> str:
    org_id: Optional[str] = getattr(request.state, "org_id", None)
    if not org_id:
        raise HTTPException(status_code=401, detail="org_id not found in token")
    return org_id


@router.post("", response_model=EContractResponse, status_code=201)
async def create_econtract(
    body: CreateEContractRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> EContractResponse:
    """Create an eContract and send it for tenant signing.

    Flow:
      1. Create DB row (draft).
      2. Create CloudSign document.
      3. Send for signing → status = sent.
    """
    org_id = _get_org_id(request)
    repo = JpEContractRepository(db)

    # Create draft row
    econtract = repo.create(
        org_id=org_id,
        application_id=body.application_id,
        template_version=body.template_version,
    )

    try:
        adapter = get_cloudsign_adapter()
        doc = await adapter.create_document(
            application_id=body.application_id,
            template_version=body.template_version,
        )
        repo.update_status(econtract, "draft", remote_doc_id=doc.remote_doc_id)

        # Send immediately after creation (MVP: no draft review step)
        sent_doc = await adapter.send_for_signing(doc.remote_doc_id)
        repo.update_status(econtract, sent_doc.status)
        db.commit()
        db.refresh(econtract)
    except Exception as exc:
        db.rollback()
        logger.error("create_econtract failed: application=%d err=%s", body.application_id, exc)
        raise HTTPException(status_code=502, detail="eContract creation failed") from exc

    return EContractResponse.model_validate(econtract)


@router.get("/{econtract_id}", response_model=EContractResponse)
async def get_econtract(
    econtract_id: int,
    request: Request,
    db: Session = Depends(get_db),
) -> EContractResponse:
    """Get eContract detail."""
    org_id = _get_org_id(request)
    repo = JpEContractRepository(db)
    econtract = repo.get_by_id_org(econtract_id, org_id)
    if econtract is None:
        raise HTTPException(status_code=404, detail="eContract not found")
    return EContractResponse.model_validate(econtract)
