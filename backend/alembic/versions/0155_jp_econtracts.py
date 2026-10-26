"""Create jp_econtracts table — electronic contract via CloudSign.

The electronic contract (電子契約) is the final step in the JP rental flow.
CloudSign sends webhook events when the tenant signs (or rejects) the document.

Status state machine:
  draft → sent → viewed → signed | cancelled

Idempotent: checks has_table() before create.
Has downgrade(): drops table.

Revision ID: 0155_jp_econtracts
Revises: 0154_jp_it_sessions
"""

from alembic import op
import sqlalchemy as sa

revision = "0155_jp_econtracts"
down_revision = "0154_jp_it_sessions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_econtracts"):
        op.create_table(
            "jp_econtracts",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "org_id", sa.String(64), nullable=False, index=True,
                comment="Broker org tenant ID. MUST be filtered in every list query.",
            ),
            sa.Column(
                "region", sa.String(3), nullable=False, server_default="jp",
                comment="Defense-in-depth region tag. Always 'jp'.",
            ),
            # Parent application
            sa.Column(
                "application_id", sa.Integer(), nullable=False, index=True,
                comment="JpTenantApplication.id. No FK — cross-domain boundary.",
            ),
            # Provider
            sa.Column(
                "provider", sa.String(32), nullable=False, server_default="cloudsign",
                comment="eSign provider name (cloudsign).",
            ),
            sa.Column(
                "remote_doc_id", sa.String(128), nullable=True,
                comment="CloudSign document ID. Null until document is created.",
            ),
            # Status
            sa.Column(
                "status", sa.String(20), nullable=False, server_default="draft",
                comment="draft | sent | viewed | signed | cancelled",
            ),
            # Signed PDF
            sa.Column(
                "signed_pdf_url", sa.String(500), nullable=True,
                comment="URL to signed PDF. Populated by CloudSign webhook after signing.",
            ),
            # Template tracking
            sa.Column(
                "template_version", sa.String(20), nullable=True,
                comment="Version of contract template used. For audit.",
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column(
                "updated_at", sa.DateTime(), nullable=False,
                server_default=sa.func.now(), onupdate=sa.func.now(),
            ),
        )

        op.create_index(
            "ix_jp_econtracts_remote_doc_id",
            "jp_econtracts",
            ["remote_doc_id"],
        )


def downgrade() -> None:
    op.drop_table("jp_econtracts")
