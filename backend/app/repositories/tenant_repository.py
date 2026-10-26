"""TenantRepository — host-scoped CRUD for tenants."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from app import models
from app.repositories.base import HostScopedRepository
from app.schemas.tenant import TenantCreate, TenantUpdate


class TenantRepository(HostScopedRepository[models.Tenant]):
    model_class = models.Tenant
    host_field_name = "host_id"

    def create(self, payload: TenantCreate) -> models.Tenant:
        """Create and flush a new Tenant for this host."""
        now = datetime.utcnow()
        so = payload.cccd_number
        cccd_hash: Optional[str] = None
        if so:
            # Import muộn: bcrypt chỉ cần khi người dùng thật sự gõ số CCCD.
            from app.services.cccd_storage import hash_cccd_number

            cccd_hash = hash_cccd_number(so)
        tenant = models.Tenant(
            host_id=self.host_id,
            full_name=payload.full_name,
            phone=payload.phone,
            email=payload.email,
            birthday=payload.birthday,
            address_origin=payload.address_origin,
            # Số nguyên không bao giờ nằm trong DB — xem migration 0108.
            cccd_number_hash=cccd_hash,
            cccd_duoi=so[-3:] if so else None,
            created_at=now,
        )
        self.db.add(tenant)
        self.db.flush()
        return tenant

    def update(self, tenant: models.Tenant, payload: TenantUpdate) -> models.Tenant:
        data = payload.model_dump(exclude_unset=True)
        for key, value in data.items():
            setattr(tenant, key, value)
        self.db.flush()
        return tenant
