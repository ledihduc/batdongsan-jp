"""rename_booking_to_viewing_appointment

Rename table bookings → viewing_appointments.
Rename indexes ix_bookings_* → ix_viewing_appointments_*.
Update existing notification type strings per the explicit mapping
in phase-01b-booking-rename.md (NOT a blanket REPLACE — two types change
their suffix, not just prefix).

Revision ID: 0003_rename_booking
Revises: bef9a3d80bf2
Create Date: 2026-06-22
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0003_rename_booking"
down_revision: Union[str, Sequence[str], None] = "bef9a3d80bf2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Explicit notification type mapping (spec §Architecture, Backend table).
# A blanket REPLACE('booking_', 'viewing_appointment_') would corrupt:
#   booking_new    -> viewing_appointment_new      (wrong; spec says _requested)
#   booking_locked -> viewing_appointment_locked   (wrong; spec says _confirmed)
_NOTIFICATION_TYPE_MAP: list[tuple[str, str]] = [
    ("booking_new", "viewing_appointment_requested"),
    ("booking_approved", "viewing_appointment_approved"),
    ("booking_rejected", "viewing_appointment_rejected"),
    ("booking_locked", "viewing_appointment_confirmed"),
    ("booking_lost", "viewing_appointment_lost"),
]

# Index rename map: (old_name, new_name). Includes the primary key index —
# Postgres does not auto-rename it when ALTER TABLE RENAME runs.
_INDEX_RENAMES: list[tuple[str, str]] = [
    ("bookings_pkey", "viewing_appointments_pkey"),
    ("ix_bookings_guest_id", "ix_viewing_appointments_guest_id"),
    ("ix_bookings_house_id", "ix_viewing_appointments_house_id"),
    ("ix_bookings_status", "ix_viewing_appointments_status"),
]


def upgrade() -> None:
    op.rename_table("bookings", "viewing_appointments")

    for old_name, new_name in _INDEX_RENAMES:
        op.execute(f'ALTER INDEX "{old_name}" RENAME TO "{new_name}"')

    for old_type, new_type in _NOTIFICATION_TYPE_MAP:
        op.execute(
            f"UPDATE notifications SET type = '{new_type}' WHERE type = '{old_type}'"
        )


def downgrade() -> None:
    for old_type, new_type in _NOTIFICATION_TYPE_MAP:
        op.execute(
            f"UPDATE notifications SET type = '{old_type}' WHERE type = '{new_type}'"
        )

    for old_name, new_name in _INDEX_RENAMES:
        op.execute(f'ALTER INDEX "{new_name}" RENAME TO "{old_name}"')

    op.rename_table("viewing_appointments", "bookings")
