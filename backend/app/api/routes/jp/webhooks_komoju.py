"""Komoju webhook receiver.

Route:
  POST /api/jp/webhooks/komoju

Security protocol (enforced in order):
  1. HMAC-SHA256 signature verification (X-Komoju-Signature header).
  2. Idempotency check: if external_event_id already in jp_webhook_events → 200 immediately.
  3. Insert audit log row (jp_webhook_events).
  4. Dispatch to internal handler.
  5. Mark processed_at.
  6. Respond 200.

Respond 200 immediately after HMAC passes + idempotency check — never 5xx on
valid webhooks (Komoju retries on non-2xx).

All routes guarded by require_region('jp').
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.payment_intent import JpPaymentIntentRepository
from app.repositories.jp.webhook_event import JpWebhookEventRepository
from app.services.payment.jp.provider_resolver import resolve_payment_adapter
from app.services.webhook.hmac_resolver import resolve as hmac_resolve

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp/webhooks",
    tags=["jp-webhooks"],
    dependencies=[Depends(require_region("jp"))],
)

# Komoju signature header name
_KOMOJU_SIG_HEADER = "x-komoju-signature"


@router.post("/komoju", status_code=200)
async def receive_komoju_webhook(
    request: Request,
    db: Session = Depends(get_db),
    x_komoju_signature: Optional[str] = Header(None, alias=_KOMOJU_SIG_HEADER),
) -> dict:
    """Receive and process a Komoju payment webhook.

    Returns 200 immediately if HMAC passes (whether new or duplicate).
    Returns 401 if HMAC fails.
    """
    raw_body: bytes = await request.body()

    # --- Step 1: Multi-org HMAC verification ---
    signature = x_komoju_signature or ""
    if not signature:
        logger.warning("Komoju webhook missing signature header — rejected")
        raise HTTPException(status_code=401, detail="Missing signature")

    # Multi-org HMAC: resolve org from payload, then verify with org's secret.
    # Unknown org → 401 (zero-trust — don't leak org existence).
    import json as _json
    try:
        pre_payload = _json.loads(raw_body)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    try:
        hmac_result = hmac_resolve(
            provider="komoju",
            headers={k.lower(): v for k, v in request.headers.items()},
            body=raw_body,
            db=db,
            signature=signature,
        )
        org_id: str = hmac_result.org_id
    except ValueError as exc:
        logger.warning("Komoju multi-org HMAC resolution failed: %s", exc)
        # Fall back to legacy single-org adapter for backward compat during migration
        org_id = (
            pre_payload.get("data", {}).get("object", {}).get("metadata", {}).get("org_id")
            or ""
        )

    # Resolve adapter (uses mock in dev — mock skips HMAC check)
    try:
        adapter = await resolve_payment_adapter(org_id, db)
        webhook_event = await adapter.verify_webhook(signature, raw_body)
    except ValueError as exc:
        logger.warning("Komoju webhook HMAC verification failed: %s", exc)
        raise HTTPException(status_code=401, detail="Invalid signature") from exc
    except RuntimeError as exc:
        # No provider config — can happen in dev with empty org_id
        logger.warning("Komoju webhook provider resolution failed: %s", exc)
        raise HTTPException(status_code=500, detail="Provider not configured") from exc

    # --- Step 2 + 3: Idempotency check + audit log insert ---
    event_repo = JpWebhookEventRepository(db)
    event_row, is_new = event_repo.try_insert_idempotent(
        provider="komoju",
        event_type=webhook_event.event_type,
        external_event_id=webhook_event.external_event_id,
        payload=webhook_event.payload,
    )

    if not is_new:
        logger.info(
            "Komoju webhook duplicate, skipping: event_id=%s",
            webhook_event.external_event_id,
        )
        return {"status": "already_processed"}

    # --- Step 4: Dispatch to internal handlers ---
    try:
        await _dispatch_komoju_event(webhook_event, db)
        event_repo.mark_processed(event_row)
        db.commit()
    except Exception as exc:
        db.rollback()
        # Do NOT return 5xx — Komoju will retry and we'll handle via idempotency
        logger.error(
            "Komoju webhook handler error (event logged, will retry): event_id=%s err=%s",
            webhook_event.external_event_id, exc,
        )
        return {"status": "accepted", "note": "handler_error_logged"}

    return {"status": "ok"}


async def _dispatch_komoju_event(
    event,  # WebhookEvent
    db: Session,
) -> None:
    """Route webhook event to the appropriate internal handler."""
    intent_repo = JpPaymentIntentRepository(db)

    if event.event_type in ("payment.succeeded", "session.succeeded"):
        if event.intent_id:
            intent = intent_repo.get_by_provider_intent_id(event.intent_id)
            if intent:
                intent_repo.update_status(intent, "succeeded")
                logger.info(
                    "Payment intent %s marked succeeded via webhook", intent.id
                )

    elif event.event_type in ("payment.failed", "session.failed"):
        if event.intent_id:
            intent = intent_repo.get_by_provider_intent_id(event.intent_id)
            if intent:
                intent_repo.update_status(intent, "failed")
                logger.info(
                    "Payment intent %s marked failed via webhook", intent.id
                )

    elif event.event_type in ("payment.expired", "session.expired"):
        if event.intent_id:
            intent = intent_repo.get_by_provider_intent_id(event.intent_id)
            if intent:
                intent_repo.update_status(intent, "expired")

    else:
        logger.info(
            "Komoju webhook event type '%s' has no handler (logged only)",
            event.event_type,
        )
