"""Đường liên hệ sau khi thắng thầu (có sự đồng ý) + nhật ký tiết lộ

Revision ID: 0056_contact_reveal
Revises: 0055_report_kind

Nối khúc đứt cuối của mảng thi công: sau khi chủ nhà chấp nhận báo giá, hai bên
không có cách liên hệ (SĐT bị che, không endpoint mở). Nay:

- `construction_leads.contact_shared_at` — mốc chủ nhà ĐỒNG Ý chia sẻ số của
  mình cho đơn vị thắng. Nullable; null = chưa đồng ý. Đây là "sự đồng ý" theo
  Luật BVDLCN 2025 — chính chủ số bấm nút, không phải hệ thống tự mở.
- `contact_reveal_logs` — ghi vết MỖI lần số được đọc (ai đọc, lead nào, khi
  nào). Bắt buộc để tuân thủ + truy vết nếu bị lạm dụng.

Cả hai đều additive; bảng/cột cũ không đổi.
"""

from alembic import op
import sqlalchemy as sa

revision = "0056_contact_reveal"
down_revision = "0055_report_kind"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    tables = set(insp.get_table_names())

    if "construction_leads" in tables and "contact_shared_at" not in _cols(
        "construction_leads"
    ):
        op.add_column(
            "construction_leads",
            sa.Column("contact_shared_at", sa.DateTime(), nullable=True),
        )

    if "contact_reveal_logs" not in tables:
        op.create_table(
            "contact_reveal_logs",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("lead_id", sa.Integer(), nullable=False, index=True),
            sa.Column("contractor_id", sa.Integer(), nullable=False, index=True),
            # Ai bấm xem (user_id của đơn vị) — để truy trách nhiệm cá nhân.
            sa.Column("revealed_by", sa.Integer(), nullable=False),
            sa.Column(
                "created_at",
                sa.DateTime(),
                nullable=False,
                server_default=sa.func.now(),
            ),
        )


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    tables = set(insp.get_table_names())
    if "contact_reveal_logs" in tables:
        op.drop_table("contact_reveal_logs")
    if "construction_leads" in tables and "contact_shared_at" in _cols(
        "construction_leads"
    ):
        op.drop_column("construction_leads", "contact_shared_at")
