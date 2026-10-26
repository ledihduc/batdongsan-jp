"""listing_v2

Thêm cột cho Release 1 (F1–F4):
- transaction_type  VARCHAR(10) NOT NULL DEFAULT 'rent' + index
- is_trusted        BOOLEAN NOT NULL DEFAULT FALSE + index
- trusted_at        TIMESTAMP NULL
- trusted_by_admin_id  INTEGER NULL FK→users.id ON DELETE SET NULL + index
- ward_slug         VARCHAR(80) NULL + index
- ward_slug_legacy  VARCHAR(80) NULL + index

Composite index ix_houses_tx_status_trusted (transaction_type, status, is_trusted).

Data migration: UPDATE houses SET status='published' WHERE status='approved'.

Dialect-guard: FK và DEFAULT boolean đặc thù Postgres. SQLite dev: bỏ FK, dùng
server_default int-string '0' cho boolean (SQLite lưu INTEGER).

Revision ID: 0039_listing_v2
Revises: 0038_houses_rejection_reason
Create Date: 2026-07-02
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0039_listing_v2"
down_revision: Union[str, Sequence[str], None] = "0038_houses_rejection_reason"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    dialect = connection.dialect.name

    # ── transaction_type ─────────────────────────────────────────────────────
    op.add_column(
        "houses",
        sa.Column(
            "transaction_type",
            sa.String(length=10),
            nullable=False,
            server_default="rent",
        ),
    )
    op.create_index("ix_houses_transaction_type", "houses", ["transaction_type"])

    # ── is_trusted ───────────────────────────────────────────────────────────
    # SQLite stores booleans as INTEGER; server_default must be '0'/'1'.
    # Postgres accepts 'false'/'true'. Use '0' universally (valid for both).
    op.add_column(
        "houses",
        sa.Column(
            "is_trusted",
            sa.Boolean(),
            nullable=False,
            server_default="0",
        ),
    )
    op.create_index("ix_houses_is_trusted", "houses", ["is_trusted"])

    # ── trusted_at ───────────────────────────────────────────────────────────
    op.add_column("houses", sa.Column("trusted_at", sa.DateTime(), nullable=True))

    # ── trusted_by_admin_id ──────────────────────────────────────────────────
    if dialect == "postgresql":
        op.add_column(
            "houses",
            sa.Column(
                "trusted_by_admin_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )
    else:
        # SQLite: column without FK constraint (FK enforcement off by default)
        op.add_column(
            "houses",
            sa.Column("trusted_by_admin_id", sa.Integer(), nullable=True),
        )
    op.create_index("ix_houses_trusted_by_admin_id", "houses", ["trusted_by_admin_id"])

    # ── ward_slug ────────────────────────────────────────────────────────────
    op.add_column("houses", sa.Column("ward_slug", sa.String(length=80), nullable=True))
    op.create_index("ix_houses_ward_slug", "houses", ["ward_slug"])

    # ── ward_slug_legacy ─────────────────────────────────────────────────────
    op.add_column(
        "houses", sa.Column("ward_slug_legacy", sa.String(length=80), nullable=True)
    )
    op.create_index("ix_houses_ward_slug_legacy", "houses", ["ward_slug_legacy"])

    # ── Composite index for guest home tab queries ────────────────────────────
    op.create_index(
        "ix_houses_tx_status_trusted",
        "houses",
        ["transaction_type", "status", "is_trusted"],
    )

    # ── Data migration: approved → published ─────────────────────────────────
    op.execute("UPDATE houses SET status='published' WHERE status='approved'")


def downgrade() -> None:
    # Revert data migration first
    op.execute("UPDATE houses SET status='approved' WHERE status='published'")

    # Drop composite index
    op.drop_index("ix_houses_tx_status_trusted", table_name="houses")

    # Drop column indices + columns (reverse order)
    op.drop_index("ix_houses_ward_slug_legacy", table_name="houses")
    op.drop_column("houses", "ward_slug_legacy")

    op.drop_index("ix_houses_ward_slug", table_name="houses")
    op.drop_column("houses", "ward_slug")

    op.drop_index("ix_houses_trusted_by_admin_id", table_name="houses")
    op.drop_column("houses", "trusted_by_admin_id")

    op.drop_column("houses", "trusted_at")

    op.drop_index("ix_houses_is_trusted", table_name="houses")
    op.drop_column("houses", "is_trusted")

    op.drop_index("ix_houses_transaction_type", table_name="houses")
    op.drop_column("houses", "transaction_type")
