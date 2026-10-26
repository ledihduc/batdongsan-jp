"""Factory that resolves the payment adapter for a given org.

Resolution order:
  1. Look up OrgProviderConfig for (org_id, 'payment', 'komoju').
  2. Decrypt credentials via app.services.crypto.decrypt_config().
  3. If settings.use_mock_providers=True → return KomojuMockClient (ignore creds).
  4. If no config found and settings.use_mock_providers=True → sandbox mock.
  5. If no config found and not mock → raise RuntimeError (misconfiguration).

Future: extend to support multiple provider_name values per org.
"""

from __future__ import annotations

import logging

from sqlalchemy.orm import Session

from app.config import settings
from app.repositories.jp.provider_config import OrgProviderConfigRepository
from app.services.crypto import decrypt_config
from app.services.payment.jp.base import JpPaymentAdapter
from app.services.payment.jp.komoju.client import KomojuClient, KomojuMockClient

logger = logging.getLogger(__name__)


async def resolve_payment_adapter(
    org_id: str,
    db: Session,
) -> JpPaymentAdapter:
    """Return the configured payment adapter for org_id.

    Args:
        org_id: Broker org tenant ID.
        db: SQLAlchemy session (for OrgProviderConfig lookup).

    Returns:
        JpPaymentAdapter instance (mock or real).

    Raises:
        RuntimeError: if no provider config found and mock mode is off.
    """
    use_mock: bool = getattr(settings, "use_mock_providers", True)

    repo = OrgProviderConfigRepository(db)
    config_row = repo.get(org_id, "payment", "komoju")

    if use_mock:
        is_sandbox = config_row.is_sandbox if config_row else True
        logger.info(
            "resolve_payment_adapter: returning mock for org=%s sandbox=%s",
            org_id, is_sandbox,
        )
        return KomojuMockClient(org_id=org_id, is_sandbox=is_sandbox)

    if config_row is None:
        raise RuntimeError(
            f"No Komoju provider config found for org={org_id}. "
            "Configure OrgProviderConfig(provider_type='payment', provider_name='komoju')."
        )

    try:
        creds = decrypt_config(config_row.config_encrypted)
    except ValueError as exc:
        raise RuntimeError(
            f"Failed to decrypt Komoju config for org={org_id}: {exc}"
        ) from exc

    api_key = creds.get("api_key", "")
    webhook_secret = creds.get("webhook_secret", "")
    if not api_key or not webhook_secret:
        raise RuntimeError(
            f"Komoju config for org={org_id} missing 'api_key' or 'webhook_secret'."
        )

    logger.info(
        "resolve_payment_adapter: returning real KomojuClient for org=%s sandbox=%s",
        org_id, config_row.is_sandbox,
    )
    return KomojuClient(
        api_key=api_key,
        webhook_secret=webhook_secret,
        is_sandbox=config_row.is_sandbox,
        org_id=org_id,
    )
