"""service_domain — cụm DỊCH VỤ độc lập, tách khỏi thi công

Trước đây tính năng "đặt dịch vụ" mượn hạ tầng thi công: danh mục nằm ở
`construction_services`, yêu cầu nằm ở `construction_leads`. Nay mảng thi công
(sàn nhà thầu, báo giá, thư viện thiết kế) bị gỡ khỏi sản phẩm, nên dịch vụ
phải có bảng riêng — không thể để một tính năng đang sống phụ thuộc vào cụm
sắp bị xoá.

Hai bảng mới:
  * `services`         — danh mục dịch vụ (Sửa điện, Thông tắc, Vệ sinh…).
  * `service_requests` — yêu cầu khách gửi + phần vận hành của admin.

CHUYỂN DỮ LIỆU, không bỏ: 11 dịch vụ nhanh và mọi yêu cầu đang có ở bảng cũ
được sao sang bảng mới (idempotent theo slug / theo `legacy_lead_id`). Bảng cũ
KHÔNG bị xoá ở migration này — xoá dữ liệu thật là việc một chiều, để riêng
một bước sau khi bản mới chạy ổn.

Bất biến: additive · idempotent · có downgrade.

Revision ID: 0079_service_domain
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0079_service_domain"
down_revision: Union[str, Sequence[str], None] = "0078_service_request_ops"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    ten_bang = set(insp.get_table_names())

    if "services" not in ten_bang:
        op.create_table(
            "services",
            sa.Column("id", sa.Integer, primary_key=True),
            sa.Column("slug", sa.String(40), nullable=False, unique=True),
            sa.Column("name", sa.String(100), nullable=False),
            sa.Column("description", sa.Text, nullable=True),
            sa.Column("icon", sa.String(50), nullable=True),
            sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
            sa.Column(
                "is_active", sa.Boolean, nullable=False, server_default=sa.true()
            ),
        )
        op.create_index("ix_services_slug", "services", ["slug"], unique=True)
        op.create_index("ix_services_is_active", "services", ["is_active"])

    if "service_requests" not in ten_bang:
        op.create_table(
            "service_requests",
            sa.Column("id", sa.Integer, primary_key=True),
            # null = khách vãng lai (đa số) — không ép đăng nhập mới đặt được thợ.
            sa.Column("user_id", sa.Integer, nullable=True),
            sa.Column("service_slug", sa.String(40), nullable=False),
            sa.Column("name", sa.String(200), nullable=False),
            sa.Column("phone", sa.String(50), nullable=False),
            sa.Column("area", sa.String(200), nullable=True),
            sa.Column("budget", sa.String(100), nullable=True),
            sa.Column("description", sa.Text, nullable=True),
            sa.Column("images", sa.JSON, nullable=True),
            sa.Column("province_code", sa.String(32), nullable=True),
            sa.Column("location_text", sa.String(200), nullable=True),
            sa.Column("lat", sa.Float, nullable=True),
            sa.Column("lng", sa.Float, nullable=True),
            sa.Column("status", sa.String(20), nullable=False, server_default="new"),
            sa.Column("scheduled_at", sa.DateTime, nullable=True),
            sa.Column("contacted_at", sa.DateTime, nullable=True),
            sa.Column("admin_note", sa.Text, nullable=True),
            sa.Column("source", sa.String(30), nullable=False, server_default="app"),
            # Mốc để việc sao dữ liệu chạy lại được mà không nhân đôi.
            sa.Column("legacy_lead_id", sa.Integer, nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime,
                nullable=False,
                server_default=sa.func.now(),
            ),
        )
        for ten, cot in (
            ("ix_service_requests_status", ["status"]),
            ("ix_service_requests_service_slug", ["service_slug"]),
            ("ix_service_requests_phone", ["phone"]),
            ("ix_service_requests_created_at", ["created_at"]),
            ("ix_service_requests_legacy", ["legacy_lead_id"]),
        ):
            op.create_index(ten, "service_requests", cot)

    # ── Chuyển dữ liệu từ cụm thi công ────────────────────────────────────────
    if "construction_services" in ten_bang:
        bind.execute(
            sa.text(
                "INSERT INTO services "
                "(slug, name, description, icon, sort_order, is_active) "
                "SELECT slug, name, description, icon, sort_order, is_active "
                "FROM construction_services cs "
                "WHERE NOT EXISTS (SELECT 1 FROM services s WHERE s.slug = cs.slug)"
            )
        )

    if "construction_leads" in ten_bang:
        bind.execute(
            sa.text(
                "INSERT INTO service_requests "
                "(user_id, service_slug, name, phone, area, budget, description, "
                " province_code, location_text, lat, lng, status, scheduled_at, "
                " contacted_at, admin_note, source, legacy_lead_id, created_at) "
                "SELECT user_id, service_slug, name, phone, area, budget, "
                "       description, province_code, location_text, lat, lng, "
                "       status, scheduled_at, contacted_at, admin_note, source, "
                "       id, created_at "
                "FROM construction_leads cl "
                "WHERE NOT EXISTS ("
                "  SELECT 1 FROM service_requests sr WHERE sr.legacy_lead_id = cl.id"
                ")"
            )
        )


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    ten_bang = set(insp.get_table_names())
    if "service_requests" in ten_bang:
        op.drop_table("service_requests")
    if "services" in ten_bang:
        op.drop_table("services")
