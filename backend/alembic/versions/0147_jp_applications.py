"""Create jp_tenant_applications and jp_application_reviews tables.

入居申込 (tenant application) flow:
  tenant creates draft → submits → agent puts in_review → approved | rejected

PII note: 年収 (annual_income_jpy), 連帯保証人 (guarantor) fields contain PII.
Per phase-01 decision: field-level encryption deferred to P2 APPI work.
Columns are tagged with comment "pii=True" for future tooling discovery.

Idempotent: checks has_table() before each create.
Has downgrade(): drops both tables in FK-safe order.

Revision ID: 0147_jp_applications
Revises: 0146_jp_viewings
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0147_jp_applications"
down_revision = "0146_jp_viewings"
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

    # -- jp_tenant_applications -----------------------------------------
    if not insp.has_table("jp_tenant_applications"):
        op.create_table(
            "jp_tenant_applications",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            # Multi-tenant isolation
            # NOTE: org_id is the core multi-tenant isolation key for all JP tables.
            # Every repository list query MUST filter by org_id by default.
            sa.Column("org_id", sa.String(64), nullable=True, index=True,
                      comment="Broker org tenant ID. MUST be filtered in every list query."),
            sa.Column("region", sa.String(3), nullable=False, server_default="jp",
                      comment="Defense-in-depth region tag. Always 'jp'."),
            # Target listing (no FK to avoid cross-table dep)
            sa.Column("listing_id", sa.String(64), nullable=False,
                      comment="Listing UUID for the application"),
            # Applicant (tenant)
            sa.Column("applicant_user_id", sa.Integer(), nullable=False,
                      comment="User ID of the tenant applicant"),
            # Employment info — PII fields
            sa.Column("employer_name", sa.String(200), nullable=True,
                      comment="勤務先会社名. pii=True"),
            sa.Column("annual_income_jpy", sa.Numeric(12, 0), nullable=True,
                      comment="年収 in JPY. pii=True. Must be positive if provided."),
            # 連帯保証人 — joint guarantor
            sa.Column("guarantor_name", sa.String(200), nullable=True,
                      comment="連帯保証人氏名. pii=True"),
            sa.Column("guarantor_phone", sa.String(20), nullable=True,
                      comment="連帯保証人電話番号. pii=True"),
            # 緊急連絡先 — emergency contact
            sa.Column("emergency_contact_name", sa.String(200), nullable=True,
                      comment="緊急連絡先氏名. pii=True"),
            sa.Column("emergency_contact_phone", sa.String(20), nullable=True,
                      comment="緊急連絡先電話番号. pii=True"),
            # Document upload references (Supabase Storage URLs)
            sa.Column("documents", json_type, nullable=True,
                      comment="JSONB dict of document URLs keyed by doc type (e.g. income_cert, id_front)"),
            # Application status state machine
            # draft → submitted → in_review → approved | rejected
            sa.Column("status", sa.String(20), nullable=False, server_default="draft",
                      comment="State: draft | submitted | in_review | approved | rejected"),
            # Timestamps
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.Column("submitted_at", sa.DateTime(), nullable=True,
                      comment="When tenant submitted the application (draft → submitted transition)"),
        )
        op.create_index("ix_jp_tenant_applications_listing_id", "jp_tenant_applications", ["listing_id"])
        op.create_index("ix_jp_tenant_applications_applicant", "jp_tenant_applications", ["applicant_user_id"])
        # Composite index for org-scoped status filtering
        op.create_index(
            "ix_jp_tenant_applications_org_status",
            "jp_tenant_applications",
            ["org_id", "status"],
        )
        op.create_index("ix_jp_tenant_applications_region", "jp_tenant_applications", ["region"])

    # -- jp_application_reviews -----------------------------------------
    if not insp.has_table("jp_application_reviews"):
        op.create_table(
            "jp_application_reviews",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            # FK to application
            # No inline index=True — explicit op.create_index below owns the
            # ix_jp_application_reviews_application_id index.
            sa.Column(
                "application_id",
                sa.Integer(),
                sa.ForeignKey("jp_tenant_applications.id"),
                nullable=False,
            ),
            # Reviewer (sales agent or owner)
            sa.Column("reviewer_user_id", sa.Integer(), nullable=False,
                      comment="User ID of the reviewer (sales or owner role)"),
            # Decision — approved | rejected | needs_info
            sa.Column("decision", sa.String(20), nullable=False,
                      comment="approved | rejected | needs_info"),
            # Free-text notes for the applicant or internal audit
            sa.Column("notes", sa.Text(), nullable=True),
            # When the decision was made
            sa.Column("decided_at", sa.DateTime(), nullable=True,
                      comment="When reviewer finalized the decision"),
            # Multi-tenant isolation
            # NOTE: org_id is the core multi-tenant isolation key for all JP tables.
            # Every repository list query MUST filter by org_id by default.
            sa.Column("org_id", sa.String(64), nullable=True, index=True,
                      comment="Broker org tenant ID. MUST be filtered in every list query."),
            sa.Column("region", sa.String(3), nullable=False, server_default="jp"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
        op.create_index(
            "ix_jp_application_reviews_application_id",
            "jp_application_reviews",
            ["application_id"],
        )
        op.create_index(
            "ix_jp_application_reviews_reviewer",
            "jp_application_reviews",
            ["reviewer_user_id"],
        )
        op.create_index(
            "ix_jp_application_reviews_org_decision",
            "jp_application_reviews",
            ["org_id", "decision"],
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # Drop reviews first (FK dependency)
    if insp.has_table("jp_application_reviews"):
        op.drop_index("ix_jp_application_reviews_org_decision", table_name="jp_application_reviews")
        op.drop_index("ix_jp_application_reviews_reviewer", table_name="jp_application_reviews")
        op.drop_index("ix_jp_application_reviews_application_id", table_name="jp_application_reviews")
        op.drop_table("jp_application_reviews")

    if insp.has_table("jp_tenant_applications"):
        op.drop_index("ix_jp_tenant_applications_region", table_name="jp_tenant_applications")
        op.drop_index("ix_jp_tenant_applications_org_status", table_name="jp_tenant_applications")
        op.drop_index("ix_jp_tenant_applications_applicant", table_name="jp_tenant_applications")
        op.drop_index("ix_jp_tenant_applications_listing_id", table_name="jp_tenant_applications")
        op.drop_table("jp_tenant_applications")
