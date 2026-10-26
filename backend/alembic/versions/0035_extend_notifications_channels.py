"""extend notifications with multi-channel delivery columns

Revision ID: 0035_extend_notifications_channels
Revises: 0034_extend_invoices_platform_fee
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

Adds multi-channel notification delivery tracking:
  - channel: delivery channel (in_app | push | email | sms | zalo-placeholder)
  - delivery_status: delivery lifecycle (queued | sent | delivered | failed | bounced)
  - external_message_id: vendor message ID for read-receipt tracking (SES/eSMS ref)
  - read_receipt_opened_at: NFR-14 high-value approval early-SMS trigger

v1 scope: in_app + email channels.
v1.1: Zalo ZNS + SMS channels (zalo = placeholder for schema forward-compat).
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0035_extend_notifications_channels"
down_revision = "0034_extend_invoices_platform_fee"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("notifications") as batch_op:
        # Delivery channel: in_app | push | email | sms | zalo (zalo = v1.1 placeholder)
        batch_op.add_column(
            sa.Column(
                "channel",
                sa.String(20),
                nullable=False,
                server_default="in_app",
            )
        )
        # Delivery status: queued | sent | delivered | failed | bounced
        batch_op.add_column(
            sa.Column(
                "delivery_status",
                sa.String(20),
                nullable=False,
                server_default="queued",
            )
        )
        # Vendor message ID for read-receipt correlation (SES message id, eSMS ref id)
        batch_op.add_column(
            sa.Column("external_message_id", sa.String(200), nullable=True)
        )
        # NFR-14: timestamp when notification was opened (triggers early-SMS for high-value approvals)
        batch_op.add_column(
            sa.Column("read_receipt_opened_at", sa.DateTime, nullable=True)
        )

    # Index for delivery status queries (e.g., find failed notifications for retry)
    op.create_index(
        "ix_notifications_channel_status",
        "notifications",
        ["channel", "delivery_status"],
    )


def downgrade() -> None:
    op.drop_index("ix_notifications_channel_status", table_name="notifications")

    with op.batch_alter_table("notifications") as batch_op:
        batch_op.drop_column("read_receipt_opened_at")
        batch_op.drop_column("external_message_id")
        batch_op.drop_column("delivery_status")
        batch_op.drop_column("channel")
