"""extend change_logs with dual-identity delegation columns

Revision ID: 0032_extend_change_logs_dual_identity
Revises: 0031_add_contract_tenants_joined_datetime
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-23: on_behalf_of_user_id (owner when actor was an operator)
  - AC-32: acted_via_delegation_id (which delegation authorized the action)
  - AC-44: retention_tier 4-tier lifecycle (hot | warm | cold | legal_hold)
  - AC-62: acted_at client-claim timestamp (NULL for server-side actions)

NFR-03: composite index on (on_behalf_of_user_id, created_at) for p95 < 1s audit queries.
scope_snapshot_json stores scope at action time — so later revocation or scope change
does not invalidate historical audit queries.
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0032_extend_change_logs_dual_identity"
down_revision = "0031_add_contract_tenants_joined_datetime"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("change_logs", schema=None) as batch_op:
        # AC-23/32: owner id when actor was an operator (FK added separately below for SQLite compat)
        batch_op.add_column(
            sa.Column("on_behalf_of_user_id", sa.Integer, nullable=True)
        )
        # Which delegation authorized this action (FK added separately for SQLite compat)
        batch_op.add_column(
            sa.Column("acted_via_delegation_id", sa.String(36), nullable=True)
        )
        # AC-62: client-claim timestamp (NULL → use created_at server-stamp)
        batch_op.add_column(
            sa.Column("acted_at", sa.DateTime, nullable=True)
        )
        # AC-44: 4-tier retention (hot | warm | cold | legal_hold); default='hot'
        batch_op.add_column(
            sa.Column(
                "retention_tier",
                sa.String(10),
                nullable=False,
                server_default="hot",
            )
        )
        # Scope snapshot at action time (prevents historical query breakage on scope change)
        batch_op.add_column(
            sa.Column("scope_snapshot_json", sa.JSON, nullable=True)
        )

    # Add FK constraints with explicit names (SQLite batch mode requires named constraints)
    conn = op.get_bind()
    if conn.dialect.name == "postgresql":
        op.create_foreign_key(
            "fk_change_logs_on_behalf_of_user_id",
            "change_logs", "users",
            ["on_behalf_of_user_id"], ["id"],
            ondelete="SET NULL",
        )
        op.create_foreign_key(
            "fk_change_logs_acted_via_delegation_id",
            "change_logs", "delegations",
            ["acted_via_delegation_id"], ["id"],
            ondelete="SET NULL",
        )

    # NFR-03: composite index for on_behalf_of audit range queries
    op.create_index(
        "ix_change_logs_on_behalf_created",
        "change_logs",
        ["on_behalf_of_user_id", "created_at"],
    )
    op.create_index(
        "ix_change_logs_acted_via_delegation",
        "change_logs",
        ["acted_via_delegation_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_change_logs_acted_via_delegation", table_name="change_logs")
    op.drop_index("ix_change_logs_on_behalf_created", table_name="change_logs")

    conn = op.get_bind()
    if conn.dialect.name == "postgresql":
        op.drop_constraint("fk_change_logs_acted_via_delegation_id", "change_logs", type_="foreignkey")
        op.drop_constraint("fk_change_logs_on_behalf_of_user_id", "change_logs", type_="foreignkey")

    with op.batch_alter_table("change_logs", schema=None) as batch_op:
        batch_op.drop_column("scope_snapshot_json")
        batch_op.drop_column("retention_tier")
        batch_op.drop_column("acted_at")
        batch_op.drop_column("acted_via_delegation_id")
        batch_op.drop_column("on_behalf_of_user_id")
