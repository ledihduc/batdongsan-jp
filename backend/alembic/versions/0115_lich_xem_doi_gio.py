"""LỊCH XEM — chủ nhà/sale BẬN thì xin đổi giờ, khách chọn lại (15/09/2026).

Trước đây bên bán bận chỉ có hai nút: duyệt (rồi không đến) hoặc từ chối (mất
khách). Nay có đường thứ ba: "Bận giờ này" kèm vài giờ đề xuất; lịch chuyển sang
trạng thái `doi_gio` và nhả khung giờ cũ; khách mở phiếu, chọn một giờ đề xuất
(coi như đã được duyệt) hoặc tự chọn giờ trống khác (quay về chờ duyệt).

  * `de_xuat_gio` — JSON [{"ngay": "YYYY-MM-DD", "gio": "HH:MM-HH:MM"}]
  * `ly_do_doi`   — "Tôi có việc đột xuất" — khách cần biết vì sao bị đổi
  * `gio_cu`      — "2026-09-16 10:00-11:00", để phiếu nói "chủ nhà bận lúc…"
  * `nguoi_doi`   — ai bấm đổi (sale hay chủ nhà)

Tất cả cho phép rỗng; lịch cũ không bao giờ có.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0115_lich_xem_doi_gio"
down_revision = "0114_lich_xem_hinh_thuc"
branch_labels = None
depends_on = None

_COT = (
    ("de_xuat_gio", sa.Text()),
    ("ly_do_doi", sa.Text()),
    ("gio_cu", sa.String(40)),
    ("nguoi_doi", sa.Integer()),
)


def _cot() -> set[str]:
    insp = sa.inspect(op.get_bind())
    if "viewing_appointments" not in insp.get_table_names():
        return set()
    return {c["name"] for c in insp.get_columns("viewing_appointments")}


def upgrade() -> None:
    co = _cot()
    if not co:
        return
    for ten, kieu in _COT:
        if ten not in co:
            op.add_column("viewing_appointments", sa.Column(ten, kieu, nullable=True))


def downgrade() -> None:
    co = _cot()
    for ten, _kieu in reversed(_COT):
        if ten in co:
            op.drop_column("viewing_appointments", ten)
