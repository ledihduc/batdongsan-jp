"""nha_tro_ops

Create service_fees, contract_service_fees, meter_readings, invoices,
invoice_line_items, payments, credit_notes tables.

Revision ID: 0006_nha_tro_ops
Revises: 0005_nha_tro_core
Create Date: 2026-06-28
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0006_nha_tro_ops"
down_revision: Union[str, Sequence[str], None] = "0005_nha_tro_core"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── service_fees ───────────────────────────────────────────────────────────
    op.create_table(
        "service_fees",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("building_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("unit_price", sa.Float(), nullable=False, server_default="0"),
        sa.Column("billing_cycle", sa.String(length=20), nullable=False, server_default="monthly"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "billing_cycle IN ('monthly', 'one_time')",
            name="ck_service_fees_billing_cycle",
        ),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["building_id"], ["buildings.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_service_fees_host_id"), "service_fees", ["host_id"], unique=False)
    op.create_index(op.f("ix_service_fees_building_id"), "service_fees", ["building_id"], unique=False)

    # ── contract_service_fees (M:N pivot) ──────────────────────────────────────
    op.create_table(
        "contract_service_fees",
        sa.Column("contract_id", sa.Integer(), nullable=False),
        sa.Column("service_fee_id", sa.Integer(), nullable=False),
        sa.Column("monthly_amount", sa.Float(), nullable=False, server_default="0"),
        sa.ForeignKeyConstraint(["contract_id"], ["contracts.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["service_fee_id"], ["service_fees.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("contract_id", "service_fee_id"),
    )

    # ── meter_readings ─────────────────────────────────────────────────────────
    op.create_table(
        "meter_readings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("room_id", sa.Integer(), nullable=False),
        sa.Column("reading_date", sa.String(length=20), nullable=False),
        sa.Column("electricity_kwh", sa.Float(), nullable=False, server_default="0"),
        sa.Column("water_m3", sa.Float(), nullable=False, server_default="0"),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["room_id"], ["rooms.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_meter_readings_host_id"), "meter_readings", ["host_id"], unique=False)
    op.create_index(op.f("ix_meter_readings_room_id"), "meter_readings", ["room_id"], unique=False)
    op.create_index(op.f("ix_meter_readings_reading_date"), "meter_readings", ["reading_date"], unique=False)

    # ── invoices ───────────────────────────────────────────────────────────────
    op.create_table(
        "invoices",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("contract_id", sa.Integer(), nullable=False),
        sa.Column("invoice_number", sa.String(length=50), nullable=False),
        sa.Column("period_start", sa.String(length=20), nullable=False),
        sa.Column("period_end", sa.String(length=20), nullable=False),
        sa.Column("issued_date", sa.String(length=20), nullable=False),
        sa.Column("due_date", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="draft"),
        sa.Column("total_amount", sa.Float(), nullable=False, server_default="0"),
        sa.Column("paid_amount", sa.Float(), nullable=False, server_default="0"),
        sa.Column("paid_at", sa.DateTime(), nullable=True),
        sa.Column("public_token", sa.String(length=36), nullable=True),
        sa.Column("public_token_expires_at", sa.DateTime(), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "status IN ('draft', 'sent', 'paid', 'overdue', 'cancelled')",
            name="ck_invoices_status",
        ),
        sa.UniqueConstraint(
            "contract_id", "period_start", "period_end",
            name="uq_invoices_contract_period",
        ),
        sa.UniqueConstraint("invoice_number", name="uq_invoices_invoice_number"),
        sa.UniqueConstraint("public_token", name="uq_invoices_public_token"),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["contract_id"], ["contracts.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_invoices_host_id"), "invoices", ["host_id"], unique=False)
    op.create_index(op.f("ix_invoices_contract_id"), "invoices", ["contract_id"], unique=False)
    op.create_index(op.f("ix_invoices_status"), "invoices", ["status"], unique=False)
    op.create_index(op.f("ix_invoices_public_token"), "invoices", ["public_token"], unique=False)
    op.create_index(op.f("ix_invoices_invoice_number"), "invoices", ["invoice_number"], unique=False)

    # ── invoice_line_items ─────────────────────────────────────────────────────
    op.create_table(
        "invoice_line_items",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("invoice_id", sa.Integer(), nullable=False),
        sa.Column("category", sa.String(length=30), nullable=False),
        sa.Column("description", sa.String(length=300), nullable=False, server_default=""),
        sa.Column("quantity", sa.Float(), nullable=False, server_default="1"),
        sa.Column("unit_price", sa.Float(), nullable=False, server_default="0"),
        sa.Column("amount", sa.Float(), nullable=False, server_default="0"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.CheckConstraint(
            "category IN ('rent','electricity','water','service','deposit_refund','damage_deduction','adjustment')",
            name="ck_invoice_line_items_category",
        ),
        sa.ForeignKeyConstraint(["invoice_id"], ["invoices.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_invoice_line_items_invoice_id"), "invoice_line_items", ["invoice_id"], unique=False)

    # ── payments ───────────────────────────────────────────────────────────────
    op.create_table(
        "payments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("invoice_id", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("method", sa.String(length=20), nullable=False, server_default="cash"),
        sa.Column("paid_at", sa.DateTime(), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "method IN ('cash','bank_transfer','other')",
            name="ck_payments_method",
        ),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["invoice_id"], ["invoices.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_payments_host_id"), "payments", ["host_id"], unique=False)
    op.create_index(op.f("ix_payments_invoice_id"), "payments", ["invoice_id"], unique=False)

    # ── credit_notes ───────────────────────────────────────────────────────────
    op.create_table(
        "credit_notes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("host_id", sa.Integer(), nullable=False),
        sa.Column("original_invoice_id", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False, server_default=""),
        sa.Column("issued_date", sa.String(length=20), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["host_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["original_invoice_id"], ["invoices.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_credit_notes_host_id"), "credit_notes", ["host_id"], unique=False)
    op.create_index(op.f("ix_credit_notes_original_invoice_id"), "credit_notes", ["original_invoice_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_credit_notes_original_invoice_id"), table_name="credit_notes")
    op.drop_index(op.f("ix_credit_notes_host_id"), table_name="credit_notes")
    op.drop_table("credit_notes")

    op.drop_index(op.f("ix_payments_invoice_id"), table_name="payments")
    op.drop_index(op.f("ix_payments_host_id"), table_name="payments")
    op.drop_table("payments")

    op.drop_index(op.f("ix_invoice_line_items_invoice_id"), table_name="invoice_line_items")
    op.drop_table("invoice_line_items")

    op.drop_index(op.f("ix_invoices_invoice_number"), table_name="invoices")
    op.drop_index(op.f("ix_invoices_public_token"), table_name="invoices")
    op.drop_index(op.f("ix_invoices_status"), table_name="invoices")
    op.drop_index(op.f("ix_invoices_contract_id"), table_name="invoices")
    op.drop_index(op.f("ix_invoices_host_id"), table_name="invoices")
    op.drop_table("invoices")

    op.drop_index(op.f("ix_meter_readings_reading_date"), table_name="meter_readings")
    op.drop_index(op.f("ix_meter_readings_room_id"), table_name="meter_readings")
    op.drop_index(op.f("ix_meter_readings_host_id"), table_name="meter_readings")
    op.drop_table("meter_readings")

    op.drop_table("contract_service_fees")

    op.drop_index(op.f("ix_service_fees_building_id"), table_name="service_fees")
    op.drop_index(op.f("ix_service_fees_host_id"), table_name="service_fees")
    op.drop_table("service_fees")
