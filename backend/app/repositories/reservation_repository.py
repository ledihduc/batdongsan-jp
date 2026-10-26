"""ReservationRepository — homestay bookings (Phase 07)."""

from __future__ import annotations

from typing import Optional

from app import models
from app.repositories.base import HostScopedRepository

# Statuses that "block" the calendar (overlap check considers these).
ACTIVE_STATUSES = ("pending", "approved", "checked_in")


class ReservationRepository(HostScopedRepository[models.Reservation]):
    model_class = models.Reservation
    host_field_name = "host_id"

    def list_filtered(
        self,
        status: Optional[str] = None,
        room_id: Optional[int] = None,
    ) -> list[models.Reservation]:
        q = self._base_query()
        if status is not None:
            q = q.filter(models.Reservation.status == status)
        if room_id is not None:
            q = q.filter(models.Reservation.room_id == room_id)
        return q.order_by(models.Reservation.check_in_date.desc()).all()

    def find_overlapping(
        self,
        room_id: int,
        check_in: str,
        check_out: str,
        exclude_id: Optional[int] = None,
    ) -> list[models.Reservation]:
        """App-level overlap check — until Postgres exclusion constraint lands.

        Two ranges [a, b) and [c, d) overlap iff a < d AND c < b.
        Here check_out is exclusive (next day after last stay).
        Only active statuses are considered blocking.
        """
        q = (
            self._base_query()
            .filter(models.Reservation.room_id == room_id)
            .filter(models.Reservation.status.in_(ACTIVE_STATUSES))
            .filter(models.Reservation.check_in_date < check_out)
            .filter(models.Reservation.check_out_date > check_in)
        )
        if exclude_id is not None:
            q = q.filter(models.Reservation.id != exclude_id)
        return q.all()

    def list_active_for_rooms_month(
        self, room_ids: list[int], month: str
    ) -> list[models.Reservation]:
        """Reservations that intersect the given month for the given rooms.

        `month` is "YYYY-MM". Range filter is half-open
        [first-day-of-month, first-day-of-next-month) so we compute the
        next-month sentinel as a real ISO date — Postgres rejects fake
        dates like "2026-07-99" once check_in_date is a native DATE.
        """
        if not room_ids:
            return []
        year, mon = (int(x) for x in month.split("-"))
        next_year, next_mon = (year + 1, 1) if mon == 12 else (year, mon + 1)
        month_start = f"{year:04d}-{mon:02d}-01"
        month_end_exclusive = f"{next_year:04d}-{next_mon:02d}-01"
        return (
            self._base_query()
            .filter(models.Reservation.room_id.in_(room_ids))
            .filter(models.Reservation.status.in_(ACTIVE_STATUSES))
            .filter(models.Reservation.check_in_date < month_end_exclusive)
            .filter(models.Reservation.check_out_date > month_start)
            .all()
        )
