"""Tách vai trò nghiệp vụ + hồ sơ sale + liên kết sale ↔ chủ phòng.

Spec mục 3. Ba việc:
  1. `users.account_type` (customer|sale|owner|admin) — TÁCH khỏi `users.role`.
     `role` là quyền JWT (guest/host/admin) và có 17 test auth bám vào; đụng vào
     nó là đụng vào đăng nhập của 2.263 tài khoản. Nên thêm cột mới.
  2. `sale_profiles` — hồ sơ công khai + MÃ LIÊN KẾT cố định của sale.
  3. `sale_owner_links` — nguồn sự thật cho mọi kiểm tra quyền về sau.

Backfill account_type (thận trọng, KHÔNG tự phong ai làm sale):
  - admin              → admin
  - có buildings/contracts → owner   (đã thật sự vận hành nhà)
  - còn lại            → customer
Sale là TỰ CHỌN: ai tạo `sale_profile` thì thành sale.

Revision ID: 0085_sale_owner
Revises: 0084_building_public
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0085_sale_owner"
down_revision = "0084_building_public"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "account_type",
            sa.String(20),
            nullable=False,
            server_default="customer",
        ),
    )
    op.create_index("ix_users_account_type", "users", ["account_type"])

    op.create_table(
        "sale_profiles",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("sale_code", sa.String(20), nullable=False, unique=True),
        sa.Column("display_name", sa.String(200), nullable=True),
        sa.Column("bio", sa.Text(), nullable=True),
        sa.Column("avatar_path", sa.String(500), nullable=True),
        sa.Column("cover_path", sa.String(500), nullable=True),
        sa.Column(
            "service_areas",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
        sa.Column(
            "verified", sa.Boolean(), nullable=False, server_default=sa.text("false")
        ),
        sa.Column(
            "trusted", sa.Boolean(), nullable=False, server_default=sa.text("false")
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_sale_profiles_sale_code", "sale_profiles", ["sale_code"])

    op.create_table(
        "sale_owner_links",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "sale_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "owner_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("status", sa.String(20), nullable=False, server_default="active"),
        sa.Column("linked_at", sa.DateTime(), nullable=False),
        sa.Column("ended_at", sa.DateTime(), nullable=True),
        sa.Column(
            "created_by",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("end_reason", sa.String(300), nullable=True),
    )
    op.create_index("ix_sale_owner_links_sale_id", "sale_owner_links", ["sale_id"])
    op.create_index("ix_sale_owner_links_owner_id", "sale_owner_links", ["owner_id"])
    op.create_index("ix_sale_owner_links_status", "sale_owner_links", ["status"])
    # "Một chủ phòng CHỈ MỘT sale chính đang hoạt động" (spec mục 2). Phải là
    # chỉ mục duy nhất MỘT PHẦN: liên kết đã kết thúc vẫn nằm lại để tra lịch
    # sử, nên UNIQUE thường sẽ chặn nhầm.
    op.create_index(
        "uq_sale_owner_links_owner_active",
        "sale_owner_links",
        ["owner_id"],
        unique=True,
        postgresql_where=sa.text("status = 'active'"),
    )

    # Sở hữu nằm ở PHÒNG, không ở toà (spec mục 3: "một dự án có thể chứa phòng
    # của nhiều chủ phòng"). Thêm cột + backfill ở đây; việc đổi cách ly dữ liệu
    # trong RoomRepository để bước sau, tách rủi ro ra khỏi migration.
    op.add_column("rooms", sa.Column("owner_id", sa.Integer(), nullable=True))
    op.add_column(
        "rooms", sa.Column("managed_by_sale_id", sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        "fk_rooms_owner", "rooms", "users", ["owner_id"], ["id"], ondelete="SET NULL"
    )
    op.create_foreign_key(
        "fk_rooms_sale",
        "rooms",
        "users",
        ["managed_by_sale_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_rooms_owner_id", "rooms", ["owner_id"])
    op.create_index("ix_rooms_managed_by_sale_id", "rooms", ["managed_by_sale_id"])

    conn = op.get_bind()
    # Phòng đang chạy phải giữ đúng chủ: hiện chủ suy từ buildings.host_id.
    conn.execute(
        sa.text(
            "UPDATE rooms r SET owner_id = b.host_id "
            "FROM buildings b WHERE b.id = r.building_id AND r.owner_id IS NULL"
        )
    )
    conn.execute(sa.text("UPDATE users SET account_type='admin' WHERE role='admin'"))
    conn.execute(
        sa.text(
            """
            UPDATE users SET account_type='owner'
            WHERE role <> 'admin' AND (
                id IN (SELECT DISTINCT host_id FROM buildings)
                OR id IN (SELECT DISTINCT host_id FROM contracts)
            )
            """
        )
    )


def downgrade() -> None:
    op.drop_index("ix_rooms_managed_by_sale_id", table_name="rooms")
    op.drop_index("ix_rooms_owner_id", table_name="rooms")
    op.drop_constraint("fk_rooms_sale", "rooms", type_="foreignkey")
    op.drop_constraint("fk_rooms_owner", "rooms", type_="foreignkey")
    op.drop_column("rooms", "managed_by_sale_id")
    op.drop_column("rooms", "owner_id")
    op.drop_index("uq_sale_owner_links_owner_active", table_name="sale_owner_links")
    op.drop_index("ix_sale_owner_links_status", table_name="sale_owner_links")
    op.drop_index("ix_sale_owner_links_owner_id", table_name="sale_owner_links")
    op.drop_index("ix_sale_owner_links_sale_id", table_name="sale_owner_links")
    op.drop_table("sale_owner_links")
    op.drop_index("ix_sale_profiles_sale_code", table_name="sale_profiles")
    op.drop_table("sale_profiles")
    op.drop_index("ix_users_account_type", table_name="users")
    op.drop_column("users", "account_type")
