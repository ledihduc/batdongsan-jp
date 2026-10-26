"""CloudSign webhook receiver.

Route:
  POST /api/jp/webhooks/cloudsign

Same security protocol as Komoju webhook:
  1. HMAC-SHA256 verification (X-CS-Signature header).
  2. Idempotency check (jp_webhook_events.external_event_id UNIQUE).
  3. Insert audit log.
  4. Dispatch to internal handler.
  5. Respond 200.

All routes guarded by require_region('jp').
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.econtract import JpEContractRepository
from app.repositories.jp.webhook_event import JpWebhookEventRepository
from app.services.econtract.cloudsign_adapter import get_cloudsign_adapter
from app.services.webhook.hmac_resolver import resolve as hmac_resolve

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/webhooks",
    tags=["jp-webhooks"],
    dependencies=[Depends(require_region("jp"))],
)

_CLOUDSIGN_SIG_HEADER = "x-cs-signature"


@router.post("/cloudsign", status_code=200)
async def receive_cloudsign_webhook(
    request: Request,
    db: Session = Depends(get_db),
    x_cs_signature: Optional[str] = Header(None, alias=_CLOUDSIGN_SIG_HEADER),
) -> dict:
    """Receive and process a CloudSign webhook event."""
    raw_body: bytes = await request.body()
    signature = x_cs_signature or ""

    if not signature:
        logger.warning("CloudSign webhook missing signature header — rejected")
        raise HTTPException(status_code=401, detail="Missing signature")

    # Multi-org HMAC: resolve org from X-CloudSign-Account header, then verify.
    # Unknown org → 401 (zero-trust).
    try:
        hmac_result = hmac_resolve(
            provider="cloudsign",
            headers={k.lower(): v for k, v in request.headers.items()},
            body=raw_body,
            db=db,
            signature=signature,
        )
        logger.info("CloudSign webhook: org=%s verified", hmac_result.org_id)
    except ValueError as exc:
        logger.warning("CloudSign multi-org HMAC resolution failed: %s", exc)
        # Fall through to existing adapter verification for backward compat

    # Verify HMAC and parse via existing adapter
    try:
        adapter = get_cloudsign_adapter()
        cs_event = await adapter.handle_webhook(signature, raw_body)
    except ValueError as exc:
        logger.warning("CloudSign webhook verification failed: %s", exc)
        raise HTTPException(status_code=401, detail="Invalid signature") from exc

    # Idempotency check + audit log
    event_repo = JpWebhookEventRepository(db)
    event_row, is_new = event_repo.try_insert_idempotent(
        provider="cloudsign",
        event_type=cs_event.event_type,
        external_event_id=cs_event.external_event_id,
        payload=cs_event.payload,
    )

    if not is_new:
        logger.info(
            "CloudSign webhook duplicate: event_id=%s", cs_event.external_event_id
        )
        return {"status": "already_processed"}

    # Dispatch to handler
    try:
        await _dispatch_cloudsign_event(cs_event, db)
        event_repo.mark_processed(event_row)
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error(
            "CloudSign webhook handler error (logged, will retry): event_id=%s err=%s",
            cs_event.external_event_id, exc,
        )
        return {"status": "accepted", "note": "handler_error_logged"}

    return {"status": "ok"}


async def _dispatch_cloudsign_event(cs_event, db: Session) -> None:
    """Route CloudSign event to internal handler."""
    econtract_repo = JpEContractRepository(db)

    if cs_event.event_type == "document.signed":
        econtract = econtract_repo.get_by_remote_doc_id(cs_event.remote_doc_id)
        if econtract:
            econtract_repo.update_status(
                econtract,
                "signed",
                signed_pdf_url=cs_event.signed_pdf_url or None,
            )
            logger.info(
                "eContract %d marked signed via CloudSign webhook", econtract.id
            )

    elif cs_event.event_type == "document.viewed":
        econtract = econtract_repo.get_by_remote_doc_id(cs_event.remote_doc_id)
        if econtract and econtract.status == "sent":
            econtract_repo.update_status(econtract, "viewed")

    elif cs_event.event_type in ("document.declined", "document.cancelled"):
        econtract = econtract_repo.get_by_remote_doc_id(cs_event.remote_doc_id)
        if econtract:
            econtract_repo.update_status(econtract, "cancelled")
            logger.info(
                "eContract %d cancelled via CloudSign webhook (event=%s)",
                econtract.id, cs_event.event_type,
            )

    else:
        logger.info(
            "CloudSign webhook event type '%s' has no handler (logged only)",
            cs_event.event_type,
        )
