"""Create jp_viewings table — 内見 (naiken) viewing appointment scheduler.

JP viewing flow:
  tenant requests up to 3 preferred slots → agent confirms one → both notified
  State machine: requested → confirmed → completed | cancelled

Constraints:
  - Slots stored as JSONB array of ISO timestamps (max 3 entries enforced at service layer)
  - lead_time_hours: confirmed_slot must be ≥24h from created_at (enforced at service layer)

Idempotent: checks has_table() before create.
Has downgrade(): drops table and indexes.

Revision ID: 0146_jp_viewings
Revises: 0145_jp_transit
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0146_jp_viewings"
down_revision = "0145_jp_transit"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if insp.has_table("jp_viewings"):
        return

    # Use JSON type — compatible with both PostgreSQL (JSONB) and SQLite (JSON/TEXT)
    json_type = (
        postgresql.JSONB()
        if bind.dialect.name == "postgresql"
        else sa.JSON()
    )

    op.create_table(
        "jp_viewings",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        # Multi-tenant isolation
        # NOTE: org_id is the core multi-tenant isolation key for all JP tables.
        # Every repository list query MUST filter by org_id by default.
        sa.Column("org_id", sa.String(64), nullable=True, index=True,
                  comment="Broker org tenant ID. MUST be filtered in every list query."),
        sa.Column("region", sa.String(3), nullable=False, server_default="jp",
                  comment="Defense-in-depth region tag. Always 'jp'."),
        # Listing reference (no FK to avoid cross-table dep on core listing)
        sa.Column("listing_id", sa.String(64), nullable=False,
                  comment="Listing UUID"),
        # Tenant who made the viewing request
        sa.Column("tenant_id", sa.Integer(), nullable=False,
                  comment="User ID of the tenant requesting the viewing"),
        # Agent assigned to the listing who will confirm
        sa.Column("agent_id", sa.Integer(), nullable=True,
                  comment="User ID of the sales agent. Nullable until assigned."),
        # Requested slots: JSONB array of ISO 8601 timestamps (max 3 per business rule)
        # Service layer enforces: max 3 slots, each in business hours 10-19 JST, lead ≥24h
        sa.Column("requested_slots", json_type, nullable=False,
                  comment="Array of ISO timestamp strings. Max 3 entries. Business hours only."),
        # The slot confirmed by the agent (one of the requested_slots values)
        sa.Column("confirmed_slot_ts", sa.DateTime(), nullable=True,
                  comment="The confirmed viewing datetime. Must be in requested_slots."),
        # Viewing status state machine
        # requested → confirmed → completed | cancelled
        sa.Column("status", sa.String(20), nullable=False, server_default="requested",
                  comment="State: requested | confirmed | completed | cancelled"),
        # Notes from agent or tenant
        sa.Column("notes", sa.Text(), nullable=True),
        # Timestamps
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    op.create_index("ix_jp_viewings_listing_id", "jp_viewings", ["listing_id"])
    op.create_index("ix_jp_viewings_tenant_id", "jp_viewings", ["tenant_id"])
    op.create_index("ix_jp_viewings_agent_id", "jp_viewings", ["agent_id"])
    # Composite index for org-scoped status filtering (common query pattern)
    op.create_index(
        "ix_jp_viewings_org_status",
        "jp_viewings",
        ["org_id", "status"],
    )
    op.create_index("ix_jp_viewings_region", "jp_viewings", ["region"])


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_viewings"):
        return

    op.drop_index("ix_jp_viewings_region", table_name="jp_viewings")
    op.drop_index("ix_jp_viewings_org_status", table_name="jp_viewings")
    op.drop_index("ix_jp_viewings_agent_id", table_name="jp_viewings")
    op.drop_index("ix_jp_viewings_tenant_id", table_name="jp_viewings")
    op.drop_index("ix_jp_viewings_listing_id", table_name="jp_viewings")
    op.drop_table("jp_viewings")
