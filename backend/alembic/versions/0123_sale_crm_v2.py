"""Add private Sale CRM and deal pipeline projection.

Revision ID: 0123_sale_crm_v2
Revises: 0122_viewing_v2_canonical
"""

import sqlalchemy as sa
from alembic import op

revision = "0123_sale_crm_v2"
down_revision = "0122_viewing_v2_canonical"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("deals", sa.Column("pipeline_stage", sa.String(32), nullable=True))
    op.add_column("deals", sa.Column("loss_reason_code", sa.String(50), nullable=True))
    op.add_column("deals", sa.Column("lost_at", sa.DateTime(), nullable=True))
    op.create_index("ix_deals_pipeline_stage", "deals", ["pipeline_stage"])
    op.execute("""
        UPDATE deals SET pipeline_stage = CASE
          WHEN status = 'confirmed' THEN 'WON'
          WHEN status IN ('rejected', 'cancelled', 'lost') THEN 'LOST'
          WHEN status = 'awaiting_guest' THEN 'PAPERWORK'
          ELSE 'FOLLOW_UP' END
        WHERE pipeline_stage IS NULL
    """)

    op.create_table(
        "sale_crm_contacts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("sale_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("contact_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("contact_type", sa.String(20), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="ACTIVE"),
        sa.Column("source_type", sa.String(32), nullable=False),
        sa.Column("source_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("sale_id", "contact_user_id", "contact_type", name="uq_sale_crm_contact_relation"),
    )
    for name, columns in (
        ("ix_sale_crm_contacts_sale", ["sale_id"]),
        ("ix_sale_crm_contacts_user", ["contact_user_id"]),
        ("ix_sale_crm_contacts_type", ["contact_type"]),
        ("ix_sale_crm_contacts_status", ["status"]),
    ):
        op.create_index(name, "sale_crm_contacts", columns)

    op.create_table(
        "sale_crm_tasks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("sale_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("contact_id", sa.Integer(), sa.ForeignKey("sale_crm_contacts.id", ondelete="CASCADE"), nullable=True),
        sa.Column("rental_journey_id", sa.Integer(), sa.ForeignKey("rental_journeys.id", ondelete="CASCADE"), nullable=True),
        sa.Column("title", sa.String(300), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("due_at", sa.DateTime(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="OPEN"),
        sa.Column("deep_link", sa.String(500), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
    )
    for name, columns in (
        ("ix_sale_crm_tasks_sale", ["sale_id"]),
        ("ix_sale_crm_tasks_contact", ["contact_id"]),
        ("ix_sale_crm_tasks_journey", ["rental_journey_id"]),
        ("ix_sale_crm_tasks_due", ["due_at"]),
        ("ix_sale_crm_tasks_status", ["status"]),
    ):
        op.create_index(name, "sale_crm_tasks", columns)

    op.create_table(
        "sale_crm_notes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("sale_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("contact_id", sa.Integer(), sa.ForeignKey("sale_crm_contacts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_sale_crm_notes_sale", "sale_crm_notes", ["sale_id"])
    op.create_index("ix_sale_crm_notes_contact", "sale_crm_notes", ["contact_id"])

    op.create_table(
        "sale_crm_activities",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("sale_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("contact_id", sa.Integer(), sa.ForeignKey("sale_crm_contacts.id", ondelete="CASCADE"), nullable=True),
        sa.Column("activity_type", sa.String(50), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_sale_crm_activities_sale", "sale_crm_activities", ["sale_id"])
    op.create_index("ix_sale_crm_activities_contact", "sale_crm_activities", ["contact_id"])
    op.create_index("ix_sale_crm_activities_type", "sale_crm_activities", ["activity_type"])
    op.create_index("ix_sale_crm_activities_created", "sale_crm_activities", ["created_at"])


def downgrade() -> None:
    op.drop_table("sale_crm_activities")
    op.drop_table("sale_crm_notes")
    op.drop_table("sale_crm_tasks")
    op.drop_table("sale_crm_contacts")
    op.drop_index("ix_deals_pipeline_stage", table_name="deals")
    op.drop_column("deals", "lost_at")
    op.drop_column("deals", "loss_reason_code")
    op.drop_column("deals", "pipeline_stage")
