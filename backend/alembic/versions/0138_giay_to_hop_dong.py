"""Giấy tờ hợp đồng: ảnh/PDF hợp đồng + minh chứng cọc gắn vào HỢP ĐỒNG.

Chủ dự án (14/10/2026): thuê trước, bổ sung hợp đồng / minh chứng cọc sau
cũng được nhưng phải có cảnh báo; chủ nhà HOẶC khách chụp và tải lên.
Trước đây giấy tờ chỉ có trong hồ sơ chốt thuê qua sale (rental_journeys),
nên 17/21 hợp đồng do chủ nhà tự nhập không có chỗ nào để lưu.

Additive, idempotent.

Revision ID: 0138_giay_to_hop_dong
Revises: 0137_admin_backoffice
"""

from alembic import op
import sqlalchemy as sa

revision = "0138_giay_to_hop_dong"
down_revision = "0137_admin_backoffice"
branch_labels = None
depends_on = None


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    if "contract_tai_lieu" in insp.get_table_names():
        return
    op.create_table(
        "contract_tai_lieu",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "contract_id",
            sa.Integer(),
            sa.ForeignKey("contracts.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("loai", sa.String(20), nullable=False),
        sa.Column("url", sa.String(500), nullable=False),
        sa.Column("vai", sa.String(20), nullable=False),
        sa.Column(
            "nguoi_tai_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_contract_tai_lieu_contract_id", "contract_tai_lieu", ["contract_id"])


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    if "contract_tai_lieu" in insp.get_table_names():
        op.drop_index("ix_contract_tai_lieu_contract_id", table_name="contract_tai_lieu")
        op.drop_table("contract_tai_lieu")
