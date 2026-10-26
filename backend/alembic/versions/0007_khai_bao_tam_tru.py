"""khai_bao_tam_tru

Create khai_bao_tam_tru table — VN-specific residence declaration record per
tenant per stay (Contract → Phase 05; Reservation → Phase 07).

Revision ID: 0007_khai_bao_tam_tru
Revises: 0006_nha_tro_ops
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0007_khai_bao_tam_tru"
down_revision: Union[str, Sequence[str], None] = "0006_nha_tro_ops"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "khai_bao_tam_tru",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("tenant_id", sa.Integer(), nullable=False),
        sa.Column("contract_id", sa.Integer(), nullable=True),
        # reservation_id reserved for Phase 07 — no FK yet (reservations table not exist)
        sa.Column("reservation_id", sa.Integer(), nullable=True),
        sa.Column("check_in_at", sa.DateTime(), nullable=False),
        sa.Column("declared_at", sa.DateTime(), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
        sa.Column("skip_reason", sa.Text(), nullable=True),
        sa.Column("public_token", sa.String(length=36), nullable=False),
        sa.Column("public_token_expires_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "status IN ('pending', 'declared', 'overdue', 'skipped')",
            name="ck_khai_bao_status",
        ),
        sa.UniqueConstraint(
            "contract_id", "tenant_id",
            name="uq_khai_bao_contract_tenant",
        ),
        sa.UniqueConstraint("public_token", name="uq_khai_bao_public_token"),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["contract_id"], ["contracts.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_khai_bao_tam_tru_host_id"), "khai_bao_tam_tru", ["host_id"], unique=False)
    op.create_index(op.f("ix_khai_bao_tam_tru_tenant_id"), "khai_bao_tam_tru", ["tenant_id"], unique=False)
    op.create_index(op.f("ix_khai_bao_tam_tru_contract_id"), "khai_bao_tam_tru", ["contract_id"], unique=False)
    op.create_index(op.f("ix_khai_bao_tam_tru_reservation_id"), "khai_bao_tam_tru", ["reservation_id"], unique=False)
    op.create_index(op.f("ix_khai_bao_tam_tru_status"), "khai_bao_tam_tru", ["status"], unique=False)
    op.create_index(op.f("ix_khai_bao_tam_tru_public_token"), "khai_bao_tam_tru", ["public_token"], unique=False)
    op.create_index("ix_khai_bao_host_status", "khai_bao_tam_tru", ["host_id", "status"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_khai_bao_host_status", table_name="khai_bao_tam_tru")
    op.drop_index(op.f("ix_khai_bao_tam_tru_public_token"), table_name="khai_bao_tam_tru")
    op.drop_index(op.f("ix_khai_bao_tam_tru_status"), table_name="khai_bao_tam_tru")
    op.drop_index(op.f("ix_khai_bao_tam_tru_reservation_id"), table_name="khai_bao_tam_tru")
    op.drop_index(op.f("ix_khai_bao_tam_tru_contract_id"), table_name="khai_bao_tam_tru")
    op.drop_index(op.f("ix_khai_bao_tam_tru_tenant_id"), table_name="khai_bao_tam_tru")
    op.drop_index(op.f("ix_khai_bao_tam_tru_host_id"), table_name="khai_bao_tam_tru")
    op.drop_table("khai_bao_tam_tru")
