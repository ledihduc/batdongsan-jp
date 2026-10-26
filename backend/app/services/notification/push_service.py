"""Push notification providers.

Firebase Admin credentials are loaded from env only. Never commit the service
account JSON into the repository.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Protocol

from sqlalchemy.orm import Session

from app.models import UserPushToken

logger = logging.getLogger(__name__)


@dataclass
class PushMessage:
    user_id: int
    title: str
    body: str
    notification_type: str
    related_id: int | None = None
    data: dict | None = None


@dataclass
class PushSendResult:
    success: bool
    sent_count: int = 0
    failed_count: int = 0
    external_message_id: str | None = None
    error: str | None = None


class PushProvider(Protocol):
    provider_name: str

    async def send(self, db: Session, msg: PushMessage) -> PushSendResult:
        ...


class StubPushProvider:
    provider_name = "stub"

    async def send(self, db: Session, msg: PushMessage) -> PushSendResult:  # noqa: ARG002
        logger.info("[PUSH STUB] user_id=%d type=%s", msg.user_id, msg.notification_type)
        return PushSendResult(success=True, external_message_id="stub")


class FirebasePushProvider:
    provider_name = "firebase"

    def __init__(self, service_account_path: str | None = None) -> None:
        self._service_account_path = service_account_path or None
        self._initialized = False

    def _ensure_initialized(self) -> None:
        if self._initialized:
            return

        import firebase_admin
        from firebase_admin import credentials

        if firebase_admin._apps:
            self._initialized = True
            return

        if self._service_account_path:
            cred = credentials.Certificate(self._service_account_path)
            firebase_admin.initialize_app(cred)
        else:
            firebase_admin.initialize_app()
        self._initialized = True

    async def send(self, db: Session, msg: PushMessage) -> PushSendResult:
        try:
            self._ensure_initialized()
            from firebase_admin import messaging
        except Exception as exc:  # noqa: BLE001
            logger.error("[FCM] init failed: %s", exc)
            return PushSendResult(success=False, error="firebase init failed")

        rows = (
            db.query(UserPushToken)
            .filter(
                UserPushToken.user_id == msg.user_id,
                UserPushToken.is_active == True,  # noqa: E712
            )
            .all()
        )
        tokens = [row.token for row in rows if row.token]
        if not tokens:
            return PushSendResult(success=False, error="no active push tokens")

        payload = {
            "type": msg.notification_type,
            **{str(k): str(v) for k, v in (msg.data or {}).items() if v is not None},
        }
        if msg.related_id is not None:
            payload["related_id"] = str(msg.related_id)

        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(title=msg.title, body=msg.body),
            data=payload,
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default", badge=1)
                )
            ),
        )

        response = messaging.send_each_for_multicast(message)
        for row, send_response in zip(rows, response.responses):
            if send_response.success:
                continue
            err = send_response.exception
            code = getattr(err, "code", "") or ""
            if code in {
                "registration-token-not-registered",
                "invalid-argument",
                "sender-id-mismatch",
            }:
                row.is_active = False
        db.flush()

        return PushSendResult(
            success=response.success_count > 0,
            sent_count=response.success_count,
            failed_count=response.failure_count,
            external_message_id=f"fcm:{response.success_count}/{len(tokens)}",
            error=None if response.success_count > 0 else "all pushes failed",
        )


def build_push_provider(provider_name: str, settings: object) -> PushProvider:
    name = (provider_name or "stub").strip().lower()
    if name == "firebase":
        path = (
            getattr(settings, "firebase_service_account_path", "")
            or getattr(settings, "google_application_credentials", "")
            or ""
        )
        return FirebasePushProvider(service_account_path=path)
    return StubPushProvider()
