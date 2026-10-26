"""BuildingRepository — host-scoped CRUD for buildings."""

from __future__ import annotations

import secrets
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.repositories.base import HostScopedRepository
from app.schemas.building import BuildingCreate, BuildingUpdate


# Bỏ 0/O/1/I/L: mã này sale đọc qua điện thoại cho chủ nhà nghe, những ký tự
# đó nghe nhầm nhau liên tục.
_BANG_CHU = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"


class BuildingRepository(HostScopedRepository[models.Building]):
    model_class = models.Building
    host_field_name = "host_id"

    def _sinh_ma_ban_giao(self) -> str:
        """Mã bàn giao 8 ký tự, chắc chắn chưa ai dùng.

        Cột có UNIQUE nên va chạm sẽ nổ ở tầng DB; vòng lặp này chỉ để tránh
        ném lỗi ra mặt người dùng vì một sự kiện xác suất ~1/10^12.
        """
        for _ in range(10):
            ma = "".join(secrets.choice(_BANG_CHU) for _ in range(8))
            trung = (
                self.db.query(models.Building.id)
                .filter(models.Building.claim_code == ma)
                .first()
            )
            if not trung:
                return ma
        raise RuntimeError("Không sinh được mã bàn giao duy nhất")

    def create(self, payload: BuildingCreate) -> models.Building:
        """Create and flush a new Building for this host."""
        now = datetime.utcnow()
        building = models.Building(
            host_id=self.host_id,
            claim_code=self._sinh_ma_ban_giao(),
            created_by_user_id=self.host_id,
            name=payload.name,
            address=payload.address,
            city=payload.city,
            district=payload.district,
            ward=payload.ward,
            note=payload.note,
            created_at=now,
            updated_at=now,
        )
        self.db.add(building)
        self.db.flush()
        return building

    def update(self, building: models.Building, payload: BuildingUpdate) -> models.Building:
        """Apply partial update to Building."""
        data = payload.model_dump(exclude_unset=True)
        for key, value in data.items():
            setattr(building, key, value)
        building.updated_at = datetime.utcnow()
        self.db.flush()
        return building

    def soft_delete(self, building_id: int) -> Optional[models.Building]:
        """Soft-delete a building (and cascade to rooms via DB FK).

        Returns the building if found and owned by this host; None otherwise.
        Note: rooms are hard-deleted by DB CASCADE. Contracts have RESTRICT on rooms
        so deletion will fail if active contracts exist — caller must handle.
        """
        building = self.get(building_id)
        if not building:
            return None
        self.db.delete(building)
        self.db.flush()
        return building
