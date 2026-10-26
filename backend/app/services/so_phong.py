"""SỔ PHÒNG — mỗi phòng của một toà đang làm gì NGAY LÚC NÀY.

Phục vụ màn "Quản lí phòng" (bốn thẻ số, chip loại hình, thẻ phòng có tên khách
+ hạn hợp đồng) và màn "Hồ sơ phòng".

MỘT cách tính với Trang chủ chủ nhà — `tong_quan_chu_nha` gọi lại chính các
hàm ở đây: phòng "đang thuê" = có hợp đồng còn hiệu lực HOẶC có khách lưu trú
đang ở. Hai màn tự tính hai kiểu là "20 phòng đã thuê" ở Trang chủ nhưng bấm
vào toà lại ra "18".
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Callable, Iterable, Optional

from sqlalchemy.orm import Session

from app import models
from app.services.short_stay_service import local_now

DAI_HAN = ("dai_han",)
KINH_DOANH = ("mat_bang",)
NGAN_HAN = ("ngan_han",)

#: Hợp đồng còn chừng này ngày nữa là hết → "Sắp trả". Cùng mốc 30 ngày với
#: cảnh báo hợp đồng sắp hết ở trang chủ nhà.
SAP_TRA_NGAY = 30

#: Còn chừng này ngày tới hạn đóng tiền tháng thì tô cam.
SAP_DONG_TIEN_NGAY = 3


def _tien(v: float) -> str:
    return f"{int(round(v)):,}".replace(",", ".") + "đ"


def _ngay(v) -> Optional[date]:
    try:
        return date.fromisoformat(str(v)[:10]) if v else None
    except ValueError:
        return None


def no_hoa_don(db: Session, contract_ids: list[int]) -> dict[int, list[models.Invoice]]:
    """Hoá đơn ĐÃ GỬI mà chưa thu đủ, theo hợp đồng. Nháp chưa gửi thì khách
    chưa nợ gì — không tính."""
    ra: dict[int, list[models.Invoice]] = {}
    if not contract_ids:
        return ra
    for i in (
        db.query(models.Invoice)
        .filter(
            models.Invoice.contract_id.in_(contract_ids),
            models.Invoice.status.in_(("sent", "overdue")),
        )
        .all()
    ):
        if (i.total_amount or 0) - (i.paid_amount or 0) > 0:
            ra.setdefault(i.contract_id, []).append(i)
    return ra


def han_dong_tien(
    c: models.Contract, no: list[models.Invoice], hom_nay: date
) -> Optional[date]:
    """NGÀY phải thu tiếp theo của hợp đồng — cùng luật với `dong_tien_thang`.

    Chữ "Đóng tiền 05/10 · còn 12 ngày" đọc được nhưng không xếp lịch được;
    màn quản lý toà cần đúng cái NGÀY để trộn vào dòng thời gian "Sắp tới".
    """
    from app.services.invoice_service import han_dong_hoa_don

    han = min((_ngay(i.due_date) for i in no if _ngay(i.due_date)), default=None)
    if han is not None:
        return han
    if not c.ngay_thanh_toan:
        return None
    return han_dong_hoa_don(c.ngay_thanh_toan, hom_nay)


def dong_tien_thang(
    c: models.Contract, no: list[models.Invoice], hom_nay: date
) -> tuple[str, str]:
    """Dòng TIỀN THÁNG của thẻ phòng: `(chữ, mức)`, mức ∈ xam · cam · do.

    Thứ tự ưu tiên là thứ tự chủ nhà cần biết:
      1. có hoá đơn QUÁ HẠN chưa thu → đỏ, kèm số tiền nợ;
      2. có hoá đơn đã gửi, chưa tới hạn → đếm ngược tới hạn hoá đơn đó;
      3. chưa có hoá đơn kỳ này → đếm ngược tới ngày thu tiền hằng tháng của
         hợp đồng (cùng hàm tính hạn với màn lập hoá đơn, để hai màn không lệch).
    """
    from app.services.invoice_service import han_dong_hoa_don

    qua_han = [i for i in no if (_ngay(i.due_date) or hom_nay) < hom_nay]
    if qua_han:
        tong = sum((i.total_amount or 0) - (i.paid_amount or 0) for i in qua_han)
        lau = max((hom_nay - _ngay(i.due_date)).days for i in qua_han)
        return f"Nợ {_tien(tong)} · quá hạn {lau} ngày", "do"
    han = min((_ngay(i.due_date) for i in no if _ngay(i.due_date)), default=None)
    if han is None:
        if not c.ngay_thanh_toan:
            return "Chưa đặt ngày thu tiền", "xam"
        han = han_dong_hoa_don(c.ngay_thanh_toan, hom_nay)
    con = (han - hom_nay).days
    if con <= 0:
        return "Hôm nay đóng tiền", "cam"
    return f"Đóng tiền {han:%d/%m} · còn {con} ngày", ("cam" if con <= SAP_DONG_TIEN_NGAY else "xam")

#: Khối → kênh mang giá hiện trên thẻ phòng.
_KENH_CUA_KHOI = {"dai": "dai_han", "kd": "mat_bang", "ngan": "ngan_han"}
#: Khối → nhãn chip lọc. Cùng bộ nhãn với thẻ toà ở Trang chủ.
_NHAN_KHOI = {"dai": "dai_han", "kd": "kinh_doanh", "ngan": "ngan_han"}


def duoc_xem_tai_chinh(
    room: models.Room, chu_toa_id: Optional[int], uid: int, la_admin: bool
) -> bool:
    """Ai được thấy NGƯỜI và TIỀN của phòng: tên khách, SĐT, hợp đồng, hoá đơn.

    Cùng luật `QuyenPhong.tai_chinh`: admin, hoặc chủ phòng — `rooms.owner_id`,
    chưa gán thì chủ toà. Sale phụ trách thấy phòng có người, không thấy là ai,
    trả bao nhiêu. Một chỗ duy nhất cho sổ phòng và hồ sơ phòng: hai nơi tự viết
    luật này là một ngày nào đó sale đọc được SĐT khách ở một trong hai.
    """
    if la_admin:
        return True
    chu = room.owner_id if room.owner_id is not None else chu_toa_id
    return chu is not None and chu == uid


def kenh_dang_bat(
    db: Session, room_ids: list[int]
) -> dict[int, dict[str, models.RoomKenh]]:
    """Kênh đang bật của từng phòng: `{room_id: {kenh: RoomKenh}}`."""
    ra: dict[int, dict[str, models.RoomKenh]] = {}
    if not room_ids:
        return ra
    for k in (
        db.query(models.RoomKenh)
        .filter(
            models.RoomKenh.room_id.in_(room_ids),
            models.RoomKenh.dang_bat.is_(True),
        )
        .all()
    ):
        ra.setdefault(k.room_id, {})[k.kenh] = k
    return ra


def hop_dong_hieu_luc(db: Session, room_ids: list[int]) -> dict[int, models.Contract]:
    """Hợp đồng `active` của từng phòng. Lỡ có hai thì lấy cái bắt đầu sau."""
    ra: dict[int, models.Contract] = {}
    if not room_ids:
        return ra
    for c in (
        db.query(models.Contract)
        .filter(
            models.Contract.room_id.in_(room_ids),
            models.Contract.status == "active",
        )
        .order_by(models.Contract.start_date, models.Contract.id)
        .all()
    ):
        ra[c.room_id] = c
    return ra


def khach_dang_o(
    db: Session, room_ids: list[int], now: datetime
) -> dict[int, models.Reservation]:
    """Đơn lưu trú có khách ĐANG Ở NGAY LÚC NÀY, không phải có đơn trong ngày.

    Đơn theo giờ 14–17h thì 18h phòng đã trống lại.
    """
    ra: dict[int, models.Reservation] = {}
    if not room_ids:
        return ra
    for r in (
        db.query(models.Reservation)
        .filter(
            models.Reservation.room_id.in_(room_ids),
            models.Reservation.status.in_(("approved", "checked_in")),
        )
        .all()
    ):
        vao, ra_luc = r.check_in_at, r.check_out_at
        if r.status == "checked_in" or (vao and ra_luc and vao <= now < ra_luc):
            ra[r.room_id] = r
    return ra


def xep_khoi(kenh: Iterable[str], co_hop_dong: bool) -> Optional[str]:
    """Khối của một phòng: 'dai' | 'kd' | 'ngan' | None.

    Mỗi phòng vào ĐÚNG MỘT khối. Một phòng chạy nhiều kênh cùng lúc là ca dùng
    chính của `room_kenh` (có khách dài thì thuê dài, trống thì chạy theo đêm).
    Xếp theo từng kênh thì phòng đó bị đếm ở cả hai khối và tổng các khối lớn
    hơn số phòng thật. Nên xếp theo việc phòng ĐANG làm.

    Phòng dài hạn = đang rao dài hạn HOẶC đang có hợp đồng (hợp đồng ký rồi thì
    kênh có thể đã đóng, nhưng phòng vẫn là phòng dài hạn đang cho thuê).
    """
    ks = set(kenh)
    if co_hop_dong:
        return "kd" if (ks & set(KINH_DOANH)) and not (ks & set(DAI_HAN)) else "dai"
    if ks & set(NGAN_HAN):
        return "ngan"
    if ks & set(DAI_HAN):
        return "dai"
    if ks & set(KINH_DOANH):
        return "kd"
    return None  # chỉ rao bán / chưa bật kênh nào: không thuộc khối thuê


def khach_chinh(db: Session, contract_ids: list[int]) -> dict[int, models.Tenant]:
    """Người đứng tên của từng hợp đồng, trong số người còn ở.

    Không ai được đánh dấu chính thì lấy người được ghi vào sổ trước (bảng nối
    không có cột id — khoá là cặp hợp đồng + khách).
    """
    ra: dict[int, models.Tenant] = {}
    if not contract_ids:
        return ra
    co_chinh: set[int] = set()
    for cid, chinh, t in (
        db.query(
            models.ContractTenant.contract_id,
            models.ContractTenant.is_primary,
            models.Tenant,
        )
        .join(models.Tenant, models.Tenant.id == models.ContractTenant.tenant_id)
        .filter(
            models.ContractTenant.contract_id.in_(contract_ids),
            models.ContractTenant.left_at.is_(None),
        )
        .order_by(models.ContractTenant.tenant_id)
        .all()
    ):
        if cid in co_chinh or not (t.full_name or "").strip():
            continue
        if chinh:
            ra[cid] = t
            co_chinh.add(cid)
        elif cid not in ra:
            ra[cid] = t
    return ra


def tinh_trang_phong(
    db: Session,
    phong: list[models.Room],
    *,
    duoc_xem_khach: Callable[[models.Room], bool],
    now: Optional[datetime] = None,
) -> dict[int, dict]:
    """Thông tin sổ phòng của từng phòng trong `phong` (nên là MỌI phòng của toà).

    * `tinh_trang`: 'dang_o' | 'sap_tra' | 'sap_vao' | 'trong' | 'bao_tri'. Có
      người ở thắng mọi thứ, kể cả cờ bảo trì còn sót — phòng đang có người mà
      in "Bảo trì" là sai. 'sap_tra' = hợp đồng còn ≤ `SAP_TRA_NGAY` ngày, vẫn
      là đang thuê. 'sap_vao' = hợp đồng đã ký nhưng CHƯA tới ngày vào ở — phòng
      chưa có ai (trước 19/09/2026 in nhầm "Đang ở").
    * `dong_tien` + `dong_tien_muc`: dòng tiền tháng — xem `dong_tien_thang`.
      Chỉ khi `duoc_xem_khach` (sale không thấy tiền của hợp đồng).
    * `loai`: nhãn chip lọc, cùng luật nhãn toà ở Trang chủ.
    * `gia_kenh` + `don_vi` + `loai_phong`: của kênh phòng đang chạy — phòng
      ngắn hạn tính theo đêm, mặt bằng theo m²/tháng; in "/tháng" cho mọi phòng
      là sai.
    * `khach_thue` / `hop_dong_den` / `tra_phong_luc`: chỉ khi
      `duoc_xem_khach(phong)` — xem `duoc_xem_tai_chinh`.
    """
    now = now or local_now()
    moc_sap_tra = (now.date() + timedelta(days=SAP_TRA_NGAY)).isoformat()
    ids = [p.id for p in phong]
    kenh = kenh_dang_bat(db, ids)
    hop_dong = hop_dong_hieu_luc(db, ids)
    luu_tru = khach_dang_o(db, ids, now)
    xep = {p.id: xep_khoi(kenh.get(p.id, {}), p.id in hop_dong) for p in phong}

    khoi_cua_toa: dict[int, set[str]] = {}
    for p in phong:
        if xep[p.id]:
            khoi_cua_toa.setdefault(p.building_id, set()).add(xep[p.id])

    xem = {p.id: bool(duoc_xem_khach(p)) for p in phong}
    khach = khach_chinh(db, [c.id for rid, c in hop_dong.items() if xem[rid]])
    no = no_hoa_don(db, [c.id for rid, c in hop_dong.items() if xem[rid]])
    hom_nay = now.date()

    ra: dict[int, dict] = {}
    for p in phong:
        k = xep[p.id]
        loai = [_NHAN_KHOI[k]] if k else []
        if k == "ngan" and khoi_cua_toa.get(p.building_id) == {"ngan"}:
            # Mọi phòng đang khai thác của toà đều là lưu trú ngắn hạn → vận
            # hành như khách sạn.
            loai.append("khach_san")

        c = hop_dong.get(p.id)
        o = luu_tru.get(p.id)
        het = ((c.actual_end_date or c.end_date or "")[:10] or None) if c else None
        vao = _ngay(c.start_date) if c is not None else None
        if c is not None and vao is not None and vao > hom_nay:
            tinh_trang = "sap_vao"
        elif c is not None:
            tinh_trang = "sap_tra" if het and het <= moc_sap_tra else "dang_o"
        elif o is not None:
            tinh_trang = "dang_o"
        elif p.status == "maintenance":
            tinh_trang = "bao_tri"
        else:
            tinh_trang = "trong"

        kr = kenh.get(p.id, {}).get(_KENH_CUA_KHOI.get(k or "", ""))
        muc = {
            "tinh_trang": tinh_trang,
            "loai": loai,
            "gia_kenh": kr.gia if kr is not None else None,
            "don_vi": kr.don_vi if kr is not None else None,
            "loai_phong": kr.loai_phong if kr is not None else None,
            "khach_thue": None,
            "hop_dong_tu": None,
            "hop_dong_den": None,
            "tra_phong_luc": None,
            "dong_tien": None,
            "dong_tien_muc": None,
            "dong_tien_ngay": None,
        }
        if xem[p.id]:
            if c is not None:
                t = khach.get(c.id)
                muc["khach_thue"] = t.full_name if t is not None else None
                muc["hop_dong_tu"] = vao.isoformat() if vao is not None else None
                muc["hop_dong_den"] = het
                han = han_dong_tien(c, no.get(c.id, []), hom_nay)
                muc["dong_tien_ngay"] = han.isoformat() if han is not None else None
                if tinh_trang == "sap_vao":
                    muc["dong_tien"] = f"Vào ở {vao:%d/%m} · còn {(vao - hom_nay).days} ngày"
                    muc["dong_tien_muc"] = "xam"
                else:
                    muc["dong_tien"], muc["dong_tien_muc"] = dong_tien_thang(
                        c, no.get(c.id, []), hom_nay
                    )
            elif o is not None:
                muc["khach_thue"] = o.guest_name or None
                muc["tra_phong_luc"] = o.check_out_at
        ra[p.id] = muc
    return ra
