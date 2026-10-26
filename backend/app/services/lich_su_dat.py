"""LỊCH SỬ ĐƠN ĐẶT PHÒNG & LỊCH HẸN — ai làm gì, lúc nào (16/09/2026).

Một nguồn duy nhất: bảng `change_logs` sẵn có (`entity_type` = `reservation` |
`viewing_appointment`). Không thêm bảng — đơn phòng vốn đã ghi vào đây từ đầu,
chỉ là chưa ai đọc; lịch hẹn xem thì trước nay KHÔNG ghi gì, nên "tôi đã đổi
giờ rồi mà" / "sale xác nhận lúc nào" không có bằng chứng.

Hai hàm:

  * `ghi`  — mọi thao tác trên đơn/lịch gọi đúng một dòng này.
  * `doc`  — dịch các dòng thô thành câu người đọc được, gắn VAI người làm
             (Bạn / Khách / Sale X / Chủ nhà / Hệ thống) theo góc nhìn người xem.

Câu chữ nằm ở server để khách, sale, chủ nhà đọc cùng một phiên bản sự việc.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.repositories.audit import write_change_log

_VN = timezone(timedelta(hours=7))

DON = "reservation"
HEN = "viewing_appointment"

_HINH_THUC = {"theo_gio": "Theo giờ", "qua_dem": "Qua đêm", "theo_ngay": "Theo ngày"}

_NHAN_TRUONG = {
    "ten": "Họ tên",
    "sdt": "SĐT",
    "so_khach": "Số khách",
    "so_nguoi": "Số người",
    "ghi_chu": "Ghi chú",
    "loi_nhan": "Lời nhắn",
    "hinh_thuc": "Hình thức",
}

_TRANG_THAI_HEN = {
    "approved": ("Xác nhận lịch xem", "xac_nhan"),
    "rejected": ("Từ chối lịch xem", "tu_choi"),
    "completed": ("Đã đi xem xong", "xong"),
    "locked": ("Chốt thuê phòng", "xong"),
    "lost": ("Phòng đã có người khác chốt", "tu_choi"),
    "cancelled": ("Huỷ lịch hẹn", "huy"),
    "pending": ("Chuyển về chờ duyệt", "cho"),
}


def ghi(
    db: Session,
    loai: str,
    ma: int,
    hanh_dong: str,
    ai: Optional[int],
    truoc: Optional[dict] = None,
    sau: Optional[dict] = None,
) -> None:
    write_change_log(
        db,
        entity_type=loai,
        entity_id=ma,
        action=hanh_dong,
        before=truoc,
        after=sau,
        actor_id=ai,
    )


# ── Định dạng ────────────────────────────────────────────────────────────────


def _vn(dt) -> Optional[datetime]:
    """Giờ VN (naive) từ datetime naive-VN hoặc chuỗi ISO có múi giờ."""
    if dt is None:
        return None
    if isinstance(dt, datetime):
        return dt
    try:
        d = datetime.fromisoformat(str(dt).replace("Z", "+00:00"))
    except ValueError:
        return None
    if d.tzinfo is not None:
        d = d.astimezone(_VN).replace(tzinfo=None)
    return d


def _moc(dt) -> str:
    d = _vn(dt)
    return f"{d:%H:%M %d/%m}" if d else ""


def tien(n) -> str:
    try:
        return f"{int(round(float(n))):,}đ".replace(",", ".")
    except (TypeError, ValueError):
        return ""


def _gio(x: dict) -> str:
    """"14:00–16:00 16/09" trong ngày; "14:00 16/09 → 12:00 17/09" qua đêm."""
    nhan, tra = _vn(x.get("nhan")), _vn(x.get("tra"))
    if nhan is None:
        return ""
    if tra is None:
        return f"{nhan:%H:%M %d/%m}"
    if tra.date() == nhan.date():
        return f"{nhan:%H:%M}–{tra:%H:%M} {nhan:%d/%m}"
    return f"{nhan:%H:%M %d/%m} → {tra:%H:%M %d/%m}"


def _khoang(x: dict) -> str:
    if not x:
        return ""
    phan = [
        _HINH_THUC.get(x.get("hinh_thuc") or "", ""),
        _gio(x),
        tien(x["tong"]) if x.get("tong") is not None else "",
    ]
    return " · ".join(p for p in phan if p)


def _doi_khung(truoc: dict, sau: dict) -> str:
    """Chỉ nói phần ĐỔI — cùng hình thức/cùng giá thì không nhắc lại hai lần."""
    phan = []
    ht_cu, ht_moi = _HINH_THUC.get(truoc.get("hinh_thuc") or "", ""), _HINH_THUC.get(sau.get("hinh_thuc") or "", "")
    if ht_cu and ht_moi and ht_cu != ht_moi:
        phan.append(f"{ht_cu} → {ht_moi}")
    phan.append(f"{_gio(truoc) or '—'} → {_gio(sau) or '—'}")
    t_cu = tien(truoc["tong"]) if truoc.get("tong") is not None else ""
    t_moi = tien(sau["tong"]) if sau.get("tong") is not None else ""
    if t_cu and t_moi and t_cu != t_moi:
        phan.append(f"{t_cu} → {t_moi}")
    elif t_moi:
        phan.append(t_moi)
    return " · ".join(phan)


def _slot(x: dict) -> str:
    if not x or not x.get("ngay"):
        return ""
    gio = (x.get("gio") or "").split("-")[0]
    try:
        d = datetime.fromisoformat(x["ngay"])
        return f"{gio} {d:%d/%m}"
    except ValueError:
        return f"{gio} {x['ngay']}"


def _doi(truoc: dict, sau: dict) -> str:
    dong = []
    for k, v in sau.items():
        cu = truoc.get(k)
        if k == "hinh_thuc":
            cu, v = {"truc_tiep": "trực tiếp", "video": "video call"}.get(cu, cu), {
                "truc_tiep": "trực tiếp", "video": "video call"}.get(v, v)
        dong.append(f"{_NHAN_TRUONG.get(k, k)}: {cu or '—'} → {v or '—'}")
    return " · ".join(dong)


def _cau(loai: str, hanh_dong: str, truoc: dict, sau: dict) -> tuple[str, str, str]:
    """(tiêu đề, chi tiết, tông) — tông: dat | cho | xac_nhan | doi | tu_choi | huy | xong."""
    if loai == DON:
        if hanh_dong == "create":
            ct = _khoang(sau) or " · ".join(
                x for x in (sau.get("booking_code"), tien(sau.get("total_amount"))) if x
            )
            if sau.get("so_khach"):
                ct += f" · {sau['so_khach']} khách"
            return "Đặt phòng", ct, "dat"
        if hanh_dong == "approve":
            return "Xác nhận phòng", "Phòng được giữ cho bạn", "xac_nhan"
        if hanh_dong == "reject":
            return "Từ chối đơn", sau.get("reason") or "", "tu_choi"
        if hanh_dong == "check_in":
            return "Nhận phòng", "", "xong"
        if hanh_dong == "check_out":
            return "Trả phòng", "", "xong"
        if hanh_dong == "cancel":
            return "Huỷ đơn", sau.get("reason") or "", "huy"
        if hanh_dong == "doi_gio":
            return "Đổi giờ", _doi_khung(truoc, sau), "doi"
        if hanh_dong == "sua_thong_tin":
            return "Sửa thông tin", _doi(truoc, sau), "doi"
        if hanh_dong == "gia_han":
            return "Gia hạn", _khoang(sau), "doi"
    else:
        if hanh_dong == "create":
            phan = [
                _slot(sau),
                {"truc_tiep": "xem trực tiếp", "video": "xem qua video"}.get(sau.get("hinh_thuc"), ""),
                f"{sau['so_nguoi']} người" if (sau.get("so_nguoi") or 1) > 1 else "",
            ]
            tieu = "Hẹn gặp chốt phòng" if sau.get("loai") == "chot" else "Đặt lịch xem nhà"
            return tieu, " · ".join(p for p in phan if p), "dat"
        if hanh_dong == "status_change":
            tieu, tong = _TRANG_THAI_HEN.get(sau.get("status"), ("Đổi trạng thái", "doi"))
            return tieu, sau.get("ly_do") or "", tong
        if hanh_dong == "doi_gio":
            de_xuat = ", ".join(_slot(x) for x in (sau.get("de_xuat") or []))
            ct = f"Bận {_slot(truoc)}"
            if de_xuat:
                ct += f" · đề xuất {de_xuat}"
            if sau.get("ly_do"):
                ct += f" · “{sau['ly_do']}”"
            return "Bên bán bận · xin đổi giờ", ct, "doi"
        if hanh_dong == "chon_gio":
            duoi = "tự xác nhận (giờ bên bán đề xuất)" if sau.get("status") == "approved" else "chờ duyệt lại"
            return "Chọn giờ mới", f"{_slot(sau)} · {duoi}", "doi"
        if hanh_dong == "khach_doi_lich":
            return "Đổi lịch xem", f"{_slot(truoc)} ⟶ {_slot(sau)} · chờ duyệt lại", "doi"
        if hanh_dong == "sua_thong_tin":
            return "Sửa thông tin", _doi(truoc, sau), "doi"
    return hanh_dong, "", "doi"


# ── Vai người làm ────────────────────────────────────────────────────────────


def _vai_don(db: Session, res: models.Reservation) -> dict[int, str]:
    from app.services import sale_phu_trach  # noqa: PLC0415

    vai: dict[int, str] = {}
    room = db.get(models.Room, res.room_id)
    for uid in {res.host_id, sale_phu_trach.chu_cua_phong(db, room) if room else None} - {None}:
        vai[uid] = "chu_nha"
    if res.sale_id:
        vai[res.sale_id] = "sale"
    if res.guest_user_id:
        vai[res.guest_user_id] = "khach"
    return vai


def _vai_hen(db: Session, b: models.ViewingAppointment) -> dict[int, str]:
    from app.services.lich_xem_service import neo_cua  # noqa: PLC0415

    n = neo_cua(db, b)
    vai: dict[int, str] = {}
    for uid in (
        n.building.host_id if n.building is not None else None,
        n.chu_nha_id,
    ):
        if uid:
            vai[uid] = "chu_nha"
    if n.house is not None and n.house.host_id and n.house.host_id not in vai:
        vai[n.house.host_id] = "sale"
    if n.sale_id:
        vai[n.sale_id] = "sale"
    vai[b.guest_id] = "khach"
    return vai


def _ai(db: Session, uid: Optional[int], vai: dict[int, str], nguoi_xem: int) -> dict:
    if uid is None:
        return {"vai": "he_thong", "ten": "Hệ thống", "la_ban": False}
    u = db.get(models.User, uid)
    v = vai.get(uid, "quan_tri" if u is not None and u.role == "admin" else "khac")
    ten_that = (u.name if u is not None else "") or ""
    if uid == nguoi_xem:
        ten = "Bạn"
    elif v == "sale":
        ten = f"Sale {ten_that}".strip()
    elif v == "chu_nha":
        ten = "Chủ nhà"
    elif v == "khach":
        ten = f"Khách {ten_that}".strip()
    elif v == "quan_tri":
        ten = "Quản trị viên"
    else:
        ten = ten_that or "Người dùng"
    return {"vai": v, "ten": ten, "la_ban": uid == nguoi_xem}


def _json(s: Optional[str]) -> dict:
    try:
        v = json.loads(s) if s else {}
    except (TypeError, ValueError):
        return {}
    return v if isinstance(v, dict) else {}


def doc(db: Session, loai: str, doi_tuong, nguoi_xem: int) -> list[dict]:
    """Dòng thời gian MỚI NHẤT TRƯỚC — người ta mở ra để xem chuyện gì vừa xảy ra."""
    vai = _vai_don(db, doi_tuong) if loai == DON else _vai_hen(db, doi_tuong)
    q = db.query(models.ChangeLog).filter(
        models.ChangeLog.entity_type == loai, models.ChangeLog.entity_id == doi_tuong.id
    )
    # Id có thể bị dùng lại sau khi xoá bản ghi (sequence bị đặt lại khi nạp dữ
    # liệu mẫu) — dòng lịch sử CŨ HƠN chính đơn thì là của một đơn khác đã xoá.
    tao = getattr(doi_tuong, "created_at", None)
    if tao is not None:
        q = q.filter(models.ChangeLog.created_at >= tao - timedelta(seconds=5))
    rows = q.order_by(models.ChangeLog.created_at.desc(), models.ChangeLog.id.desc()).all()
    out = []
    for r in rows:
        truoc, sau = _json(r.before_json), _json(r.after_json)
        tieu, ct, tong = _cau(loai, r.action, truoc, sau)
        out.append({
            "luc": (r.created_at.isoformat() + "Z") if r.created_at else None,
            "hanh_dong": r.action,
            "tieu_de": tieu,
            "chi_tiet": ct,
            "tong": tong,
            "ai": _ai(db, r.actor_id, vai, nguoi_xem),
        })
    # Đơn/lịch có từ trước khi ghi lịch sử: vẫn phải có dòng "đã đặt" đầu tiên.
    if not any(e["hanh_dong"] == "create" for e in out):
        tao = getattr(doi_tuong, "created_at", None)
        chu = doi_tuong.guest_user_id if loai == DON else doi_tuong.guest_id
        out.append({
            "luc": (tao.isoformat() + "Z") if tao else None,
            "hanh_dong": "create",
            "tieu_de": "Đặt phòng" if loai == DON else "Đặt lịch xem nhà",
            "chi_tiet": "",
            "tong": "dat",
            "ai": _ai(db, chu, vai, nguoi_xem),
        })
    return out
