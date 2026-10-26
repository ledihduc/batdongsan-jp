"""reservation_exclude_constraint

Phase 01h — Postgres concurrency hardening. Installs btree_gist extension
and adds an EXCLUDE USING gist constraint on `reservations` so that two
overlapping pending/approved/checked_in rows for the same room cannot
both be committed even under race-condition concurrency.

Replaces the long-standing TODO referenced in `0009_homestay_core.py` and
`app/services/reservation_service.py`.

Notes:
- `check_in_date` / `check_out_date` were originally VARCHAR(20) ISO
  strings (migration 0009). This migration promotes them to native
  `DATE` on Postgres so the GiST expression can reference them directly
  — `text::date` is STABLE (depends on DateStyle) and Postgres rejects
  it inside an index expression with "functions in index expression
  must be marked IMMUTABLE". The promotion is Postgres-only; SQLite
  dev DBs keep VARCHAR (SQLite is dynamically typed so the model's
  `Mapped[str]` keeps working).
- Range bound `'[)'` — check-out day is exclusive, so the room can be
  re-booked on the same day a previous guest leaves.
- Predicate `WHERE status IN ('pending','approved','checked_in')` — only
  active reservations participate in the EXCLUDE check; cancelled /
  rejected / checked_out rows are ignored.
- Postgres-only. SQLite dev DB silently skips (op.execute will run but
  the SQL is unsupported there; the migration is intended to be applied
  only on Postgres environments where Phase 01 already landed).

Revision ID: 0011_excl_reservation_overlap
Revises: 0010_marketplace_integration
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op

revision: str = "0011_excl_reservation_overlap"
down_revision: Union[str, Sequence[str], None] = "0010_marketplace_integration"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


CONSTRAINT_NAME = "excl_reservations_room_overlap"


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        # SQLite dev environments — no EXCLUDE / gist support; the
        # service-level overlap check in reservation_service stands in.
        return

    op.execute("CREATE EXTENSION IF NOT EXISTS btree_gist")

    # Promote check_in_date / check_out_date from VARCHAR(20) to DATE
    # so the daterange() expression below uses immutable inputs.
    op.execute(
        "ALTER TABLE reservations "
        "ALTER COLUMN check_in_date TYPE date USING check_in_date::date"
    )
    op.execute(
        "ALTER TABLE reservations "
        "ALTER COLUMN check_out_date TYPE date USING check_out_date::date"
    )

    op.execute(
        f"""
        ALTER TABLE reservations
        ADD CONSTRAINT {CONSTRAINT_NAME}
        EXCLUDE USING gist (
          room_id WITH =,
          daterange(check_in_date, check_out_date, '[)') WITH &&
        )
        WHERE (status IN ('pending', 'approved', 'checked_in'))
        """
    )


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        return

    op.execute(
        f"ALTER TABLE reservations DROP CONSTRAINT IF EXISTS {CONSTRAINT_NAME}"
    )
    op.execute(
        "ALTER TABLE reservations "
        "ALTER COLUMN check_in_date TYPE varchar(20) USING check_in_date::text"
    )
    op.execute(
        "ALTER TABLE reservations "
        "ALTER COLUMN check_out_date TYPE varchar(20) USING check_out_date::text"
    )
    # Intentionally NOT dropping btree_gist — extensions are typically
    # shared across the database and other features may rely on it.
