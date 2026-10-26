"""Room state machine service.

Valid transitions:
  vacant → occupied    (contract activates)
  occupied → vacant    (contract terminates)
  vacant → maintenance (manual)
  maintenance → vacant (manual clear)

Any other transition raises HTTPException 400.
"""

from __future__ import annotations

from typing import Optional

from fastapi import HTTPException

from app import models

# Allowed transitions: (from_status, to_status)
_ALLOWED_TRANSITIONS: set[tuple[str, str]] = {
    ("vacant", "occupied"),
    ("occupied", "vacant"),
    ("vacant", "maintenance"),
    ("maintenance", "vacant"),
}


def validate_room_transition(room: models.Room, to_status: str) -> None:
    """Raise HTTPException(400) if transition is not valid."""
    from_status = room.status
    if (from_status, to_status) not in _ALLOWED_TRANSITIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Không thể chuyển trạng thái phòng từ '{from_status}' sang '{to_status}'",
        )


def set_maintenance(
    room: models.Room,
    maintenance_start: str,
    maintenance_end: Optional[str],
) -> models.Room:
    """Transition room to maintenance. Validates state before mutating.

    Does NOT flush/commit — caller owns the transaction.
    """
    validate_room_transition(room, "maintenance")
    room.status = "maintenance"
    room.maintenance_start = maintenance_start
    room.maintenance_end = maintenance_end
    return room


def clear_maintenance(room: models.Room) -> models.Room:
    """Transition room from maintenance back to vacant.

    Does NOT flush/commit — caller owns the transaction.
    """
    validate_room_transition(room, "vacant")
    room.status = "vacant"
    room.maintenance_start = None
    room.maintenance_end = None
    return room


def set_occupied(room: models.Room) -> models.Room:
    """Transition room to occupied (called when contract activates)."""
    validate_room_transition(room, "occupied")
    room.status = "occupied"
    return room


def set_vacant(room: models.Room) -> models.Room:
    """Transition room to vacant (called when contract terminates)."""
    validate_room_transition(room, "vacant")
    room.status = "vacant"
    return room
