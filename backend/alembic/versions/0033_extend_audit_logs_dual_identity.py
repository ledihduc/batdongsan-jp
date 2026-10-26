"""extend audit_logs with dual-identity delegation columns

Revision ID: 0033_extend_audit_logs_dual_identity
Revises: 0032_extend_change_logs_dual_identity
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-22: actor_user_id (explicit actor, separate from host_id = owner)
  - AC-23: on_behalf_of_user_id (owner when actor is an operator)
  - AC-32: acted_via_delegation_id (delegation that authorized the action)
  - AC-44: retention_tier 4-tier lifecycle

NFR-03: composite index on (acted_via_delegation_id, created_at) for audit queries.
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0033_extend_audit_logs_dual_identity"
down_revision = "0032_extend_change_logs_dual_identity"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("audit_logs", schema=None) as batch_op:
        # Explicit actor (FK added separately for SQLite batch mode compat)
        batch_op.add_column(
            sa.Column("actor_user_id", sa.Integer, nullable=True)
        )
        # Owner when actor is an operator (FK added separately)
        batch_op.add_column(
            sa.Column("on_behalf_of_user_id", sa.Integer, nullable=True)
        )
        # Delegation that authorized this action (FK added separately)
        batch_op.add_column(
            sa.Column("acted_via_delegation_id", sa.String(36), nullable=True)
        )
        # AC-44: 4-tier retention (hot | warm | cold | legal_hold)
        batch_op.add_column(
            sa.Column(
                "retention_tier",
                sa.String(10),
                nullable=False,
                server_default="hot",
            )
        )

    # Add FK constraints with explicit names (required for SQLite batch mode)
    conn = op.get_bind()
    if conn.dialect.name == "postgresql":
        op.create_foreign_key(
            "fk_audit_logs_actor_user_id",
            "audit_logs", "users",
            ["actor_user_id"], ["id"],
            ondelete="SET NULL",
        )
        op.create_foreign_key(
            "fk_audit_logs_on_behalf_of_user_id",
            "audit_logs", "users",
            ["on_behalf_of_user_id"], ["id"],
            ondelete="SET NULL",
        )
        op.create_foreign_key(
            "fk_audit_logs_acted_via_delegation_id",
            "audit_logs", "delegations",
            ["acted_via_delegation_id"], ["id"],
            ondelete="SET NULL",
        )

    # NFR-03: composite index for delegation audit range queries
    op.create_index(
        "ix_audit_logs_delegation_created",
        "audit_logs",
        ["acted_via_delegation_id", "created_at"],
    )
    op.create_index(
        "ix_audit_logs_actor_user_id", "audit_logs", ["actor_user_id"]
    )
    op.create_index(
        "ix_audit_logs_on_behalf_of", "audit_logs", ["on_behalf_of_user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_audit_logs_on_behalf_of", table_name="audit_logs")
    op.drop_index("ix_audit_logs_actor_user_id", table_name="audit_logs")
    op.drop_index("ix_audit_logs_delegation_created", table_name="audit_logs")

    conn = op.get_bind()
    if conn.dialect.name == "postgresql":
        op.drop_constraint("fk_audit_logs_acted_via_delegation_id", "audit_logs", type_="foreignkey")
        op.drop_constraint("fk_audit_logs_on_behalf_of_user_id", "audit_logs", type_="foreignkey")
        op.drop_constraint("fk_audit_logs_actor_user_id", "audit_logs", type_="foreignkey")

    with op.batch_alter_table("audit_logs", schema=None) as batch_op:
        batch_op.drop_column("retention_tier")
        batch_op.drop_column("acted_via_delegation_id")
        batch_op.drop_column("on_behalf_of_user_id")
        batch_op.drop_column("actor_user_id")
