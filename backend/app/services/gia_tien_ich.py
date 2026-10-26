"""Giá điện · nước · dịch vụ của một phòng — MỘT chỗ giải quyết duy nhất.

Ba tầng, ưu tiên từ hẹp tới rộng:

    phòng khai riêng  →  toà khai chung  →  hằng số của hệ thống

Vì sao gom về một tệp: thứ tự này sẽ được đọc ở ít nhất bốn chỗ (sinh hoá đơn
hàng tháng, hoá đơn trả phòng, màn chi tiết phòng, trang dự án công khai). Viết
lại `a or b or c` ở từng chỗ chính là cách sinh ra hai câu trả lời khác nhau cho
cùng một câu hỏi — và lúc lệch nhau thì hoá đơn nói một giá, app nói một giá.

**`None` khác `0`.** `0` nghĩa là MIỄN PHÍ (rất nhiều nhà trọ bao nước); `None`
nghĩa là chưa khai, lấy theo tầng trên. Nên ở đây phải hỏi `is None`, KHÔNG được
dùng `or` — `0 or 15000` ra 15000, tức là phòng bao nước vẫn bị tính tiền nước.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy.orm import Session

from app import models

#: Hằng số cuối cùng, dùng khi cả phòng lẫn toà đều chưa khai. Trùng với mặc
#: định cũ của `GenerateBatchRequest` để hoá đơn của toà chưa khai gì không đổi
#: số so với trước migration 0104.
GIA_DIEN_MAC_DINH = 3500.0
GIA_NUOC_MAC_DINH = 15000.0
PHI_DICH_VU_MAC_DINH = 0.0


def _lay(
    db: Session,
    room: Optional[models.Room],
    ten_cot: str,
    mac_dinh: float,
) -> float:
    if room is None:
        return mac_dinh

    cua_phong = getattr(room, ten_cot, None)
    if cua_phong is not None:
        return float(cua_phong)

    toa = (
        db.query(models.Building)
        .filter(models.Building.id == room.building_id)
        .first()
    )
    cua_toa = getattr(toa, ten_cot, None) if toa is not None else None
    if cua_toa is not None:
        return float(cua_toa)

    return mac_dinh


def gia_dien(db: Session, room: Optional[models.Room]) -> float:
    """Đơn giá điện đ/kWh có hiệu lực cho phòng này."""
    return _lay(db, room, "gia_dien", GIA_DIEN_MAC_DINH)


def gia_nuoc(db: Session, room: Optional[models.Room]) -> float:
    """Đơn giá nước đ/m³ có hiệu lực cho phòng này."""
    return _lay(db, room, "gia_nuoc", GIA_NUOC_MAC_DINH)


def phi_dich_vu(db: Session, room: Optional[models.Room]) -> float:
    """Phí dịch vụ đ/tháng có hiệu lực cho phòng này.

    Mặc định 0 chứ không phải một con số bịa: thu tiền của người thuê vì một
    khoản chưa ai khai là chuyện không được phép xảy ra.
    """
    return _lay(db, room, "phi_dich_vu", PHI_DICH_VU_MAC_DINH)


# ── Tính THEO NGƯỜI (migration 0136) ─────────────────────────────────────────

THEO_NGUOI = "theo_nguoi"
DON_GIA = "don_gia"


def nuoc_theo_nguoi(room: Optional[models.Room]) -> bool:
    """Nước của phòng tính theo đầu người (gia_nuoc = đ/người/tháng)."""
    return bool(getattr(room, "nuoc_theo_nguoi", None))


def so_nguoi(db: Session, contract: Optional[models.Contract]) -> int:
    """Số người ở để nhân với khoản tính theo người.

    Chủ nhà khai `contracts.so_nguoi_o` thì lấy đúng số đó; chưa khai thì đếm
    người còn ở trên hợp đồng. Tối thiểu 1 — phòng đang có hợp đồng thì có ít
    nhất một người ở.
    """
    if contract is None:
        return 0
    if contract.so_nguoi_o:
        return max(1, int(contract.so_nguoi_o))
    from sqlalchemy import func

    n = (
        db.query(func.count(models.ContractTenant.tenant_id))
        .filter(
            models.ContractTenant.contract_id == contract.id,
            models.ContractTenant.left_at.is_(None),
        )
        .scalar()
    )
    return max(1, int(n or 0))
