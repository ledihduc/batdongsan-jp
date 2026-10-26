"""nha_tro_core

Create buildings, rooms, tenants, contracts, contract_tenants tables.

Revision ID: 0005_nha_tro_core
Revises: 0004_add_host_profile_audit_log
Create Date: 2026-06-22
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "0005_nha_tro_core"
down_revision: Union[str, Sequence[str], None] = "0004_add_host_profile_audit_log"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── buildings ──────────────────────────────────────────────────────────────
    op.create_table(
        "buildings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=300), nullable=False),
        sa.Column("address", sa.String(length=500), nullable=False, server_default=""),
        sa.Column("city", sa.String(length=100), nullable=False, server_default=""),
        sa.Column("district", sa.String(length=100), nullable=False, server_default=""),
        sa.Column("ward", sa.String(length=100), nullable=False, server_default=""),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_buildings_host_id"), "buildings", ["host_id"], unique=False)

    # ── rooms ──────────────────────────────────────────────────────────────────
    op.create_table(
        "rooms",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("building_id", sa.Integer(), nullable=False),
        sa.Column("code", sa.String(length=50), nullable=False),
        sa.Column("area_m2", sa.Float(), nullable=True),
        sa.Column("capacity", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("base_price", sa.Float(), nullable=False, server_default="0"),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="vacant",
        ),
        sa.Column("maintenance_start", sa.String(length=20), nullable=True),
        sa.Column("maintenance_end", sa.String(length=20), nullable=True),
        sa.Column("images", sa.Text(), nullable=True, server_default="[]"),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "status IN ('vacant', 'occupied', 'maintenance')",
            name="ck_rooms_status",
        ),
        sa.ForeignKeyConstraint(["building_id"], ["buildings.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_rooms_building_id"), "rooms", ["building_id"], unique=False)
    op.create_index(op.f("ix_rooms_status"), "rooms", ["status"], unique=False)

    # ── tenants ────────────────────────────────────────────────────────────────
    op.create_table(
        "tenants",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("full_name", sa.String(length=300), nullable=False),
        sa.Column("cccd_number_hash", sa.String(length=200), nullable=True),
        sa.Column("phone", sa.String(length=50), nullable=False, server_default=""),
        sa.Column("email", sa.String(length=200), nullable=True),
        sa.Column("birthday", sa.String(length=20), nullable=True),
        sa.Column("address_origin", sa.String(length=500), nullable=True),
        sa.Column("cccd_front_path", sa.String(length=500), nullable=True),
        sa.Column("cccd_back_path", sa.String(length=500), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_tenants_host_id"), "tenants", ["host_id"], unique=False)

    # ── contracts ──────────────────────────────────────────────────────────────
    op.create_table(
        "contracts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("start_date", sa.String(length=20), nullable=False),
        sa.Column("end_date", sa.String(length=20), nullable=False),
        sa.Column("monthly_rent", sa.Float(), nullable=False),
        sa.Column("deposit", sa.Float(), nullable=False, server_default="0"),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="draft",
        ),
        sa.Column("terminated_at", sa.String(length=20), nullable=True),
        sa.Column("actual_end_date", sa.String(length=20), nullable=True),
        sa.Column("deposit_refund_amount", sa.Float(), nullable=True),
        sa.Column("damage_note", sa.Text(), nullable=True),
        sa.Column("damage_photos", sa.Text(), nullable=True, server_default="[]"),
        sa.Column("handover_photos", sa.Text(), nullable=True, server_default="[]"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "status IN ('draft', 'active', 'expired', 'terminated')",
            name="ck_contracts_status",
        ),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_contracts_host_id"), "contracts", ["host_id"], unique=False)
    op.create_index(op.f("ix_contracts_room_id"), "contracts", ["room_id"], unique=False)
    op.create_index(op.f("ix_contracts_status"), "contracts", ["status"], unique=False)
    op.create_index(op.f("ix_contracts_end_date"), "contracts", ["end_date"], unique=False)

    # ── contract_tenants (M:N pivot) ───────────────────────────────────────────
    op.create_table(
        "contract_tenants",
        sa.Column("contract_id", sa.Integer(), nullable=False),
        sa.Column("tenant_id", sa.Integer(), nullable=False),
        sa.Column("is_primary", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("joined_at", sa.String(length=20), nullable=True),
        sa.Column("left_at", sa.String(length=20), nullable=True),
        sa.ForeignKeyConstraint(
            ["contract_id"], ["contracts.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["tenant_id"], ["tenants.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("contract_id", "tenant_id"),
    )
    op.create_index(
        "ix_contract_tenants_contract_id", "contract_tenants", ["contract_id"], unique=False
    )
    op.create_index(
        "ix_contract_tenants_tenant_id", "contract_tenants", ["tenant_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_contract_tenants_tenant_id", table_name="contract_tenants")
    op.drop_index("ix_contract_tenants_contract_id", table_name="contract_tenants")
    op.drop_table("contract_tenants")

    op.drop_index(op.f("ix_contracts_end_date"), table_name="contracts")
    op.drop_index(op.f("ix_contracts_status"), table_name="contracts")
    op.drop_index(op.f("ix_contracts_room_id"), table_name="contracts")
    op.drop_index(op.f("ix_contracts_host_id"), table_name="contracts")
    op.drop_table("contracts")

    op.drop_index(op.f("ix_tenants_host_id"), table_name="tenants")
    op.drop_table("tenants")

    op.drop_index(op.f("ix_rooms_status"), table_name="rooms")
    op.drop_index(op.f("ix_rooms_building_id"), table_name="rooms")
    op.drop_table("rooms")

    op.drop_index(op.f("ix_buildings_host_id"), table_name="buildings")
    op.drop_table("buildings")
