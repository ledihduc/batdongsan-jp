"""Add canonical viewing workflow without rewriting legacy appointments.

Revision ID: 0122_viewing_v2_canonical
Revises: 0121_activity_deposit_policy_snapshots
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op


revision = "0122_viewing_v2_canonical"
down_revision = "0121_activity_deposit_policy_snapshots"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "viewing_appointments",
        sa.Column("canonical_status", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "viewing_appointments",
        sa.Column("canonical_version", sa.Integer(), nullable=False, server_default="1"),
    )
    op.add_column("viewing_appointments", sa.Column("confirmed_at", sa.DateTime(), nullable=True))
    op.add_column("viewing_appointments", sa.Column("completed_at", sa.DateTime(), nullable=True))
    op.add_column("viewing_appointments", sa.Column("cancelled_at", sa.DateTime(), nullable=True))
    op.add_column("viewing_appointments", sa.Column("cancelled_by_user_id", sa.Integer(), nullable=True))
    op.add_column("viewing_appointments", sa.Column("cancelled_by_role", sa.String(length=20), nullable=True))
    op.add_column("viewing_appointments", sa.Column("cancel_reason_code", sa.String(length=50), nullable=True))
    op.add_column("viewing_appointments", sa.Column("cancel_reason_note", sa.Text(), nullable=True))
    op.create_foreign_key(
        "fk_viewing_cancelled_by_user",
        "viewing_appointments",
        "users",
        ["cancelled_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_viewing_appointments_canonical_status",
        "viewing_appointments",
        ["canonical_status"],
    )
    op.execute(
        """
        UPDATE viewing_appointments
        SET canonical_status = CASE
          WHEN status = 'pending' THEN 'REQUESTED'
          WHEN status = 'doi_gio' THEN 'WAITING_CUSTOMER'
          WHEN status IN ('approved', 'confirmed') THEN 'CONFIRMED'
          WHEN status IN ('completed', 'locked', 'awaiting_guest') THEN 'COMPLETED'
          WHEN status = 'no_show' THEN 'NO_SHOW'
          WHEN status IN ('cancelled', 'rejected', 'lost') THEN 'CANCELLED'
          ELSE 'FAILED'
        END
        WHERE canonical_status IS NULL
        """
    )

    op.create_table(
        "viewing_proposals",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "appointment_id",
            sa.Integer(),
            sa.ForeignKey("viewing_appointments.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "proposed_by_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("proposed_by_role", sa.String(length=20), nullable=False),
        sa.Column("booking_date", sa.String(length=20), nullable=False),
        sa.Column("booking_time", sa.String(length=50), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="PENDING"),
        sa.Column("accepted_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint(
            "appointment_id",
            "booking_date",
            "booking_time",
            name="uq_viewing_proposal_slot",
        ),
    )
    op.create_index("ix_viewing_proposals_appointment", "viewing_proposals", ["appointment_id"])
    op.create_index("ix_viewing_proposals_status", "viewing_proposals", ["status"])

    op.create_table(
        "viewing_results",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "appointment_id",
            sa.Integer(),
            sa.ForeignKey("viewing_appointments.id", ondelete="RESTRICT"),
            nullable=False,
            unique=True,
        ),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("reason_code", sa.String(length=50), nullable=True),
        sa.Column("reason_note", sa.Text(), nullable=True),
        sa.Column(
            "submitted_by_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("submitted_by_role", sa.String(length=20), nullable=False),
        sa.Column("submitted_at", sa.DateTime(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
    )
    op.create_index("ix_viewing_results_status", "viewing_results", ["status"])

    op.create_table(
        "viewing_issues",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "appointment_id",
            sa.Integer(),
            sa.ForeignKey("viewing_appointments.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "reporter_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("reporter_role", sa.String(length=20), nullable=False),
        sa.Column("issue_code", sa.String(length=50), nullable=False),
        sa.Column("detail", sa.Text(), nullable=True),
        sa.Column("evidence_urls", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="OPEN"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_viewing_issues_appointment", "viewing_issues", ["appointment_id"])
    op.create_index("ix_viewing_issues_status", "viewing_issues", ["status"])

    op.create_table(
        "viewing_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "appointment_id",
            sa.Integer(),
            sa.ForeignKey("viewing_appointments.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "actor_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("actor_role", sa.String(length=20), nullable=False),
        sa.Column("event_type", sa.String(length=50), nullable=False),
        sa.Column("from_status", sa.String(length=32), nullable=True),
        sa.Column("to_status", sa.String(length=32), nullable=True),
        sa.Column("payload", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_viewing_events_appointment", "viewing_events", ["appointment_id"])
    op.create_index("ix_viewing_events_created", "viewing_events", ["created_at"])


def downgrade() -> None:
    op.drop_table("viewing_events")
    op.drop_table("viewing_issues")
    op.drop_table("viewing_results")
    op.drop_table("viewing_proposals")
    op.drop_index("ix_viewing_appointments_canonical_status", table_name="viewing_appointments")
    op.drop_constraint("fk_viewing_cancelled_by_user", "viewing_appointments", type_="foreignkey")
    for name in (
        "cancel_reason_note",
        "cancel_reason_code",
        "cancelled_by_role",
        "cancelled_by_user_id",
        "cancelled_at",
        "completed_at",
        "confirmed_at",
        "canonical_version",
        "canonical_status",
    ):
        op.drop_column("viewing_appointments", name)
