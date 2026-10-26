"""extend users table for delegation domain

Revision ID: 0027_extend_users_for_delegation
Revises: 0026_create_bank_account_reveal_logs
Create Date: 2026-06-29

Phase 01 — Owner-Operator Delegation data model.

AC coverage:
  - AC-56: is_operator_capable flag (host who also operates for others)
  - AC-64: sole_ownership_attested_at (user-level self-declaration)

Note on is_operator_capable vs role:
  - role = primary login persona {'guest','host','admin','operator'}
  - is_operator_capable = can accept delegation invites (explicit gating)
  - Both can be True for a host who also operates for other owners (AC-56)
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0027_extend_users_for_delegation"
down_revision = "0026_create_bank_account_reveal_logs"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("users", schema=None) as batch_op:
        # Can accept delegation invites (may be True even if role='host' — AC-56)
        batch_op.add_column(
            sa.Column(
                "is_operator_capable",
                sa.Boolean,
                nullable=False,
                server_default=sa.false(),
            )
        )
        # AC-64: sole ownership attestation (user-level — applies to all properties)
        batch_op.add_column(
            sa.Column("sole_ownership_attested_at", sa.DateTime, nullable=True)
        )
        # 1:1 backref to operator_business_profiles (NULL for cá nhân operators).
        # FK added as separate ALTER to avoid unnamed constraint error in batch mode.
        batch_op.add_column(
            sa.Column(
                "business_operator_profile_id",
                sa.Integer,
                nullable=True,
            )
        )
    # Add FK constraint separately with explicit name (required for SQLite batch mode)
    conn = op.get_bind()
    if conn.dialect.name == "postgresql":
        op.create_foreign_key(
            "fk_users_business_operator_profile_id",
            "users",
            "operator_business_profiles",
            ["business_operator_profile_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    conn = op.get_bind()
    if conn.dialect.name == "postgresql":
        op.drop_constraint(
            "fk_users_business_operator_profile_id", "users", type_="foreignkey"
        )
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("business_operator_profile_id")
        batch_op.drop_column("sole_ownership_attested_at")
        batch_op.drop_column("is_operator_capable")
