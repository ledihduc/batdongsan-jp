"""create tt200_exports table

Revision ID: 0020_create_tt200_exports
Revises: 0019_create_audit_logs
Create Date: 2026-06-28

Phase 09 — versioned export records for TT200 immutability guarantee.
Each export attempt writes one row; re-exporting same period increments version.
"""

from alembic import op
import sqlalchemy as sa

revision = "0020_create_tt200_exports"
down_revision = "0019_create_audit_logs"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "tt200_exports",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column(
            "host_id",
            sa.Integer,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        # period: "YYYY-MM"
        sa.Column("period", sa.String(7), nullable=False),
        sa.Column("version", sa.Integer, nullable=False),
        # sha256 hex digest of the exported file bytes (64 chars)
        sa.Column("sha256", sa.String(64), nullable=False),
        sa.Column(
            "exported_at",
            sa.DateTime,
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("ip", sa.String(45), nullable=True),
        sa.Column("user_agent", sa.String(500), nullable=True),
    )
    # UNIQUE: one version per (host, period) combination
    op.create_unique_constraint(
        "uq_tt200_exports_host_period_version",
        "tt200_exports",
        ["host_id", "period", "version"],
    )
    # Index for max-version lookup: ORDER BY version DESC
    op.create_index(
        "ix_tt200_exports_host_period_version",
        "tt200_exports",
        ["host_id", "period", "version"],
    )


def downgrade():
    op.drop_index("ix_tt200_exports_host_period_version", table_name="tt200_exports")
    op.drop_constraint(
        "uq_tt200_exports_host_period_version", "tt200_exports", type_="unique"
    )
    op.drop_table("tt200_exports")
