"""Sale quản lý theo YÊU CẦU: khách của sale, đơn thuê, căn đã gửi, mốc pipeline.

Sale làm việc theo ĐƠN của khách ("10–15 triệu, Thảo Điền, 2PN, vào ở tháng
10") chứ không theo từng cái tin. Trước đây mỗi mẩu của câu chuyện nằm một
bảng — lịch xem, hồ sơ thuê, deal — và không bảng nào giữ chính cái đơn, nên
sale không có chỗ nào trả lời "khách này đang tới bước nào".

Thêm cả `sale_profiles.hoa_hong_phan_tram` (mặc định 50%) để tính hoa hồng khi
chốt: hoa hồng = % × giá thuê tháng đầu.

Additive: bảng mới + một cột nullable; không đụng dữ liệu cũ.

Revision ID: 0132_sale_quan_ly_theo_yeu_cau
Revises: 0131_ho_so_thue_noi_hop_dong
"""

import sqlalchemy as sa
from alembic import op

revision = "0132_sale_quan_ly_theo_yeu_cau"
down_revision = "0131_ho_so_thue_noi_hop_dong"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    bang = set(inspector.get_table_names())

    if "sale_khach" not in bang:
        op.create_table(
            "sale_khach",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "sale_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column("ho_ten", sa.String(200), nullable=False),
            sa.Column("sdt", sa.String(20), nullable=False, server_default=""),
            sa.Column("khu_vuc", sa.String(200), nullable=True),
            sa.Column("ghi_chu", sa.Text(), nullable=True),
            sa.Column(
                "trang_thai",
                sa.String(20),
                nullable=False,
                server_default="dang_tu_van",
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_sale_khach_sale_id", "sale_khach", ["sale_id"])
        op.create_index("ix_sale_khach_user_id", "sale_khach", ["user_id"])
        op.create_index("ix_sale_khach_sdt", "sale_khach", ["sdt"])
        op.create_index("ix_sale_khach_trang_thai", "sale_khach", ["trang_thai"])

    if "sale_yeu_cau" not in bang:
        op.create_table(
            "sale_yeu_cau",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "sale_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "khach_id",
                sa.Integer(),
                sa.ForeignKey("sale_khach.id", ondelete="CASCADE"),
                nullable=False,
            ),
            # Không FK: `demand_posts` thuộc metadata khác (app/domain).
            sa.Column("demand_id", sa.Integer(), nullable=True),
            sa.Column("loai_can", sa.String(120), nullable=True),
            sa.Column("khu_vuc", sa.String(200), nullable=True),
            sa.Column("ngan_sach_min", sa.BigInteger(), nullable=True),
            sa.Column("ngan_sach_max", sa.BigInteger(), nullable=True),
            sa.Column("vao_o_tu", sa.DateTime(), nullable=True),
            sa.Column("ghi_chu", sa.Text(), nullable=True),
            sa.Column(
                "trang_thai", sa.String(24), nullable=False, server_default="lead_moi"
            ),
            sa.Column("dong_ly_do", sa.String(300), nullable=True),
            sa.Column("dong_luc", sa.DateTime(), nullable=True),
            sa.Column("chot_luc", sa.DateTime(), nullable=True),
            sa.Column(
                "contract_id",
                sa.Integer(),
                sa.ForeignKey("contracts.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_sale_yeu_cau_sale_id", "sale_yeu_cau", ["sale_id"])
        op.create_index("ix_sale_yeu_cau_khach_id", "sale_yeu_cau", ["khach_id"])
        op.create_index("ix_sale_yeu_cau_trang_thai", "sale_yeu_cau", ["trang_thai"])
        op.create_index("ix_sale_yeu_cau_created_at", "sale_yeu_cau", ["created_at"])

    if "sale_yeu_cau_can" not in bang:
        op.create_table(
            "sale_yeu_cau_can",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "yeu_cau_id",
                sa.Integer(),
                sa.ForeignKey("sale_yeu_cau.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "house_id",
                sa.Integer(),
                sa.ForeignKey("houses.id", ondelete="CASCADE"),
                nullable=True,
            ),
            sa.Column(
                "room_id",
                sa.Integer(),
                sa.ForeignKey("rooms.id", ondelete="CASCADE"),
                nullable=True,
            ),
            sa.Column(
                "khach_thich", sa.Boolean(), nullable=False, server_default=sa.false()
            ),
            sa.Column("created_at", sa.DateTime(), nullable=False),
        )
        op.create_index(
            "ix_sale_yeu_cau_can_yeu_cau_id", "sale_yeu_cau_can", ["yeu_cau_id"]
        )

    if "sale_yeu_cau_moc" not in bang:
        op.create_table(
            "sale_yeu_cau_moc",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "yeu_cau_id",
                sa.Integer(),
                sa.ForeignKey("sale_yeu_cau.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("moc", sa.String(24), nullable=False),
            sa.Column("ghi_chu", sa.String(300), nullable=True),
            sa.Column(
                "boi_ai",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column("luc", sa.DateTime(), nullable=False),
        )
        op.create_index(
            "ix_sale_yeu_cau_moc_yeu_cau_id", "sale_yeu_cau_moc", ["yeu_cau_id"]
        )
        op.create_index("ix_sale_yeu_cau_moc_moc", "sale_yeu_cau_moc", ["moc"])
        op.create_index("ix_sale_yeu_cau_moc_luc", "sale_yeu_cau_moc", ["luc"])

    cols = {c["name"] for c in inspector.get_columns("sale_profiles")}
    if "hoa_hong_phan_tram" not in cols:
        op.add_column(
            "sale_profiles",
            sa.Column(
                "hoa_hong_phan_tram",
                sa.Integer(),
                nullable=False,
                server_default="50",
            ),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns("sale_profiles")}
    if "hoa_hong_phan_tram" in cols:
        op.drop_column("sale_profiles", "hoa_hong_phan_tram")
    bang = set(inspector.get_table_names())
    for ten in (
        "sale_yeu_cau_moc",
        "sale_yeu_cau_can",
        "sale_yeu_cau",
        "sale_khach",
    ):
        if ten in bang:
            op.drop_table(ten)
