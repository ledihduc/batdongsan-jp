"""contractor_legal_verify

Xác minh NĂM THÀNH LẬP bằng GIẤY TỜ thay vì tự khai (B4).

Căn cứ pháp lý (VN):
  • Giấy chứng nhận ĐKDN — Luật Doanh nghiệp 59/2020/QH14 buộc công khai trên
    Cổng thông tin quốc gia dangkykinhdoanh.gov.vn → tra theo MÃ SỐ THUẾ ra
    tên + NGÀY CẤP (= năm thành lập) + tình trạng hoạt động.
  • Chứng chỉ năng lực hoạt động xây dựng (Hạng I Bộ XD / Hạng II-III Sở XD).

Bất biến: additive + nullable + idempotent. Đơn vị CHƯA xác minh KHÔNG bị ẩn,
chỉ là không có nhãn năm & không lọt bộ lọc kinh nghiệm (dùng established_year
đã xác minh, KHÔNG dùng year_established tự khai).

Revision ID: 0073_contractor_legal_verify
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0073_contractor_legal_verify"
down_revision: Union[str, Sequence[str], None] = "0072_contractor_scale"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_COLS = [
    # Hồ sơ đơn vị NỘP LÊN
    ("tax_code", sa.String(20)),            # MST/MSDN — khoá tra cứu quốc gia
    ("license_path", sa.String(500)),       # ảnh/scan GCN ĐKDN
    ("license_number", sa.String(100)),     # số GCN ĐKDN
    ("cert_path", sa.String(500)),          # ảnh chứng chỉ năng lực XD
    ("cert_rank", sa.String(4)),            # 'I' | 'II' | 'III'
    # Kết quả TRA CỨU TỰ ĐỘNG (dangkykinhdoanh/MST) — để admin đối chiếu
    ("lookup_name", sa.String(300)),        # tên DN theo cổng quốc gia
    ("lookup_year", sa.Integer),            # năm cấp theo cổng quốc gia
    ("lookup_at", sa.DateTime),
    # Kết quả DUYỆT của admin (nguồn sự thật cho nhãn/bộ lọc)
    ("established_year", sa.Integer),       # NĂM ĐÃ XÁC MINH
    ("legal_status", sa.String(12)),        # none|pending|approved|rejected
    ("legal_note", sa.Text),                # lý do từ chối / ghi chú admin
    ("legal_verified_at", sa.DateTime),
    ("legal_verified_by_admin_id", sa.Integer),
]


def _has_col(insp, table, col) -> bool:
    return col in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    for name, type_ in _COLS:
        if not _has_col(insp, "contractors", name):
            op.add_column("contractors", sa.Column(name, type_, nullable=True))
    idx = {i["name"] for i in insp.get_indexes("contractors")}
    if "ix_contractors_established_year" not in idx:
        op.create_index("ix_contractors_established_year", "contractors",
                        ["established_year"])
    if "ix_contractors_legal_status" not in idx:
        op.create_index("ix_contractors_legal_status", "contractors",
                        ["legal_status"])
    # Đơn vị chưa nộp hồ sơ → 'none' (KHÔNG ẩn khỏi danh bạ).
    op.execute("UPDATE contractors SET legal_status='none' WHERE legal_status IS NULL")


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    idx = {i["name"] for i in insp.get_indexes("contractors")}
    for n in ("ix_contractors_established_year", "ix_contractors_legal_status"):
        if n in idx:
            op.drop_index(n, table_name="contractors")
    for name, _ in _COLS:
        if _has_col(insp, "contractors", name):
            op.drop_column("contractors", name)
