"""Create jp_user_consents table — APPI (個人情報保護法) consent record.

Consent records are append-only (immutable audit trail).
Revocation is recorded as a new row with revoked_at set — original granted row
is NEVER modified or deleted (legal requirement).

Purpose values:
  service_use | marketing | analytics | data_sharing_broker | data_sharing_hoshou

Idempotent: checks has_table() before create.
Has downgrade(): drops table.

Revision ID: 0153_jp_user_consents
Revises: 0152_jp_webhook_events
"""

from alembic import op
import sqlalchemy as sa

revision = "0153_jp_user_consents"
down_revision = "0152_jp_webhook_events"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_user_consents"):
        op.create_table(
            "jp_user_consents",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "user_id", sa.Integer(), nullable=False, index=True,
                comment="Platform user ID.",
            ),
            sa.Column(
                "purpose", sa.String(40), nullable=False,
                comment=(
                    "service_use | marketing | analytics "
                    "| data_sharing_broker | data_sharing_hoshou"
                ),
            ),
            sa.Column(
                "consent_version", sa.String(20), nullable=False, server_default="1.0",
                comment="Version of consent text shown to user at grant time.",
            ),
            sa.Column(
                "granted_at", sa.DateTime(), nullable=False, server_default=sa.func.now(),
                comment="When user granted consent. Immutable once set.",
            ),
            sa.Column(
                "revoked_at", sa.DateTime(), nullable=True,
                comment=(
                    "When user revoked consent. Null = still active. "
                    "NEVER modify granted_at — append revoked_at only."
                ),
            ),
            # Audit metadata
            sa.Column(
                "ip_address", sa.String(45), nullable=True,
                comment="IPv4 or IPv6 address at grant time. pii=True",
            ),
            sa.Column(
                "user_agent", sa.String(500), nullable=True,
                comment="Browser/app user agent at grant time. pii=True",
            ),
            # Legal hold flag (set when user requests deletion but rows must be kept)
            sa.Column(
                "legal_hold", sa.Boolean(), nullable=False, server_default="false",
                comment="If true, row must not be purged regardless of DSR deletion.",
            ),
        )

        op.create_index(
            "ix_jp_user_consents_user_purpose",
            "jp_user_consents",
            ["user_id", "purpose"],
        )
        op.create_index(
            "ix_jp_user_consents_granted_at",
            "jp_user_consents",
            ["granted_at"],
        )


def downgrade() -> None:
    op.drop_table("jp_user_consents")
