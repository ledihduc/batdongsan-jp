"""KHÁCH SỬA ĐƠN ĐẶT PHÒNG & LỊCH HẸN SAU KHI ĐẶT (16/09/2026).

Trước đây đặt xong là "đóng băng": muốn đổi giờ phải huỷ rồi đặt lại — mất giờ
đã giữ, sale nhận hai thông báo rời rạc và không biết hai đơn là một người.

Luật (xem docs/PLAN-DA-DAT.md ở app):

  * Đơn phòng — đổi giờ khi `pending`/`approved` VÀ còn hạn huỷ miễn phí; xét
    trùng lịch BỎ QUA chính đơn mình (kéo dài 2h→3h không tự đụng); đổi xong về
    `pending` chờ sale xác nhận lại. Sửa tên/SĐT/số khách/ghi chú khi còn mở.
  * Lịch xem — khách tự đổi khung khi `pending`/`approved` → `pending`. Sửa tên/
    SĐT/số người/hình thức/lời nhắn khi `pending`/`approved`/`doi_gio`.

Mọi lần sửa: một dòng lịch sử (`lich_su_dat`) + báo sale và chủ nhà.
"""

from __future__ import annotations

import json
import re
from datetime import time, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import helpers, models
from app.services import booking_slot_service as slots
from app.services import chiem_dung_service, lich_su_dat, phieu_hen_xem, sale_phu_trach
from app.services import short_stay_service as stays
from app.services.lich_xem_service import neo_cua

DON_MO = ("pending", "approved")
HEN_SUA_DUOC = ("pending", "approved", "doi_gio")
HEN_DOI_LICH_DUOC = ("pending", "approved")


def _sdt(s: str) -> str:
    so = re.sub(r"\D", "", s or "")
    if not 9 <= len(so) <= 11:
        raise HTTPException(422, "Số điện thoại chưa đúng")
    return (s or "").strip()


def _ten(s: str) -> str:
    t = (s or "").strip()
    if len(t) < 2:
        raise HTTPException(422, "Họ tên quá ngắn")
    return t[:300]


def _bao_van_hanh(db: Session, res: models.Reservation, tieu_de: str, noi_dung: str) -> None:
    room = db.get(models.Room, res.room_id)
    for uid in {res.host_id, res.sale_id or sale_phu_trach.sale_cua_phong(db, room)} - {None, res.guest_user_id}:
        db.add(models.Notification(
            user_id=uid,
            type=stays.LOAI_VAN_HANH,
            title=tieu_de,
            body=noi_dung,
            related_id=res.id,
            channel="in_app",
            delivery_status="delivered",
        ))


# ── Đơn phòng ────────────────────────────────────────────────────────────────


def sua_don(db: Session, res: models.Reservation, uid: int, thay: dict) -> dict:
    """Trả {truong: (cũ, mới)} đã đổi. Không đổi gì → không ghi lịch sử."""
    if res.status not in DON_MO:
        raise HTTPException(409, "Đơn này không còn sửa được")
    room = db.get(models.Room, res.room_id)
    truoc: dict = {}
    sau: dict = {}

    def dat(khoa: str, cu, moi, gan):
        if moi is not None and moi != cu:
            truoc[khoa], sau[khoa] = cu, moi
            gan(moi)

    if thay.get("guest_name") is not None:
        dat("ten", res.guest_name, _ten(thay["guest_name"]), lambda v: setattr(res, "guest_name", v))
    if thay.get("guest_phone") is not None:
        dat("sdt", res.guest_phone, _sdt(thay["guest_phone"]), lambda v: setattr(res, "guest_phone", v))
    if thay.get("so_khach") is not None:
        so = int(thay["so_khach"])
        if so < 1:
            raise HTTPException(422, "Số khách phải từ 1 người")
        if room is not None and room.capacity and so > room.capacity:
            raise HTTPException(422, f"Phòng này ở tối đa {room.capacity} khách")
        dat("so_khach", res.so_khach, so, lambda v: setattr(res, "so_khach", v))
    if thay.get("note") is not None:
        dat("ghi_chu", res.note or "", str(thay["note"]).strip()[:300], lambda v: setattr(res, "note", v))

    if sau:
        lich_su_dat.ghi(db, lich_su_dat.DON, res.id, "sua_thong_tin", uid, truoc, sau)
        _bao_van_hanh(
            db,
            res,
            f"Đơn {res.booking_code} · khách sửa thông tin",
            " · ".join(
                f"{lich_su_dat._NHAN_TRUONG.get(k, k)}: {truoc[k] or '—'} → {v or '—'}"
                for k, v in sau.items()
            ),
        )
    return sau


def _gac_doi_gio(res: models.Reservation) -> None:
    if not res.booking_mode:
        raise HTTPException(409, "Đơn này không đổi giờ trong app được")
    if res.status not in DON_MO:
        raise HTTPException(409, "Đơn này không còn đổi giờ được")
    if not stays.cancellation(res):
        raise HTTPException(
            409, "Đã quá hạn đổi giờ miễn phí. Vui lòng gọi sale để được hỗ trợ"
        )


def bao_gia_doi_gio(db: Session, res: models.Reservation, mode: str, start, end) -> dict:
    _gac_doi_gio(res)
    return stays.quote(db, res.room_id, mode, start, end, bo_qua=res.id)


def _khung(res: models.Reservation) -> dict:
    return {
        "hinh_thuc": res.booking_mode,
        "nhan": stays.iso(res.check_in_at),
        "tra": stays.iso(res.check_out_at),
        "tong": res.total_amount,
    }


def doi_gio_don(
    db: Session,
    res: models.Reservation,
    uid: int,
    mode: str,
    start,
    end,
    quote_token: str,
) -> models.Reservation:
    _gac_doi_gio(res)
    q = stays.quote(db, res.room_id, mode, start, end, bo_qua=res.id)
    if quote_token != q["quote_token"]:
        raise HTTPException(
            409, "Giá hoặc chính sách đã thay đổi. Vui lòng xem lại giá trước khi xác nhận"
        )
    truoc = _khung(res)
    ci, co = stays.local_time(q["check_in_at"]), stays.local_time(q["check_out_at"])
    ceiling = co.date() + (timedelta(days=1) if co.time() != time() else timedelta())
    if (ci, co, mode) == (res.check_in_at, res.check_out_at, res.booking_mode):
        return res
    try:
        chiem_dung_service.ghi(
            db,
            room_id=res.room_id,
            tu_ngay=ci.date(),
            den_ngay=ceiling,
            tu_luc=ci,
            den_luc=co,
            kenh="ngan_han",
            nguon=models.RoomChiemDung.RESERVATION,
            nguon_id=res.id,
        )
    except chiem_dung_service.TrungLich as exc:
        raise HTTPException(409, "Phòng vừa có lịch trong giờ mới. Vui lòng chọn giờ khác") from exc

    policy = json.loads(res.cancel_policy_snapshot or "{}")
    policy.update({
        "free_cancel_hours": q["free_cancel_hours"],
        "free_cancel_until": q["free_cancel_until"],
        "text": q["cancellation_policy"],
    })
    res.booking_mode = mode
    res.check_in_at, res.check_out_at = ci, co
    res.check_in_date, res.check_out_date = ci.date().isoformat(), ceiling.isoformat()
    res.nights = max(1, (co.date() - ci.date()).days)
    res.total_amount = q["total_amount"]
    res.price_snapshot = json.dumps(q, ensure_ascii=False)
    res.cancel_policy_snapshot = json.dumps(policy, ensure_ascii=False)
    # Giờ mới chưa ai hứa giữ — sale/chủ nhà phải xác nhận lại.
    res.status = "pending"
    sau = _khung(res)
    lich_su_dat.ghi(db, lich_su_dat.DON, res.id, "doi_gio", uid, truoc, sau)
    room = db.get(models.Room, res.room_id)
    _bao_van_hanh(
        db,
        res,
        f"Khách đổi giờ · {res.booking_code} · chờ xác nhận lại",
        f"{res.guest_name} · Phòng {room.code if room else ''} · "
        f"{lich_su_dat._khoang(truoc)} ⟶ {lich_su_dat._khoang(sau)}",
    )
    return res


# ── Lịch hẹn xem ─────────────────────────────────────────────────────────────


def _bao_ben_ban(db: Session, b: models.ViewingAppointment, tieu_de: str, noi_dung: str) -> None:
    n = neo_cua(db, b)
    for uid in {n.sale_id, n.chu_nha_id} - {None, b.guest_id}:
        helpers.push_notification(
            db,
            uid,
            "viewing_appointment_requested",
            tieu_de,
            noi_dung,
            n.house.id if n.house is not None else None,
        )


def sua_hen(db: Session, b: models.ViewingAppointment, uid: int, thay: dict) -> dict:
    if b.status not in HEN_SUA_DUOC:
        raise HTTPException(409, "Lịch này không còn sửa được")
    truoc: dict = {}
    sau: dict = {}

    def dat(khoa, cu, moi, cot):
        if moi is not None and moi != cu:
            truoc[khoa], sau[khoa] = cu, moi
            setattr(b, cot, moi)

    if thay.get("ten_khach") is not None:
        dat("ten", b.ten_khach, _ten(thay["ten_khach"]), "ten_khach")
    if thay.get("sdt_khach") is not None:
        dat("sdt", b.sdt_khach, _sdt(thay["sdt_khach"]), "sdt_khach")
    if thay.get("so_nguoi") is not None:
        so = int(thay["so_nguoi"])
        if not 1 <= so <= phieu_hen_xem.SO_NGUOI_TOI_DA:
            raise HTTPException(422, f"Số người từ 1 đến {phieu_hen_xem.SO_NGUOI_TOI_DA}")
        dat("so_nguoi", b.so_nguoi or 1, so, "so_nguoi")
    if thay.get("hinh_thuc") is not None:
        ht = str(thay["hinh_thuc"])
        if ht not in phieu_hen_xem.HINH_THUC:
            raise HTTPException(422, "Hình thức xem không hợp lệ")
        dat("hinh_thuc", b.hinh_thuc or "truc_tiep", ht, "hinh_thuc")
    if thay.get("message") is not None:
        dat("loi_nhan", b.message or "", str(thay["message"]).strip()[:500], "message")

    if sau:
        lich_su_dat.ghi(db, lich_su_dat.HEN, b.id, "sua_thong_tin", uid, truoc, sau)
        _bao_ben_ban(
            db,
            b,
            "Khách sửa thông tin lịch xem",
            f"Phiếu {phieu_hen_xem.ma_phieu(b.id)} · "
            + " · ".join(
                f"{lich_su_dat._NHAN_TRUONG.get(k, k)}: {truoc[k] or '—'} → {v or '—'}"
                for k, v in sau.items()
            ),
        )
    return sau


def khach_doi_lich(db: Session, b: models.ViewingAppointment, uid: int, ngay: str, gio: str) -> None:
    if b.status not in HEN_DOI_LICH_DUOC:
        raise HTTPException(409, "Lịch này không còn đổi được")
    gio = slots.normalize_slot(gio)
    if (ngay, gio) == (b.booking_date, slots.normalize_slot(b.booking_time)):
        return
    n = neo_cua(db, b)
    loi = slots.validate_booking(db, n.house, ngay, gio, room_id=n.room.id if n.room else None)
    if loi:
        raise HTTPException(
            409 if loi == "slot_taken" else 422,
            "Giờ này vừa có người đặt, vui lòng chọn giờ khác"
            if loi == "slot_taken"
            else "Giờ này không đặt được",
        )
    truoc = {"ngay": b.booking_date, "gio": b.booking_time}
    b.booking_date, b.booking_time = ngay, gio
    b.status = "pending"
    lich_su_dat.ghi(db, lich_su_dat.HEN, b.id, "khach_doi_lich", uid, truoc, {"ngay": ngay, "gio": gio})
    _bao_ben_ban(
        db,
        b,
        "Khách đổi lịch xem · chờ duyệt lại",
        f'{b.ten_khach or "Khách"} đổi "{n.ten}" từ {lich_su_dat._slot(truoc)} sang '
        f"{lich_su_dat._slot({'ngay': ngay, 'gio': gio})} · phiếu {phieu_hen_xem.ma_phieu(b.id)}.",
    )
