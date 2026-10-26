"""ContractRepository — host-scoped CRUD for contracts.

Soft delete: terminated contracts are excluded from default list() calls.
Use list(include_terminated=True) to include them explicitly.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.repositories.base import HostScopedRepository
from app.schemas.contract import ContractCreate


class ContractRepository(HostScopedRepository[models.Contract]):
    model_class = models.Contract
    host_field_name = "host_id"

    def list(  # type: ignore[override]
        self,
        status: Optional[str] = None,
        room_id: Optional[int] = None,
        expiring_within: Optional[int] = None,
        include_terminated: bool = False,
    ) -> list[models.Contract]:
        """List contracts for this host with optional filters.

        By default, terminated contracts are excluded (soft delete).
        expiring_within: integer days — return contracts with end_date within N days.
        """
        q = self._base_query()
        if not include_terminated:
            q = q.filter(models.Contract.status != "terminated")
        if status is not None:
            q = q.filter(models.Contract.status == status)
        if room_id is not None:
            q = q.filter(models.Contract.room_id == room_id)
        if expiring_within is not None:
            today = date.today().isoformat()
            future = (date.today() + timedelta(days=expiring_within)).isoformat()
            q = q.filter(
                models.Contract.end_date >= today,
                models.Contract.end_date <= future,
                models.Contract.status == "active",
            )
        return q.all()

    def get_pivot_rows(self, contract_id: int) -> list[models.ContractTenant]:
        """Return all ContractTenant pivot rows for a contract."""
        return (
            self.db.query(models.ContractTenant)
            .filter(models.ContractTenant.contract_id == contract_id)
            .all()
        )

    def add_tenant_pivot(
        self,
        contract_id: int,
        tenant_id: int,
        is_primary: bool,
        joined_at: Optional[str] = None,
    ) -> models.ContractTenant:
        """Insert a pivot row. Flushes — does not commit."""
        pivot = models.ContractTenant(
            contract_id=contract_id,
            tenant_id=tenant_id,
            is_primary=is_primary,
            joined_at=joined_at,
        )
        self.db.add(pivot)
        self.db.flush()
        return pivot
