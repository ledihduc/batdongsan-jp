"""Create org_provider_configs table — per-org payment/eSign/conference provider credentials.

B2B multi-tenant design: each broker org brings their own merchant accounts.
Credentials are stored encrypted (Fernet/AES128-CBC) in config_encrypted JSONB.
The encryption key is derived from settings.secret_key — see app/services/crypto.py.

Idempotent: checks has_table() before create.
Has downgrade(): drops table.

Revision ID: 0149_org_provider_configs
Revises: 0148_listing_sales_assignments
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0149_org_provider_configs"
down_revision = "0148_listing_sales_assignments"
branch_labels = None
depends_on = None

# Valid provider_type values
PROVIDER_TYPES = ("payment", "esign", "conference", "notification")


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    json_type = (
        postgresql.JSONB()
        if bind.dialect.name == "postgresql"
        else sa.JSON()
    )

    if not insp.has_table("org_provider_configs"):
        op.create_table(
            "org_provider_configs",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "org_id", sa.String(64), nullable=False, index=True,
                comment="Broker org tenant ID. Part of uniqueness constraint.",
            ),
            sa.Column(
                "provider_type", sa.String(20), nullable=False,
                comment="payment | esign | conference | notification",
            ),
            sa.Column(
                "provider_name", sa.String(64), nullable=False,
                comment="e.g. komoju | cloudsign | zoom",
            ),
            sa.Column(
                "config_encrypted", json_type, nullable=True,
                comment="Fernet-encrypted JSON blob of provider credentials. Never store plaintext.",
            ),
            sa.Column(
                "is_sandbox", sa.Boolean(), nullable=False, server_default="true",
                comment="True = sandbox/test mode. Must be explicitly set false in prod.",
            ),
            sa.Column(
                "created_at", sa.DateTime(), nullable=False,
                server_default=sa.func.now(),
            ),
            sa.Column(
                "updated_at", sa.DateTime(), nullable=False,
                server_default=sa.func.now(), onupdate=sa.func.now(),
            ),
            # One active config per org+provider_type+provider_name
            sa.UniqueConstraint(
                "org_id", "provider_type", "provider_name",
                name="uq_org_provider_configs_org_type_name",
            ),
        )

        op.create_index(
            "ix_org_provider_configs_org_type",
            "org_provider_configs",
            ["org_id", "provider_type"],
        )


def downgrade() -> None:
    op.drop_table("org_provider_configs")
