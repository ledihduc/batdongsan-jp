"""homestay_core

Phase 07 — homestay tables: Availability, PricingRule, Reservation.

Postgres-only concurrency hardening (EXCLUDE USING gist on reservations) is
installed by migration 0011_excl_reservation_overlap (Phase 01h). The
service-level overlap check in reservation_service.create_reservation()
stands in for SQLite dev environments and produces a 400 instead of a
500 IntegrityError on Postgres.

Revision ID: 0009_homestay_core
Revises: 0008_report_indexes
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0009_homestay_core"
down_revision: Union[str, Sequence[str], None] = "0008_report_indexes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── reservations ───────────────────────────────────────────────────────
    op.create_table(
        "reservations",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("guest_user_id", sa.Integer(), nullable=True),
        sa.Column("guest_name", sa.String(length=300), nullable=False),
        sa.Column("guest_phone", sa.String(length=50), nullable=False, server_default=""),
        sa.Column("guest_email", sa.String(length=200), nullable=True),
        sa.Column("check_in_date", sa.String(length=20), nullable=False),
        sa.Column("check_out_date", sa.String(length=20), nullable=False),
        sa.Column("nights", sa.Integer(), nullable=False),
        sa.Column("total_amount", sa.Float(), nullable=False),
        sa.Column("deposit_paid", sa.Float(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
        sa.Column(
            "cancel_policy_snapshot",
            sa.Text(),
            nullable=False,
            server_default='{"version":"v1","rigid_24h":true}',
        ),
        sa.Column("cancelled_at", sa.DateTime(), nullable=True),
        sa.Column("refund_amount", sa.Float(), nullable=True),
        sa.Column("rejection_reason", sa.Text(), nullable=True),
        sa.Column("source", sa.String(length=20), nullable=False, server_default="manual"),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "status IN ('pending','approved','rejected','checked_in',"
            "'checked_out','cancelled','no_show')",
            name="ck_reservations_status",
        ),
        sa.CheckConstraint("nights > 0", name="ck_reservations_nights_positive"),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["guest_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_reservations_host_id", "reservations", ["host_id"])
    op.create_index("ix_reservations_room_id", "reservations", ["room_id"])
    op.create_index("ix_reservations_status", "reservations", ["status"])
    op.create_index("ix_reservations_host_status", "reservations", ["host_id", "status"])
    op.create_index(
        "ix_reservations_room_dates",
        "reservations",
        ["room_id", "check_in_date", "check_out_date"],
    )

    # ── availability ───────────────────────────────────────────────────────
    op.create_table(
        "availability",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("date", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="available"),
        sa.Column("reservation_id", sa.Integer(), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "status IN ('available','blocked','reserved')",
            name="ck_availability_status",
        ),
        sa.UniqueConstraint("room_id", "date", name="uq_availability_room_date"),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reservation_id"], ["reservations.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_availability_host_id", "availability", ["host_id"])
    op.create_index("ix_availability_room_id", "availability", ["room_id"])
    op.create_index("ix_availability_date", "availability", ["date"])
    op.create_index("ix_availability_reservation_id", "availability", ["reservation_id"])
    op.create_index("ix_availability_host_date", "availability", ["host_id", "date"])

    # ── pricing_rules ──────────────────────────────────────────────────────
    op.create_table(
        "pricing_rules",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=True),
        sa.Column("house_id", sa.Integer(), nullable=True),
        sa.Column("rule_type", sa.String(length=20), nullable=False),
        sa.Column("start_date", sa.String(length=20), nullable=False),
        sa.Column("end_date", sa.String(length=20), nullable=False),
        sa.Column("price_per_night", sa.Float(), nullable=False),
        sa.Column("priority", sa.Integer(), nullable=False, server_default="100"),
        sa.Column("weekday_mask", sa.Integer(), nullable=True),
        sa.Column("holiday_name", sa.String(length=200), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "rule_type IN ('base','weekend','holiday','manual')",
            name="ck_pricing_rules_type",
        ),
        sa.CheckConstraint("price_per_night >= 0", name="ck_pricing_rules_price_positive"),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_pricing_rules_host_id", "pricing_rules", ["host_id"])
    op.create_index("ix_pricing_rules_host_room", "pricing_rules", ["host_id", "room_id"])
    op.create_index("ix_pricing_rules_dates", "pricing_rules", ["start_date", "end_date"])

    # See migration 0011_excl_reservation_overlap for the
    # Postgres EXCLUDE USING gist constraint that makes overlap
    # detection race-condition-proof.


def downgrade() -> None:
    op.drop_index("ix_pricing_rules_dates", table_name="pricing_rules")
    op.drop_index("ix_pricing_rules_host_room", table_name="pricing_rules")
    op.drop_index("ix_pricing_rules_host_id", table_name="pricing_rules")
    op.drop_table("pricing_rules")

    op.drop_index("ix_availability_host_date", table_name="availability")
    op.drop_index("ix_availability_reservation_id", table_name="availability")
    op.drop_index("ix_availability_date", table_name="availability")
    op.drop_index("ix_availability_room_id", table_name="availability")
    op.drop_index("ix_availability_host_id", table_name="availability")
    op.drop_table("availability")

    op.drop_index("ix_reservations_room_dates", table_name="reservations")
    op.drop_index("ix_reservations_host_status", table_name="reservations")
    op.drop_index("ix_reservations_status", table_name="reservations")
    op.drop_index("ix_reservations_room_id", table_name="reservations")
    op.drop_index("ix_reservations_host_id", table_name="reservations")
    op.drop_table("reservations")
