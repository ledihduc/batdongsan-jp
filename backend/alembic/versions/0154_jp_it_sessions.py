"""Create jp_it_sessions table — IT重説 (online rental explanation) sessions.

IT重説 is a JP legal requirement (宅地建物取引業法 35条) that mandates
a licensed 宅建士 (real estate agent) explain the rental contract online
before signing. Tenant must give explicit consent before entering the session.

Status state machine:
  scheduled → in_progress → completed | cancelled

Idempotent: checks has_table() before create.
Has downgrade(): drops table.

Revision ID: 0154_jp_it_sessions
Revises: 0153_jp_user_consents
"""

from alembic import op
import sqlalchemy as sa

revision = "0154_jp_it_sessions"
down_revision = "0153_jp_user_consents"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_it_sessions"):
        op.create_table(
            "jp_it_sessions",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column(
                "org_id", sa.String(64), nullable=False, index=True,
                comment="Broker org tenant ID. MUST be filtered in every list query.",
            ),
            sa.Column(
                "region", sa.String(3), nullable=False, server_default="jp",
                comment="Defense-in-depth region tag. Always 'jp'.",
            ),
            # Viewing this session is tied to
            sa.Column(
                "viewing_id", sa.Integer(), nullable=False, index=True,
                comment="JpViewing.id. No FK — cross-domain boundary.",
            ),
            # 宅建士 conducting the session
            sa.Column(
                "takken_shi_id", sa.Integer(), nullable=False,
                comment="User ID of 宅建士 (licensed agent). Role='takken_shi'.",
            ),
            # Scheduling
            sa.Column(
                "scheduled_at", sa.DateTime(), nullable=False,
                comment="Planned session start time (JST — stored as UTC).",
            ),
            # Zoom meeting details
            sa.Column(
                "zoom_meeting_id", sa.String(128), nullable=True,
                comment="Zoom Meeting ID. Null until Zoom API responds.",
            ),
            sa.Column(
                "zoom_join_url", sa.String(500), nullable=True,
                comment="Tenant-facing Zoom join URL. Null until created.",
            ),
            # Session status
            sa.Column(
                "status", sa.String(20), nullable=False, server_default="scheduled",
                comment="scheduled | in_progress | completed | cancelled",
            ),
            # Consent capture (tenant must consent before entering)
            sa.Column(
                "tenant_consent_at", sa.DateTime(), nullable=True,
                comment="UTC timestamp when tenant gave IT重説 consent. Null = not yet consented.",
            ),
            # Recording
            sa.Column(
                "recording_url", sa.String(500), nullable=True,
                comment="Zoom cloud recording URL (short-lived signed URL). Null until available.",
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column(
                "updated_at", sa.DateTime(), nullable=False,
                server_default=sa.func.now(), onupdate=sa.func.now(),
            ),
        )


def downgrade() -> None:
    op.drop_table("jp_it_sessions")
