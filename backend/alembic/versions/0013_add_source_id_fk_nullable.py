"""add_source_id_fk_nullable

Phase 04 analytics — thêm cột source_id (nullable FK → revenue_sources.id) vào
bảng reservations và contracts.

Cột được tạo nullable để đảm bảo zero-downtime và cho phép rollback an toàn
trước khi data migration (0014) chạy.

FK strategy: ondelete=SET NULL — xóa một nguồn thu không xóa reservation/contract,
chỉ đặt source_id về NULL (hosts quản lý nguồn của họ, không ảnh hưởng lịch sử).

SQLite note: SQLite không hỗ trợ ADD FOREIGN KEY via ALTER TABLE trực tiếp;
dùng batch_alter_table để Alembic thực hiện copy-and-move strategy.
Trên Postgres: dùng op.add_column + op.create_foreign_key trực tiếp.

Revision ID: 0013_add_source_id_fk_nullable
Revises: 0012_create_revenue_sources
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0013_add_source_id_fk_nullable"
down_revision: Union[str, Sequence[str], None] = "0012_create_revenue_sources"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    dialect = connection.dialect.name

    if dialect == "sqlite":
        # SQLite: batch mode để add column + FK cùng lúc (copy-and-move)
        with op.batch_alter_table("reservations") as batch_op:
            batch_op.add_column(sa.Column("source_id", sa.Integer(), nullable=True))
            batch_op.create_foreign_key(
                "fk_reservations_source_id_revenue_sources",
                "revenue_sources",
                ["source_id"],
                ["id"],
                ondelete="SET NULL",
            )
        op.create_index("ix_reservations_source_id", "reservations", ["source_id"])

        with op.batch_alter_table("contracts") as batch_op:
            batch_op.add_column(sa.Column("source_id", sa.Integer(), nullable=True))
            batch_op.create_foreign_key(
                "fk_contracts_source_id_revenue_sources",
                "revenue_sources",
                ["source_id"],
                ["id"],
                ondelete="SET NULL",
            )
        op.create_index("ix_contracts_source_id", "contracts", ["source_id"])
    else:
        # Postgres: ALTER TABLE hỗ trợ đầy đủ
        op.add_column(
            "reservations",
            sa.Column("source_id", sa.Integer(), nullable=True),
        )
        op.create_foreign_key(
            "fk_reservations_source_id_revenue_sources",
            "reservations",
            "revenue_sources",
            ["source_id"],
            ["id"],
            ondelete="SET NULL",
        )
        op.create_index("ix_reservations_source_id", "reservations", ["source_id"])

        op.add_column(
            "contracts",
            sa.Column("source_id", sa.Integer(), nullable=True),
        )
        op.create_foreign_key(
            "fk_contracts_source_id_revenue_sources",
            "contracts",
            "revenue_sources",
            ["source_id"],
            ["id"],
            ondelete="SET NULL",
        )
        op.create_index("ix_contracts_source_id", "contracts", ["source_id"])


def downgrade() -> None:
    connection = op.get_bind()
    dialect = connection.dialect.name

    if dialect == "sqlite":
        op.drop_index("ix_contracts_source_id", table_name="contracts")
        with op.batch_alter_table("contracts") as batch_op:
            batch_op.drop_constraint(
                "fk_contracts_source_id_revenue_sources", type_="foreignkey"
            )
            batch_op.drop_column("source_id")

        op.drop_index("ix_reservations_source_id", table_name="reservations")
        with op.batch_alter_table("reservations") as batch_op:
            batch_op.drop_constraint(
                "fk_reservations_source_id_revenue_sources", type_="foreignkey"
            )
            batch_op.drop_column("source_id")
    else:
        op.drop_index("ix_contracts_source_id", table_name="contracts")
        op.drop_constraint(
            "fk_contracts_source_id_revenue_sources", "contracts", type_="foreignkey"
        )
        op.drop_column("contracts", "source_id")

        op.drop_index("ix_reservations_source_id", table_name="reservations")
        op.drop_constraint(
            "fk_reservations_source_id_revenue_sources", "reservations", type_="foreignkey"
        )
        op.drop_column("reservations", "source_id")
