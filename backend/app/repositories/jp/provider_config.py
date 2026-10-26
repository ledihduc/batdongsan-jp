"""Repository for OrgProviderConfig — per-org external provider credentials.

Multi-tenant isolation: every list query MUST filter by org_id.
Encryption/decryption of config_encrypted is handled in app.services.crypto
— NOT here. Repository returns raw model rows only.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.provider_config import OrgProviderConfig


class OrgProviderConfigRepository:
    """Org-scoped CRUD for org_provider_configs.

    All list queries filter by org_id (MULTI-TENANT ISOLATION).
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def get(
        self,
        org_id: str,
        provider_type: str,
        provider_name: str,
    ) -> Optional[OrgProviderConfig]:
        """Fetch one config row by org + type + name. Returns None if absent."""
        return (
            self.db.query(OrgProviderConfig)
            .filter(
                OrgProviderConfig.org_id == org_id,          # MULTI-TENANT ISOLATION
                OrgProviderConfig.provider_type == provider_type,
                OrgProviderConfig.provider_name == provider_name,
            )
            .first()
        )

    def list_by_org(self, org_id: str) -> list[OrgProviderConfig]:
        """List all provider configs for an org."""
        return (
            self.db.query(OrgProviderConfig)
            .filter(OrgProviderConfig.org_id == org_id)      # MULTI-TENANT ISOLATION
            .all()
        )

    def upsert(
        self,
        org_id: str,
        provider_type: str,
        provider_name: str,
        config_encrypted: dict,
        is_sandbox: bool = True,
    ) -> OrgProviderConfig:
        """Insert or update a provider config row."""
        existing = self.get(org_id, provider_type, provider_name)
        if existing:
            existing.config_encrypted = config_encrypted
            existing.is_sandbox = is_sandbox
            self.db.flush()
            return existing

        row = OrgProviderConfig(
            org_id=org_id,
            provider_type=provider_type,
            provider_name=provider_name,
            config_encrypted=config_encrypted,
            is_sandbox=is_sandbox,
        )
        self.db.add(row)
        self.db.flush()
        return row
