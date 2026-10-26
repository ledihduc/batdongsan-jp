"""Xác minh chủ nhà — CCCD hai mặt (+ giấy phép kinh doanh nếu có), admin duyệt.

14/10/2026 chiều chủ dự án chốt lại: CCCD chỉ để TỰ XÁC THỰC thông tin, không
cần eKYC (bỏ bắt buộc ảnh chân dung); giấy phép kinh doanh bỏ trống được nhưng
có cảnh báo. Endpoint ảnh chân dung vẫn nhận (không bắt buộc) để app cũ không lỗi.

Chủ dự án (14/10/2026): "ekyc up giấy tờ cho chủ nhà (giấy tờ kd, cccd), tạo
link ekyc trực tuyến trên app, lưu ảnh về và admin duyệt".

Luồng:
  1. Chủ nhà mở màn eKYC trong app (đã đăng nhập) — hoặc bấm "Làm trên điện
     thoại" để nhận LINK `/ekyc?t=<token>`: mở link trên máy có camera là chụp
     được, không cần đăng nhập lại; token chỉ mở đúng hồ sơ eKYC của người tạo,
     hết hạn sau 24 giờ.
  2. Chụp / tải từng ảnh → kho NHẠY CẢM (`sensitive_file_service`, ghi nhật ký
     truy cập), không bao giờ qua `/uploads` công khai.
  3. Nộp → chép sang `operator_business_profiles` (status 'pending'): admin
     duyệt ở hàng đợi KYC v2 sẵn có (xem ảnh qua link ký 5 phút, có lý do).
  4. Duyệt / từ chối ở đó gọi `sau_khi_admin_xet` → cập nhật bản eKYC +
     `host_profiles.verified` + báo chủ nhà.

Chưa tích hợp nhà cung cấp eKYC (OCR / so khuôn mặt / liveness): admin đối
chiếu ảnh chân dung với ảnh CCCD bằng mắt. Thêm nhà cung cấp sau thì chen vào
bước 3, trước khi đẩy sang hàng đợi.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import os
import re
import secrets
from datetime import datetime, timedelta
from typing import Optional

import bcrypt
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import helpers, models
from app.domain.operator_business import OperatorBusinessProfile
from app.models.host import EkycChuNha, EkycLink, HostProfile
from app.services import sensitive_file_service

LINK_GIO = 24
TOI_DA_BYTE = 10 * 1024 * 1024

#: loại ảnh → (cột trên bản eKYC, loại tệp nhạy cảm, nhãn)
LOAI_ANH: dict[str, tuple[str, str, str]] = {
    "cccd_truoc": ("cccd_truoc", "legal_rep_cccd", "CCCD mặt trước"),
    "cccd_sau": ("cccd_sau", "legal_rep_cccd", "CCCD mặt sau"),
    "chan_dung": ("chan_dung", "ekyc_selfie", "Ảnh chân dung"),
    "gpkd": ("gpkd", "gpkd_document", "Giấy phép kinh doanh"),
}

_MAGIC = (
    (b"\xff\xd8\xff", "jpg"),
    (b"\x89PNG\r\n\x1a\n", "png"),
    (b"RIFF", "webp"),
    (b"%PDF", "pdf"),
)


def _now() -> datetime:
    return datetime.utcnow()


def _bam_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _goc_link() -> str:
    return os.getenv("EKYC_LINK_BASE", "https://ancu365.ddns.net").rstrip("/")


# ── Link làm trên thiết bị khác ──────────────────────────────────────────────
def tao_link(db: Session, uid: int) -> dict:
    ho_so = _ho_so(db, uid)
    if ho_so.trang_thai in (EkycChuNha.CHO_DUYET, EkycChuNha.DA_DUYET):
        raise HTTPException(409, "Hồ sơ eKYC đã nộp — không cần làm lại")
    token = secrets.token_urlsafe(32)
    het = _now() + timedelta(hours=LINK_GIO)
    db.add(EkycLink(user_id=uid, token_hash=_bam_token(token), het_han=het))
    db.commit()
    return {"url": f"{_goc_link()}/ekyc?t={token}", "het_han": het.isoformat() + "Z"}


def nguoi_cua_token(db: Session, token: str) -> int:
    link = db.query(EkycLink).filter(EkycLink.token_hash == _bam_token(token or "")).first()
    if link is None:
        raise HTTPException(401, "Link eKYC không hợp lệ")
    if link.het_han < _now():
        raise HTTPException(410, "Link eKYC đã hết hạn — tạo link mới trong app")
    link.dung_luc = _now()
    return link.user_id


# ── Bản nháp ─────────────────────────────────────────────────────────────────
def _ho_so(db: Session, uid: int) -> EkycChuNha:
    h = db.query(EkycChuNha).filter(EkycChuNha.user_id == uid).first()
    if h is None:
        h = EkycChuNha(user_id=uid, trang_thai=EkycChuNha.NHAP)
        db.add(h)
        db.flush()
    return h


#: Bắt buộc để nộp (chủ dự án 14/10/2026: CCCD chỉ để TỰ XÁC THỰC thông tin,
#: không cần eKYC chân dung; giấy phép kinh doanh bỏ trống được, chỉ cảnh báo).
BAT_BUOC = ("cccd_truoc", "cccd_sau")


def _thieu(h: EkycChuNha) -> list[str]:
    thieu = [LOAI_ANH[loai][2] for loai in BAT_BUOC if not getattr(h, LOAI_ANH[loai][0])]
    if not h.ho_ten:
        thieu.append("Họ tên")
    if not h.so_cccd_hash:
        thieu.append("Số CCCD")
    return thieu


def _canh_bao(h: EkycChuNha) -> list[str]:
    """Không chặn nộp — chỉ nhắc (và admin thấy hồ sơ "chưa có GPKD")."""
    ra = []
    if not h.gpkd:
        ra.append("Chưa có ảnh giấy phép kinh doanh")
    if not h.so_gpkd:
        ra.append("Chưa khai số giấy phép kinh doanh")
    return ra


def xem(db: Session, uid: int) -> dict:
    h = _ho_so(db, uid)
    db.commit()
    return {
        "trang_thai": h.trang_thai,
        "ho_ten": h.ho_ten or "",
        "so_cccd_cuoi": h.so_cccd_cuoi or "",
        "ten_kinh_doanh": h.ten_kinh_doanh or "",
        "so_gpkd": h.so_gpkd or "",
        # Chỉ báo CÓ / CHƯA — ảnh nhạy cảm không trả ngược ra app.
        "anh": {loai: bool(getattr(h, cot)) for loai, (cot, _, _) in LOAI_ANH.items()},
        "thieu": _thieu(h),
        "canh_bao": _canh_bao(h),
        "ly_do_tu_choi": h.ly_do_tu_choi,
        "nop_luc": h.nop_luc.isoformat() + "Z" if h.nop_luc else None,
        "sua_duoc": h.trang_thai in (EkycChuNha.NHAP, EkycChuNha.TU_CHOI),
    }


def _sua_duoc(h: EkycChuNha) -> None:
    if h.trang_thai == EkycChuNha.CHO_DUYET:
        raise HTTPException(409, "Hồ sơ đang chờ admin duyệt")
    if h.trang_thai == EkycChuNha.DA_DUYET:
        raise HTTPException(409, "Hồ sơ đã được duyệt")


def luu_thong_tin(
    db: Session, uid: int, *, ho_ten: str, so_cccd: str, ten_kinh_doanh: str, so_gpkd: str
) -> dict:
    h = _ho_so(db, uid)
    _sua_duoc(h)
    ho_ten = re.sub(r"\s+", " ", (ho_ten or "").strip())
    if len(ho_ten) < 2:
        raise HTTPException(422, "Nhập họ tên như trên CCCD")
    so = re.sub(r"\D", "", so_cccd or "")
    if so:
        if len(so) != 12:
            raise HTTPException(422, "Số CCCD gồm 12 chữ số")
        h.so_cccd_hash = bcrypt.hashpw(so.encode(), bcrypt.gensalt()).decode()
        h.so_cccd_cuoi = so[-4:]
    # Giấy phép kinh doanh KHÔNG bắt buộc — bỏ trống thì chỉ cảnh báo.
    ten_kd = (ten_kinh_doanh or "").strip()
    so_kd = re.sub(r"\s+", "", so_gpkd or "")
    if so_kd and not re.fullmatch(r"[0-9A-Za-z./-]{4,50}", so_kd):
        raise HTTPException(422, "Số giấy phép kinh doanh không hợp lệ")
    h.ho_ten, h.ten_kinh_doanh, h.so_gpkd = ho_ten, ten_kd or None, so_kd or None
    if h.trang_thai == EkycChuNha.TU_CHOI:
        h.trang_thai = EkycChuNha.NHAP
    db.commit()
    return xem(db, uid)


def luu_anh(db: Session, uid: int, loai: str, anh_base64: str) -> dict:
    if loai not in LOAI_ANH:
        raise HTTPException(422, "Loại ảnh không hợp lệ")
    h = _ho_so(db, uid)
    _sua_duoc(h)
    try:
        du_lieu = base64.b64decode(anh_base64.split(",", 1)[-1], validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(422, "Ảnh không đọc được")
    if not du_lieu or len(du_lieu) > TOI_DA_BYTE:
        raise HTTPException(422, "Ảnh rỗng hoặc lớn hơn 10 MB")
    duoi = next((d for m, d in _MAGIC if du_lieu.startswith(m)), None)
    if duoi is None or (duoi == "webp" and du_lieu[8:12] != b"WEBP"):
        raise HTTPException(422, "Chỉ nhận ảnh JPG / PNG / WebP (giấy phép được thêm PDF)")
    if duoi == "pdf" and loai != "gpkd":
        raise HTTPException(422, "Ảnh CCCD / chân dung phải là ảnh chụp")
    cot, kieu, _ = LOAI_ANH[loai]
    duong = sensitive_file_service.store_file(
        du_lieu, kieu, owner_user_id=uid, extension=duoi, db=db, accessor_user_id=uid
    )
    setattr(h, cot, duong)
    if h.trang_thai == EkycChuNha.TU_CHOI:
        h.trang_thai = EkycChuNha.NHAP
    db.commit()
    return xem(db, uid)


def nop(db: Session, uid: int) -> dict:
    h = _ho_so(db, uid)
    _sua_duoc(h)
    thieu = _thieu(h)
    if thieu:
        raise HTTPException(422, "Còn thiếu: " + ", ".join(thieu))
    u = db.get(models.User, uid)
    p = db.query(OperatorBusinessProfile).filter(OperatorBusinessProfile.user_id == uid).first()
    if p is not None and p.verification_status == "verified":
        raise HTTPException(409, "Tài khoản đã được xác minh kinh doanh")
    if p is None:
        p = OperatorBusinessProfile(user_id=uid, gpkd_issued_at=_now())
        db.add(p)
    # Không có GPKD (chủ trọ cá nhân): tên hiển thị = họ tên, số / tệp để trống
    # — hàng đợi admin thấy rõ "chưa có giấy phép".
    p.business_name = h.ten_kinh_doanh or f"{h.ho_ten} (cá nhân, chưa có GPKD)"
    p.business_registration_number = h.so_gpkd or ""
    p.gpkd_document_path = h.gpkd or ""
    p.legal_representative_name = h.ho_ten
    p.legal_representative_phone = (u.phone if u else "") or ""
    p.legal_representative_cccd_number_hash = h.so_cccd_hash
    p.legal_representative_cccd_front_path = h.cccd_truoc
    p.legal_representative_cccd_back_path = h.cccd_sau
    p.legal_representative_selfie_path = h.chan_dung
    # Nộp lại sau khi bị từ chối → về hàng đợi.
    p.verification_status = "pending"
    p.updated_at = _now()
    h.trang_thai = EkycChuNha.CHO_DUYET
    h.nop_luc = _now()
    h.ly_do_tu_choi = None
    db.commit()
    return xem(db, uid)


# ── Admin duyệt / từ chối (gọi từ operator_business_service) ─────────────────
def sau_khi_admin_xet(
    db: Session, profile: OperatorBusinessProfile, *, duyet: bool, ly_do: Optional[str] = None
) -> None:
    """Đồng bộ kết quả hàng đợi KYC về eKYC chủ nhà + huy hiệu "đã xác minh".

    Hồ sơ KYC doanh nghiệp không đi qua eKYC chủ nhà (operator thuần) thì
    không có bản eKYC — bỏ qua, không đụng gì.
    """
    h = db.query(EkycChuNha).filter(EkycChuNha.user_id == profile.user_id).first()
    if h is None:
        return
    h.duyet_luc = _now()
    if duyet:
        h.trang_thai = EkycChuNha.DA_DUYET
        h.ly_do_tu_choi = None
        hp = db.query(HostProfile).filter(HostProfile.user_id == profile.user_id).first()
        if hp is None:
            hp = HostProfile(user_id=profile.user_id)
            db.add(hp)
        hp.verified = True
        if h.so_cccd_hash and not hp.cccd_number_hash:
            hp.cccd_number_hash = h.so_cccd_hash
        tieu_de, noi_dung = "eKYC chủ nhà đã được duyệt", "Tài khoản của bạn đã được xác minh."
    else:
        h.trang_thai = EkycChuNha.TU_CHOI
        h.ly_do_tu_choi = (ly_do or "").strip() or "Hồ sơ chưa hợp lệ"
        tieu_de, noi_dung = "eKYC chủ nhà cần bổ sung", h.ly_do_tu_choi
    helpers.push_notification(db, profile.user_id, "ekyc_chu_nha", tieu_de, noi_dung, h.id)
