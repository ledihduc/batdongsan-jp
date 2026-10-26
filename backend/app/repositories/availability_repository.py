"""AvailabilityRepository — per-day status rows for homestay rooms (Phase 07)."""

from __future__ import annotations

from typing import Optional

from app import models
from app.repositories.base import HostScopedRepository


class AvailabilityRepository(HostScopedRepository[models.Availability]):
    model_class = models.Availability
    host_field_name = "host_id"

    def list_for_room_month(
        self, room_id: int, month: str
    ) -> list[models.Availability]:
        """Return all explicit availability rows for a (room, YYYY-MM)."""
        return (
            self._base_query()
            .filter(models.Availability.room_id == room_id)
            .filter(models.Availability.date.like(f"{month}-%"))
            .all()
        )

    def list_for_rooms_month(
        self, room_ids: list[int], month: str
    ) -> list[models.Availability]:
        if not room_ids:
            return []
        return (
            self._base_query()
            .filter(models.Availability.room_id.in_(room_ids))
            .filter(models.Availability.date.like(f"{month}-%"))
            .all()
        )

    def get_by_room_date(
        self, room_id: int, date: str
    ) -> Optional[models.Availability]:
        return (
            self._base_query()
            .filter(
                models.Availability.room_id == room_id,
                models.Availability.date == date,
            )
            .first()
        )

    def list_for_reservation(
        self, reservation_id: int
    ) -> list[models.Availability]:
        return (
            self._base_query()
            .filter(models.Availability.reservation_id == reservation_id)
            .all()
        )
