"""Add auditable rental journey workflow.

Revision ID: 0117_rental_journey
Revises: 0116_dat_phong_so_khach
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0117_rental_journey"
down_revision = "0116_dat_phong_so_khach"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "rental_journeys",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "appointment_id",
            sa.Integer(),
            sa.ForeignKey("viewing_appointments.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("room_id", sa.Integer(), sa.ForeignKey("rooms.id", ondelete="SET NULL")),
        sa.Column("house_id", sa.Integer(), sa.ForeignKey("houses.id", ondelete="SET NULL")),
        sa.Column(
            "customer_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("sale_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column(
            "owner_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("status", sa.String(40), nullable=False),
        sa.Column("total_deposit", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("contract_urls", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("contract_note", sa.Text()),
        sa.Column("contract_submitted_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("contract_submitted_at", sa.DateTime()),
        sa.Column("cancel_reason", sa.Text()),
        sa.Column("cancelled_at", sa.DateTime()),
        sa.Column("completed_at", sa.DateTime()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("appointment_id", name="uq_rental_journey_appointment"),
    )
    for column in ("appointment_id", "room_id", "house_id", "customer_id", "sale_id", "owner_id", "status"):
        op.create_index(f"ix_rental_journeys_{column}", "rental_journeys", [column])

    op.create_table(
        "rental_journey_payments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("journey_id", sa.Integer(), sa.ForeignKey("rental_journeys.id", ondelete="CASCADE"), nullable=False),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("amount", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(20), nullable=False, server_default="PENDING"),
        sa.Column("proof_urls", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("submitted_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("submitted_at", sa.DateTime()),
        sa.Column("acknowledged_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("acknowledged_at", sa.DateTime()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("journey_id", "kind", name="uq_rental_journey_payment_kind"),
    )
    op.create_index("ix_rental_journey_payments_journey_id", "rental_journey_payments", ["journey_id"])
    op.create_index("ix_rental_journey_payments_status", "rental_journey_payments", ["status"])

    op.create_table(
        "rental_journey_reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("journey_id", sa.Integer(), sa.ForeignKey("rental_journeys.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reporter_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("reported_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("reason_code", sa.String(50), nullable=False),
        sa.Column("detail", sa.Text()),
        sa.Column("evidence_urls", sa.Text(), nullable=False, server_default="[]"),
        sa.Column("status", sa.String(20), nullable=False, server_default="PENDING"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("journey_id", "reporter_id", "reason_code", name="uq_rental_journey_report_reason"),
    )
    for column in ("journey_id", "reporter_id", "reported_user_id", "reason_code", "status"):
        op.create_index(f"ix_rental_journey_reports_{column}", "rental_journey_reports", [column])

    op.create_table(
        "rental_journey_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("journey_id", sa.Integer(), sa.ForeignKey("rental_journeys.id", ondelete="CASCADE"), nullable=False),
        sa.Column("actor_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("actor_role", sa.String(20), nullable=False),
        sa.Column("event_type", sa.String(50), nullable=False),
        sa.Column("from_status", sa.String(40)),
        sa.Column("to_status", sa.String(40)),
        sa.Column("payload", sa.JSON()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_rental_journey_events_journey_id", "rental_journey_events", ["journey_id"])
    op.create_index("ix_rental_journey_events_event_type", "rental_journey_events", ["event_type"])
    op.create_index("ix_rental_journey_events_created_at", "rental_journey_events", ["created_at"])


def downgrade() -> None:
    op.drop_table("rental_journey_events")
    op.drop_table("rental_journey_reports")
    op.drop_table("rental_journey_payments")
    op.drop_table("rental_journeys")
