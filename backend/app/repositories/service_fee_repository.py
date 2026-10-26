"""ServiceFeeRepository — host-scoped CRUD for service_fees + contract_service_fees pivot."""

from __future__ import annotations

from typing import Optional

from app import models
from app.repositories.base import HostScopedRepository


class ServiceFeeRepository(HostScopedRepository[models.ServiceFee]):
    model_class = models.ServiceFee
    host_field_name = "host_id"

    def list(  # type: ignore[override]
        self,
        building_id: Optional[int] = None,
        is_active: Optional[bool] = None,
    ) -> list[models.ServiceFee]:
        q = self._base_query()
        if building_id is not None:
            q = q.filter(models.ServiceFee.building_id == building_id)
        if is_active is not None:
            q = q.filter(models.ServiceFee.is_active == is_active)
        return q.order_by(models.ServiceFee.name.asc()).all()

    def list_for_contract(self, contract_id: int) -> list[models.ContractServiceFee]:
        """Return pivot rows for a contract."""
        return (
            self.db.query(models.ContractServiceFee)
            .filter(models.ContractServiceFee.contract_id == contract_id)
            .all()
        )

    def attach_to_contract(
        self, contract_id: int, service_fee_id: int, monthly_amount: float
    ) -> models.ContractServiceFee:
        """Insert pivot row. Flushes — does not commit. Upsert semantics."""
        existing = (
            self.db.query(models.ContractServiceFee)
            .filter(
                models.ContractServiceFee.contract_id == contract_id,
                models.ContractServiceFee.service_fee_id == service_fee_id,
            )
            .first()
        )
        if existing is not None:
            existing.monthly_amount = monthly_amount
            self.db.flush()
            return existing
        pivot = models.ContractServiceFee(
            contract_id=contract_id,
            service_fee_id=service_fee_id,
            monthly_amount=monthly_amount,
        )
        self.db.add(pivot)
        self.db.flush()
        return pivot

    def detach_from_contract(self, contract_id: int, service_fee_id: int) -> bool:
        """Delete pivot row. Returns True if deleted."""
        n = (
            self.db.query(models.ContractServiceFee)
            .filter(
                models.ContractServiceFee.contract_id == contract_id,
                models.ContractServiceFee.service_fee_id == service_fee_id,
            )
            .delete()
        )
        self.db.flush()
        return n > 0
