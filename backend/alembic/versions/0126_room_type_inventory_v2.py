"""P10 RoomType-first short-stay inventory.

Revision ID: 0126_room_type_inventory_v2
Revises: 0125_money_ledger_v2
"""
import sqlalchemy as sa
from alembic import op

revision = "0126_room_type_inventory_v2"
down_revision = "0125_money_ledger_v2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table("short_stay_rate_plans", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("room_type_id", sa.Integer(), sa.ForeignKey("loai_phong.id", ondelete="CASCADE"), nullable=False), sa.Column("code", sa.String(40), nullable=False), sa.Column("name", sa.String(120), nullable=False), sa.Column("nightly_price", sa.Float(), nullable=False), sa.Column("min_nights", sa.Integer(), nullable=False, server_default="1"), sa.Column("cancellation_policy", sa.JSON(), nullable=False, server_default="{}"), sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()), sa.Column("created_at", sa.DateTime(), nullable=False), sa.Column("updated_at", sa.DateTime(), nullable=False), sa.UniqueConstraint("room_type_id", "code", name="uq_short_rate_plan_code"))
    op.create_index("ix_short_stay_rate_plans_room_type_id", "short_stay_rate_plans", ["room_type_id"]); op.create_index("ix_short_stay_rate_plans_active", "short_stay_rate_plans", ["active"])
    op.create_table("room_type_inventory", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("room_type_id", sa.Integer(), sa.ForeignKey("loai_phong.id", ondelete="CASCADE"), nullable=False), sa.Column("date", sa.Date(), nullable=False), sa.Column("capacity", sa.Integer(), nullable=False), sa.Column("reserved", sa.Integer(), nullable=False, server_default="0"), sa.Column("version", sa.Integer(), nullable=False, server_default="1"), sa.Column("updated_at", sa.DateTime(), nullable=False), sa.UniqueConstraint("room_type_id", "date", name="uq_room_type_inventory_date"), sa.CheckConstraint("capacity >= 0 AND reserved >= 0 AND reserved <= capacity", name="ck_room_type_inventory_bounds"))
    op.create_index("ix_room_type_inventory_room_type_id", "room_type_inventory", ["room_type_id"]); op.create_index("ix_room_type_inventory_date", "room_type_inventory", ["date"])
    op.create_table("room_type_booking_requests", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("room_type_id", sa.Integer(), sa.ForeignKey("loai_phong.id", ondelete="RESTRICT"), nullable=False), sa.Column("rate_plan_id", sa.Integer(), sa.ForeignKey("short_stay_rate_plans.id", ondelete="RESTRICT"), nullable=False), sa.Column("guest_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False), sa.Column("sale_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL")), sa.Column("check_in_date", sa.Date(), nullable=False), sa.Column("check_out_date", sa.Date(), nullable=False), sa.Column("guest_count", sa.Integer(), nullable=False, server_default="1"), sa.Column("status", sa.String(30), nullable=False, server_default="REQUESTED"), sa.Column("quote_snapshot", sa.JSON(), nullable=False), sa.Column("cancellation_policy_snapshot", sa.JSON(), nullable=False), sa.Column("assigned_room_id", sa.Integer(), sa.ForeignKey("rooms.id", ondelete="SET NULL")), sa.Column("reservation_id", sa.Integer(), sa.ForeignKey("reservations.id", ondelete="SET NULL")), sa.Column("created_at", sa.DateTime(), nullable=False), sa.Column("updated_at", sa.DateTime(), nullable=False))
    for c in ("room_type_id", "guest_user_id", "sale_user_id", "status"): op.create_index(f"ix_room_type_booking_requests_{c}", "room_type_booking_requests", [c])


def downgrade() -> None:
    op.drop_table("room_type_booking_requests"); op.drop_table("room_type_inventory"); op.drop_table("short_stay_rate_plans")
