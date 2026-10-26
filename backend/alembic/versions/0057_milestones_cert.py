"""Báo giá theo giai đoạn (B1) + chứng chỉ hành nghề (B3)

Revision ID: 0057_milestones_cert
Revises: 0056_contact_reveal

B1 — quotes.milestones (JSON): đơn vị đề xuất tiến độ thanh toán theo giai
     đoạn (mặc định 30/20/20/20 theo thông lệ VN). Chỉ là CƠ CẤU của báo giá;
     theo dõi đã trả từng giai đoạn là việc của Đợt C, chưa làm.
B3 — contractors.cert_number + cert_verified: số chứng chỉ hành nghề đơn vị tự
     khai + cờ admin đã đối chiếu (moc.gov.vn). Badge tin cậy phụ, không phải
     trụ định vị (xem docs/PLAN-ROLE-DON-VI-THIET-KE.md §2.4).

Tất cả additive + nullable. Bảng/cột cũ không đổi.
"""

from alembic import op
import sqlalchemy as sa

revision = "0057_milestones_cert"
down_revision = "0056_contact_reveal"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    tables = set(insp.get_table_names())

    if "quotes" in tables and "milestones" not in _cols("quotes"):
        # JSON hoạt động trên cả PostgreSQL lẫn SQLite (test).
        op.add_column("quotes", sa.Column("milestones", sa.JSON(), nullable=True))

    if "contractors" in tables:
        cols = _cols("contractors")
        if "cert_number" not in cols:
            op.add_column(
                "contractors",
                sa.Column("cert_number", sa.String(length=100), nullable=True),
            )
        if "cert_verified" not in cols:
            op.add_column(
                "contractors",
                sa.Column("cert_verified", sa.Boolean(), nullable=False,
                          server_default=sa.false()),
            )


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    tables = set(insp.get_table_names())
    if "contractors" in tables:
        cols = _cols("contractors")
        if "cert_verified" in cols:
            op.drop_column("contractors", "cert_verified")
        if "cert_number" in cols:
            op.drop_column("contractors", "cert_number")
    if "quotes" in tables and "milestones" in _cols("quotes"):
        op.drop_column("quotes", "milestones")
