"""marketplace_integration

Phase 08 — adds columns to houses, rooms, tenants, contracts to support 1-way
ops→marketplace sync and marketplace booking → draft Contract/Reservation.

Revision ID: 0010_marketplace_integration
Revises: 0009_homestay_core
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0010_marketplace_integration"
down_revision: Union[str, Sequence[str], None] = "0009_homestay_core"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── houses ───────────────────────────────────────────────────────────────
    op.add_column(
        "houses",
        sa.Column(
            "product_type",
            sa.String(length=20),
            nullable=False,
            server_default="apartment",
        ),
    )
    op.add_column(
        "houses",
        sa.Column("source_room_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "houses",
        sa.Column("last_synced_at", sa.DateTime(), nullable=True),
    )
    op.create_index(
        "ix_houses_product_type", "houses", ["product_type"]
    )
    op.create_unique_constraint(
        "uq_houses_source_room_id", "houses", ["source_room_id"]
    )
    op.create_foreign_key(
        "fk_houses_source_room_id_rooms",
        "houses",
        "rooms",
        ["source_room_id"],
        ["id"],
        ondelete="SET NULL",
    )

    # ── rooms ────────────────────────────────────────────────────────────────
    op.add_column(
        "rooms",
        sa.Column(
            "is_listed_on_marketplace",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "rooms",
        sa.Column("marketplace_house_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "rooms",
        sa.Column(
            "is_homestay",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.create_index(
        "ix_rooms_is_listed_on_marketplace",
        "rooms",
        ["is_listed_on_marketplace"],
    )
    op.create_index("ix_rooms_is_homestay", "rooms", ["is_homestay"])
    op.create_foreign_key(
        "fk_rooms_marketplace_house_id_houses",
        "rooms",
        "houses",
        ["marketplace_house_id"],
        ["id"],
        ondelete="SET NULL",
    )

    # ── tenants ──────────────────────────────────────────────────────────────
    op.add_column(
        "tenants",
        sa.Column(
            "is_placeholder",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "tenants",
        sa.Column(
            "created_from_booking_type", sa.String(length=30), nullable=True
        ),
    )
    op.add_column(
        "tenants",
        sa.Column("created_from_booking_id", sa.Integer(), nullable=True),
    )
    op.create_index(
        "ix_tenants_is_placeholder", "tenants", ["is_placeholder"]
    )

    # ── contracts ────────────────────────────────────────────────────────────
    op.add_column(
        "contracts",
        sa.Column(
            "source",
            sa.String(length=20),
            nullable=False,
            server_default="manual",
        ),
    )
    op.create_index("ix_contracts_source", "contracts", ["source"])


def downgrade() -> None:
    # contracts
    op.drop_index("ix_contracts_source", table_name="contracts")
    op.drop_column("contracts", "source")
    # tenants
    op.drop_index("ix_tenants_is_placeholder", table_name="tenants")
    op.drop_column("tenants", "created_from_booking_id")
    op.drop_column("tenants", "created_from_booking_type")
    op.drop_column("tenants", "is_placeholder")
    # rooms
    op.drop_constraint(
        "fk_rooms_marketplace_house_id_houses", "rooms", type_="foreignkey"
    )
    op.drop_index("ix_rooms_is_homestay", table_name="rooms")
    op.drop_index(
        "ix_rooms_is_listed_on_marketplace", table_name="rooms"
    )
    op.drop_column("rooms", "is_homestay")
    op.drop_column("rooms", "marketplace_house_id")
    op.drop_column("rooms", "is_listed_on_marketplace")
    # houses
    op.drop_constraint(
        "fk_houses_source_room_id_rooms", "houses", type_="foreignkey"
    )
    op.drop_constraint(
        "uq_houses_source_room_id", "houses", type_="unique"
    )
    op.drop_index("ix_houses_product_type", table_name="houses")
    op.drop_column("houses", "last_synced_at")
    op.drop_column("houses", "source_room_id")
    op.drop_column("houses", "product_type")
