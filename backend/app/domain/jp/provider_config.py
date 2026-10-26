"""SQLAlchemy 2.0 model for OrgProviderConfig — per-org external provider credentials.

Table: org_provider_configs

B2B multi-tenant design: each broker org brings their own merchant accounts.
We never hold provider credentials centrally. Credentials are stored
Fernet-encrypted in config_encrypted (JSONB). The encryption helper lives in
app/services/crypto.py (uses settings.secret_key).

Design decisions:
- Managed by migration 0149_org_provider_configs.
- config_encrypted stores ciphertext (bytes) serialised as base64 string in JSON.
- is_sandbox flag: True by default — explicit action required to go live.
- org_id: multi-tenant isolation. Every repository list() MUST filter by org_id.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from sqlalchemy import Boolean, DateTime, Integer, JSON, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


# Valid provider_type values
PROVIDER_TYPE_VALUES = ("payment", "esign", "conference", "notification")


class OrgProviderConfig(Base):
    """Per-org external provider configuration (payment, eSign, conference, etc.).

    Credentials in config_encrypted are Fernet-encrypted; decrypt with
    app.services.crypto.decrypt_provider_config() before use.

    Uniqueness: one active config per (org_id, provider_type, provider_name).

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(OrgProviderConfig.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "org_provider_configs"

    __table_args__ = (
        UniqueConstraint(
            "org_id", "provider_type", "provider_name",
            name="uq_org_provider_configs_org_type_name",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Multi-tenant isolation
    org_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )

    # Provider classification
    provider_type: Mapped[str] = mapped_column(
        String(20), nullable=False,
        comment="payment | esign | conference | notification",
    )
    provider_name: Mapped[str] = mapped_column(
        String(64), nullable=False,
        comment="e.g. komoju | cloudsign | zoom",
    )

    # Encrypted credentials blob
    # The JSON column stores a dict like:
    #   {"ciphertext": "<base64-encoded Fernet token>"}
    # Decrypt via app.services.crypto.decrypt_provider_config(row.config_encrypted)
    config_encrypted: Mapped[Optional[Any]] = mapped_column(
        JSON, nullable=True,
        comment="Fernet-encrypted provider credentials. Never plaintext.",
    )

    # Sandbox flag — must be explicitly set False for production
    is_sandbox: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True,
        comment="True = sandbox/test mode. Explicit false required for production.",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
