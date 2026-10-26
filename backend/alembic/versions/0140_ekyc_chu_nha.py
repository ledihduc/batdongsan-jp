"""eKYC chủ nhà: CCCD hai mặt + chân dung + GPKD, link làm trên điện thoại khác.

Chủ dự án (14/10/2026): chủ nhà tải giấy tờ kinh doanh + CCCD qua eKYC trực
tuyến trong app (có link), lưu ảnh về, admin duyệt. Hồ sơ nộp chép sang
operator_business_profiles để dùng hàng đợi KYC sẵn có của admin v2.

  * ekyc_chu_nha  — bản nháp/trạng thái eKYC của từng chủ nhà
  * ekyc_link     — token (băm) mở luồng eKYC trên thiết bị khác, 24 giờ
  * operator_business_profiles.legal_representative_selfie_path

Additive, idempotent.

Revision ID: 0140_ekyc_chu_nha
Revises: 0139_tai_khoan_nhan_tien
"""

from alembic import op
import sqlalchemy as sa

revision = "0140_ekyc_chu_nha"
down_revision = "0139_tai_khoan_nhan_tien"
branch_labels = None
depends_on = None


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    bang = set(insp.get_table_names())
    if "ekyc_chu_nha" not in bang:
        op.create_table(
            "ekyc_chu_nha",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("trang_thai", sa.String(20), nullable=True),
            sa.Column("ho_ten", sa.String(300), nullable=True),
            sa.Column("so_cccd_hash", sa.String(100), nullable=True),
            sa.Column("so_cccd_cuoi", sa.String(4), nullable=True),
            sa.Column("ten_kinh_doanh", sa.String(300), nullable=True),
            sa.Column("so_gpkd", sa.String(50), nullable=True),
            sa.Column("cccd_truoc", sa.String(500), nullable=True),
            sa.Column("cccd_sau", sa.String(500), nullable=True),
            sa.Column("chan_dung", sa.String(500), nullable=True),
            sa.Column("gpkd", sa.String(500), nullable=True),
            sa.Column("ly_do_tu_choi", sa.Text(), nullable=True),
            sa.Column("nop_luc", sa.DateTime(), nullable=True),
            sa.Column("duyet_luc", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.Column("updated_at", sa.DateTime(), nullable=True),
        )
        op.create_index("ix_ekyc_chu_nha_user_id", "ekyc_chu_nha", ["user_id"], unique=True)
    if "ekyc_link" not in bang:
        op.create_table(
            "ekyc_link",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("token_hash", sa.String(64), nullable=False),
            sa.Column("het_han", sa.DateTime(), nullable=False),
            sa.Column("dung_luc", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )
        op.create_index("ix_ekyc_link_token_hash", "ekyc_link", ["token_hash"], unique=True)
        op.create_index("ix_ekyc_link_user_id", "ekyc_link", ["user_id"])
    co = {c["name"] for c in insp.get_columns("operator_business_profiles")}
    if "legal_representative_selfie_path" not in co:
        op.add_column(
            "operator_business_profiles",
            sa.Column("legal_representative_selfie_path", sa.String(500), nullable=True),
        )


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    co = {c["name"] for c in insp.get_columns("operator_business_profiles")}
    if "legal_representative_selfie_path" in co:
        op.drop_column("operator_business_profiles", "legal_representative_selfie_path")
    bang = set(insp.get_table_names())
    if "ekyc_link" in bang:
        op.drop_table("ekyc_link")
    if "ekyc_chu_nha" in bang:
        op.drop_table("ekyc_chu_nha")
