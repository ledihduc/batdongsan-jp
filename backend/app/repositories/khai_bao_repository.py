"""KhaiBaoRepository — host-scoped CRUD for khai_bao_tam_tru."""

from __future__ import annotations

from typing import Optional

from app import models
from app.repositories.base import HostScopedRepository


class KhaiBaoRepository(HostScopedRepository[models.KhaiBaoTamTru]):
    model_class = models.KhaiBaoTamTru
    host_field_name = "host_id"

    def list_filtered(
        self,
        status: Optional[str] = None,
        building_id: Optional[int] = None,
    ) -> list[models.KhaiBaoTamTru]:
        """List host's records, optionally filtered by status + building.

        Building filter joins through Contract → Room → Building. Records
        without a contract (future: Reservation) skip the building join.
        """
        q = self._base_query()
        if status is not None:
            q = q.filter(models.KhaiBaoTamTru.status == status)
        if building_id is not None:
            q = (
                q.join(
                    models.Contract,
                    models.Contract.id == models.KhaiBaoTamTru.contract_id,
                )
                .join(models.Room, models.Room.id == models.Contract.room_id)
                .filter(models.Room.building_id == building_id)
            )
        return q.order_by(models.KhaiBaoTamTru.check_in_at.desc()).all()

    def get_by_public_token(self, token: str) -> Optional[models.KhaiBaoTamTru]:
        """Anon route lookup — bypass host filter on purpose."""
        return (
            self.db.query(models.KhaiBaoTamTru)
            .filter(models.KhaiBaoTamTru.public_token == token)
            .first()
        )

    def get_by_contract_tenant(
        self, contract_id: int, tenant_id: int
    ) -> Optional[models.KhaiBaoTamTru]:
        """Used by auto-create idempotency check."""
        return (
            self.db.query(models.KhaiBaoTamTru)
            .filter(
                models.KhaiBaoTamTru.contract_id == contract_id,
                models.KhaiBaoTamTru.tenant_id == tenant_id,
            )
            .first()
        )
