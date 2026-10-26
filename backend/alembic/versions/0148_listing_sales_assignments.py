"""Create listing_sales_assignments table — JP sales agent assignment to listings.

Used by role_scope.py to determine if a sales agent has access to a specific listing.
The 'sales' role is scoped to 'assigned' listings only; this table is the authority.

Idempotent: checks has_table() before create.
Has downgrade(): drops table and indexes.

Revision ID: 0148_listing_sales_assignments
Revises: 0147_jp_applications
"""

from alembic import op
import sqlalchemy as sa

revision = "0148_listing_sales_assignments"
down_revision = "0147_jp_applications"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if insp.has_table("listing_sales_assignments"):
        return

    op.create_table(
        "listing_sales_assignments",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        # Listing reference (no FK to avoid cross-schema dep on core listing table)
        sa.Column("listing_id", sa.String(64), nullable=False,
                  comment="Listing UUID. No FK to keep JP domain isolated from core."),
        # Sales agent user ID
        sa.Column("sales_user_id", sa.Integer(), nullable=False,
                  comment="User ID of the assigned sales agent (仲介担当)"),
        # Multi-tenant isolation
        # NOTE: org_id is the core multi-tenant isolation key for all JP tables.
        # Every repository list query MUST filter by org_id by default.
        # No inline index=True — explicit op.create_index below owns the
        # ix_listing_sales_assignments_org_id index.
        sa.Column("org_id", sa.String(64), nullable=True,
                  comment="Broker org tenant ID. MUST be filtered in every list query."),
        sa.Column("region", sa.String(3), nullable=False, server_default="jp"),
        # Whether this assignment is currently active
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        # Timestamps
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    op.create_index("ix_listing_sales_assignments_listing_id", "listing_sales_assignments", ["listing_id"])
    op.create_index("ix_listing_sales_assignments_sales_user_id", "listing_sales_assignments", ["sales_user_id"])
    op.create_index("ix_listing_sales_assignments_org_id", "listing_sales_assignments", ["org_id"])
    # Composite for efficient "is this sales user assigned to this listing?" lookup
    op.create_index(
        "ix_listing_sales_assignments_listing_sales",
        "listing_sales_assignments",
        ["listing_id", "sales_user_id"],
    )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("listing_sales_assignments"):
        return

    op.drop_index("ix_listing_sales_assignments_listing_sales", table_name="listing_sales_assignments")
    op.drop_index("ix_listing_sales_assignments_org_id", table_name="listing_sales_assignments")
    op.drop_index("ix_listing_sales_assignments_sales_user_id", table_name="listing_sales_assignments")
    op.drop_index("ix_listing_sales_assignments_listing_id", table_name="listing_sales_assignments")
    op.drop_table("listing_sales_assignments")
