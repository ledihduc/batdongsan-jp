"""quick_services — dịch vụ NHANH (sửa điện/nước/thông tắc…) kiểu Vua Thợ

Hai việc:

1. Thêm `construction_services.kind`:
     * 'marketplace' — Thiết kế · Xây dựng · Nội thất: có sàn nhà thầu, khách xem
       danh bạ rồi mới gửi yêu cầu, yêu cầu chảy vào feed cho nhà thầu báo giá.
     * 'quick' — Sửa điện · Sửa nước · …: KHÔNG có sàn, khách bấm là điền form,
       admin nhận thông báo rồi tự gọi thợ quen và xếp lịch.

   Vì sao là CỘT chứ không phải danh sách slug cứng trong code: cả backend (đặt
   `visibility='private'` để SĐT khách không lọt feed nhà thầu) lẫn app (bấm ô
   thì mở FORM hay mở DANH BẠ, và ẩn dịch vụ nhanh khỏi bộ lọc nhà thầu) đều
   phải biết. Chép danh sách slug ở hai repo thì sớm muộn cũng lệch, mà lệch ở
   đây nghĩa là lộ số điện thoại khách.

2. Seed 11 dịch vụ nhanh. Trước migration này bảng chỉ có 3 dòng (design ·
   build · interior), tức là "phần dịch vụ" của app chỉ có mảng thi công.

Bất biến: additive · idempotent (INSERT theo slug chưa có) · có downgrade.
Downgrade CHỈ xoá dịch vụ chưa có yêu cầu nào trỏ tới — xoá dòng đang được
`construction_leads.service_slug` tham chiếu sẽ biến yêu cầu thật thành mồ côi.

Revision ID: 0077_quick_services
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0077_quick_services"
down_revision: Union[str, Sequence[str], None] = "0076_demand_posts"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# (slug, tên, mô tả, icon, thứ tự). Icon là tên Material Icon phía app.
_QUICK = [
    ("electric", "Sửa điện", "Chập cháy, mất pha, aptomat nhảy, đi dây mới", "bolt", 10),
    ("plumbing", "Sửa nước", "Rò rỉ, vỡ ống, thay vòi sen, lắp bồn", "water_drop", 11),
    ("unclog", "Thông tắc", "Tắc bồn cầu, cống thoát sàn, chậu rửa", "plumbing", 12),
    ("ac_repair", "Sửa điều hoà", "Không lạnh, chảy nước, vệ sinh, nạp gas", "ac_unit", 13),
    ("appliance_repair", "Sửa đồ gia dụng", "Máy giặt, tủ lạnh, bình nóng lạnh", "kitchen", 14),
    ("cleaning", "Vệ sinh nhà", "Tổng vệ sinh, sau xây dựng, theo định kỳ", "cleaning_services", 15),
    ("moving", "Chuyển nhà", "Chuyển nhà trọn gói, chuyển văn phòng", "local_shipping", 16),
    ("painting", "Sơn nhà", "Sơn lại nhà, sơn mới, xử lý tường", "format_paint", 17),
    ("waterproofing", "Chống thấm", "Sân thượng, nhà vệ sinh, tường ngoài", "umbrella", 18),
    ("pest_control", "Diệt côn trùng", "Muỗi, gián, mối, chuột", "pest_control", 19),
    ("hourly_helper", "Giúp việc theo giờ", "Dọn dẹp, nấu ăn, trông nhà theo giờ", "schedule", 20),
]

_TABLE = "construction_services"


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    cols = {c["name"] for c in insp.get_columns(_TABLE)}
    if "kind" not in cols:
        op.add_column(
            _TABLE,
            sa.Column(
                "kind", sa.String(20), nullable=False, server_default="marketplace"
            ),
        )
    idx = {i["name"] for i in insp.get_indexes(_TABLE)}
    if "ix_construction_services_kind" not in idx:
        op.create_index("ix_construction_services_kind", _TABLE, ["kind"])

    da_co = {
        r[0]
        for r in bind.execute(sa.text(f"SELECT slug FROM {_TABLE}")).fetchall()
    }
    for slug, ten, mo_ta, icon, thu_tu in _QUICK:
        if slug in da_co:
            continue
        bind.execute(
            sa.text(
                f"INSERT INTO {_TABLE} "
                "(slug, name, description, icon, sort_order, is_active, kind) "
                "VALUES (:slug, :ten, :mo_ta, :icon, :thu_tu, true, 'quick')"
            ),
            {"slug": slug, "ten": ten, "mo_ta": mo_ta, "icon": icon, "thu_tu": thu_tu},
        )


def downgrade() -> None:
    bind = op.get_bind()
    slugs = [s for s, *_ in _QUICK]
    # Chỉ xoá dịch vụ CHƯA có yêu cầu nào trỏ tới — xoá dòng đang được
    # construction_leads.service_slug tham chiếu sẽ làm yêu cầu thật mồ côi.
    # `IN :slugs` với expanding bindparam thay cho `= ANY(...)`: ANY là cú pháp
    # riêng của Postgres, còn test migration chạy trên SQLite.
    bind.execute(
        sa.text(
            f"DELETE FROM {_TABLE} WHERE slug IN :slugs AND slug NOT IN "
            "(SELECT DISTINCT service_slug FROM construction_leads)"
        ).bindparams(sa.bindparam("slugs", expanding=True)),
        {"slugs": slugs},
    )
    insp = sa.inspect(bind)
    idx = {i["name"] for i in insp.get_indexes(_TABLE)}
    if "ix_construction_services_kind" in idx:
        op.drop_index("ix_construction_services_kind", table_name=_TABLE)
    cols = {c["name"] for c in insp.get_columns(_TABLE)}
    if "kind" in cols:
        op.drop_column(_TABLE, "kind")
