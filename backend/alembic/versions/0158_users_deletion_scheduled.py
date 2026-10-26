"""Add deletion_scheduled_at to users table — APPI DSR deletion scheduling.

Adds nullable TIMESTAMPTZ column to users table for tracking deletion requests.
The daily cron job soft-anonymizes users whose deletion_scheduled_at < now().

Idempotent: inspects existing columns before adding.
Has downgrade(): drops the column.

Revision ID: 0158_users_deletion_scheduled
Revises: 0157_deposit_settlements
"""

from alembic import op
import sqlalchemy as sa

revision = "0158_users_deletion_scheduled"
down_revision = "0157_deposit_settlements"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # Only add column if users table exists and column is missing
    if insp.has_table("users"):
        existing_cols = {c["name"] for c in insp.get_columns("users")}

        if "deletion_scheduled_at" not in existing_cols:
            op.add_column(
                "users",
                sa.Column(
                    "deletion_scheduled_at",
                    sa.DateTime(timezone=True),
                    nullable=True,
                    comment=(
                        "APPI DSR: when to purge this user's PII. "
                        "Set to now()+30d on deletion request. "
                        "Null = no pending deletion. "
                        "Daily cron anonymizes users past this timestamp."
                    ),
                ),
            )
            op.create_index(
                "ix_users_deletion_scheduled_at",
                "users",
                ["deletion_scheduled_at"],
            )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if insp.has_table("users"):
        existing_cols = {c["name"] for c in insp.get_columns("users")}
        if "deletion_scheduled_at" in existing_cols:
            op.drop_index("ix_users_deletion_scheduled_at", table_name="users")
            op.drop_column("users", "deletion_scheduled_at")
