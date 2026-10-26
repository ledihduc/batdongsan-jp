"""service_request_ops — trường vận hành cho yêu cầu dịch vụ

`construction_leads` đã chứa đủ NỘI DUNG yêu cầu (dịch vụ, tên, SĐT, khu vực,
mô tả, ảnh, vị trí). Thiếu đúng phần VẬN HÀNH của admin:

  * `scheduled_at` — hẹn thợ đến lúc nào. Không có cột này thì "xếp lịch" chỉ
    còn là chữ trong ghi chú, không lọc/sắp xếp được theo ngày.
  * `admin_note` — admin gọi xong ghi lại kết quả ("khách bận, gọi lại chiều
    mai"). Không có thì lần gọi sau bắt đầu từ số 0.
  * `contacted_at` — mốc admin liên hệ lần đầu. Đây là số đo DUY NHẤT nói được
    dịch vụ này có sống hay không: khách gửi lúc 22h, gọi lại lúc 9h hôm sau là
    mất khách. Không đo thì không biết mình chậm.

Bất biến: additive · nullable · idempotent · có downgrade.

Revision ID: 0078_service_request_ops
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0078_service_request_ops"
down_revision: Union[str, Sequence[str], None] = "0077_quick_services"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLE = "construction_leads"
_COLS = (
    ("scheduled_at", sa.DateTime),
    ("contacted_at", sa.DateTime),
    ("admin_note", sa.Text),
)


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    cols = {c["name"] for c in insp.get_columns(_TABLE)}
    for ten, kieu in _COLS:
        if ten not in cols:
            op.add_column(_TABLE, sa.Column(ten, kieu, nullable=True))
    idx = {i["name"] for i in insp.get_indexes(_TABLE)}
    # Màn admin sắp theo lịch hẹn gần nhất.
    if "ix_construction_leads_scheduled_at" not in idx:
        op.create_index(
            "ix_construction_leads_scheduled_at", _TABLE, ["scheduled_at"]
        )


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    idx = {i["name"] for i in insp.get_indexes(_TABLE)}
    if "ix_construction_leads_scheduled_at" in idx:
        op.drop_index("ix_construction_leads_scheduled_at", table_name=_TABLE)
    cols = {c["name"] for c in insp.get_columns(_TABLE)}
    for ten, _ in _COLS:
        if ten in cols:
            op.drop_column(_TABLE, ten)
