"""Create jp_webhook_events table — audit log for all incoming JP provider webhooks.

Idempotency: external_event_id UNIQUE prevents double-processing.
Handlers MUST check this table before acting on any event.

HMAC verification must happen BEFORE inserting to this table (at route level).
Insert = "we accepted this event". processed_at = "we handled it".

Idempotent: checks has_table() before create.
Has downgrade(): drops table.

Revision ID: 0152_jp_webhook_events
Revises: 0151_jp_payment_intents
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0152_jp_webhook_events"
down_revision = "0151_jp_payment_intents"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    json_type = (
        postgresql.JSONB()
        if bind.dialect.name == "postgresql"
        else sa.JSON()
    )

    if not insp.has_table("jp_webhook_events"):
        op.create_table(
            "jp_webhook_events",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            # Provider identification
            sa.Column(
                "provider", sa.String(32), nullable=False,
                comment="Source provider (komoju | cloudsign | zoom).",
            ),
            sa.Column(
                "event_type", sa.String(100), nullable=False,
                comment="Provider event type string (e.g. 'payment.succeeded').",
            ),
            # Idempotency key — provider-assigned event ID
            sa.Column(
                "external_event_id", sa.String(256), nullable=False,
                comment="Provider-assigned event ID. UNIQUE to enforce idempotency.",
            ),
            sa.Column(
                "idempotency_key", sa.String(256), nullable=True,
                comment=(
                    "Computed idempotency key (provider:event_id). "
                    "Alias for external_event_id for clarity."
                ),
            ),
            # Full payload for audit/replay
            sa.Column(
                "payload", json_type, nullable=False,
                comment="Full raw webhook payload stored for audit and replay.",
            ),
            # Timestamps
            sa.Column(
                "received_at", sa.DateTime(), nullable=False, server_default=sa.func.now(),
                comment="When we received the webhook.",
            ),
            sa.Column(
                "processed_at", sa.DateTime(), nullable=True,
                comment="When we finished processing. Null = not yet processed.",
            ),
            # Unique constraint on external_event_id for idempotency
            sa.UniqueConstraint(
                "external_event_id",
                name="uq_jp_webhook_events_external_event_id",
            ),
        )

        op.create_index(
            "ix_jp_webhook_events_provider_event_type",
            "jp_webhook_events",
            ["provider", "event_type"],
        )
        op.create_index(
            "ix_jp_webhook_events_received_at",
            "jp_webhook_events",
            ["received_at"],
        )


def downgrade() -> None:
    op.drop_table("jp_webhook_events")
