"""MeterReadingRepository — host-scoped CRUD for meter_readings."""

from __future__ import annotations

from typing import Optional

from app import models
from app.repositories.base import HostScopedRepository


class MeterReadingRepository(HostScopedRepository[models.MeterReading]):
    model_class = models.MeterReading
    host_field_name = "host_id"

    def list(  # type: ignore[override]
        self,
        room_id: Optional[int] = None,
        period_start: Optional[str] = None,
        period_end: Optional[str] = None,
    ) -> list[models.MeterReading]:
        q = self._base_query()
        if room_id is not None:
            q = q.filter(models.MeterReading.room_id == room_id)
        if period_start is not None:
            q = q.filter(models.MeterReading.reading_date >= period_start)
        if period_end is not None:
            q = q.filter(models.MeterReading.reading_date <= period_end)
        return q.order_by(models.MeterReading.reading_date.desc()).all()

    def latest_for_room(
        self, room_id: int, before_date: Optional[str] = None
    ) -> Optional[models.MeterReading]:
        """Return the most recent APPROVED reading for a room (optionally before a date).

        Only `trang_thai == 'da_duyet'`. Since migration 0106 tenants submit
        readings that wait for the host (`cho_duyet`) or get sent back
        (`can_chup_lai`). Every caller of this method bills money — billing on a
        number nobody confirmed, or one the host just rejected, bills a wrong
        number (and batch generation is idempotent per period, so it would
        never be recomputed). Host-entered rows default to 'da_duyet'.
        """
        q = self._base_query().filter(
            models.MeterReading.room_id == room_id,
            models.MeterReading.trang_thai == "da_duyet",
        )
        if before_date is not None:
            q = q.filter(models.MeterReading.reading_date < before_date)
        return q.order_by(models.MeterReading.reading_date.desc()).first()
