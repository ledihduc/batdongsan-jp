"""Tài khoản nhận tiền theo TOÀ và PHÒNG — khách chuyển khoản / quét VietQR trong app.

Chủ dự án (14/10/2026): chủ nhà nhập số tài khoản vào tòa hoặc phòng để khách
chuyển khoản luôn qua app. Trước đây chỉ có ở hồ sơ chủ nhà (host_profiles) và
không màn nào của Sổ chủ nhà cho nhập → 0/11 hồ sơ có số tài khoản.

Hai tầng như giá điện (mig 0104): phòng → toà → hồ sơ chủ nhà. NULL = chưa khai,
dùng tầng trên. `tk_ngan_hang` là BIN NAPAS 6 số (để sinh VietQR).

Additive, nullable, idempotent.

Revision ID: 0139_tai_khoan_nhan_tien
Revises: 0138_giay_to_hop_dong
"""

from alembic import op
import sqlalchemy as sa

revision = "0139_tai_khoan_nhan_tien"
down_revision = "0138_giay_to_hop_dong"
branch_labels = None
depends_on = None

_COT = ("tk_ngan_hang", 10), ("tk_so", 30), ("tk_chu", 100)
_BANG = ("buildings", "rooms")


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    for bang in _BANG:
        co = {c["name"] for c in insp.get_columns(bang)}
        for ten, dai in _COT:
            if ten not in co:
                op.add_column(bang, sa.Column(ten, sa.String(dai), nullable=True))


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    for bang in _BANG:
        co = {c["name"] for c in insp.get_columns(bang)}
        for ten, _ in _COT:
            if ten in co:
                op.drop_column(bang, ten)
