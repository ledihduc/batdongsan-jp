"""realestate_services — thêm dịch vụ gắn với việc MUA BÁN nhà + thi công trọn gói

Danh mục cũ chỉ có sửa chữa và thi công. Nhưng app này là sàn bất động sản:
người dùng tới đây vì đang mua, đang bán, hoặc đang làm nhà — mà đúng những
việc quanh một giao dịch nhà đất lại không có dịch vụ nào.

Bảy dịch vụ thêm vào đều là việc CÓ THẬT quanh một thương vụ nhà đất ở Việt Nam:
định giá trước khi ra giá, sang tên sổ đỏ, vay ngân hàng, kiểm định trước khi
xuống tiền, chụp ảnh cho tin đăng, xem phong thuỷ, và dọn sửa để bán nhanh.
Thêm `turnkey` (thi công trọn gói) vào nhóm thi công.

GHI VÀO CẢ HAI BẢNG:
  * `construction_services` — bảng bản backend ĐANG CHẠY đọc.
  * `services`              — bảng mới của 0079, bản backend sắp tới đọc.
Chỉ ghi một bảng thì hoặc dịch vụ không hiện bây giờ, hoặc biến mất sau khi
deploy bản mới. Ghi cả hai là cách duy nhất không có khoảng mù.

Bất biến: additive · idempotent (bỏ qua slug đã có) · có downgrade.

Revision ID: 0080_realestate_services
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0080_realestate_services"
down_revision: Union[str, Sequence[str], None] = "0079_service_domain"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# (slug, tên, mô tả, icon, thứ tự, loại)
# `kind='quick'` cho tất cả: không dịch vụ nào trong số này có sàn nhà thầu —
# khách điền form, admin nhận rồi tự nối với đơn vị. Đặt nhầm 'marketplace' sẽ
# dẫn khách tới một danh bạ rỗng.
_MOI = [
    ("valuation", "Định giá nhà đất",
     "Định giá theo thị trường trước khi ra giá bán hoặc trả giá mua",
     "price_check", 30),
    ("legal_transfer", "Sang tên · Pháp lý",
     "Sang tên sổ đỏ, công chứng hợp đồng, kiểm tra pháp lý",
     "gavel", 31),
    ("home_loan", "Hỗ trợ vay mua nhà",
     "So sánh lãi suất, chuẩn bị hồ sơ, làm việc với ngân hàng",
     "account_balance", 32),
    ("inspection", "Kiểm định nhà",
     "Kiểm tra kết cấu, thấm dột, điện nước trước khi xuống tiền",
     "fact_check", 33),
    ("photo_listing", "Chụp ảnh · Quay video bán nhà",
     "Ảnh và video cho tin đăng, có flycam và ảnh 360",
     "photo_camera", 34),
    ("fengshui", "Xem phong thuỷ",
     "Xem hướng nhà, bố trí mặt bằng, chọn ngày",
     "explore", 35),
    ("staging", "Dọn sửa để bán nhanh",
     "Sơn dặm, dọn nhà, bày biện lại cho dễ bán",
     "auto_fix_high", 36),
    ("turnkey", "Thi công trọn gói",
     "Một đầu mối lo từ bản vẽ, xin phép, xây thô tới hoàn thiện",
     "handyman", 4),
]


def _ghi(bind, bang: str, co_kind: bool) -> None:
    da_co = {
        r[0] for r in bind.execute(sa.text(f"SELECT slug FROM {bang}")).fetchall()
    }
    for slug, ten, mo_ta, icon, thu_tu in [(a, b, c, d, e) for a, b, c, d, e in _MOI]:
        if slug in da_co:
            continue
        cot = "(slug, name, description, icon, sort_order, is_active"
        gt = "(:slug, :ten, :mo_ta, :icon, :thu_tu, true"
        if co_kind:
            cot += ", kind"
            gt += ", 'quick'"
        bind.execute(
            sa.text(f"INSERT INTO {bang} {cot}) VALUES {gt})"),
            {"slug": slug, "ten": ten, "mo_ta": mo_ta, "icon": icon,
             "thu_tu": thu_tu},
        )


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    bang_co = set(insp.get_table_names())
    for bang in ("construction_services", "services"):
        if bang not in bang_co:
            continue
        cols = {c["name"] for c in insp.get_columns(bang)}
        _ghi(bind, bang, co_kind="kind" in cols)


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    bang_co = set(insp.get_table_names())
    slugs = [s for s, *_ in _MOI]
    for bang in ("construction_services", "services"):
        if bang not in bang_co:
            continue
        # Không xoá dịch vụ đã có yêu cầu trỏ tới — xoá đi thì yêu cầu thật của
        # khách thành mồ côi, không tra ngược được tên dịch vụ.
        bind.execute(
            sa.text(
                f"DELETE FROM {bang} WHERE slug IN :slugs"
            ).bindparams(sa.bindparam("slugs", expanding=True)),
            {"slugs": slugs},
        )
