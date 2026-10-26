"""Tài khoản nhận tiền của một phòng — khách chuyển khoản / quét VietQR trong app.

Ba tầng, giải quyết DUY NHẤT ở đây (như `gia_tien_ich` với giá điện):
    phòng (rooms.tk_*) → toà (buildings.tk_*) → hồ sơ chủ nhà (host_profiles.bank_*)

Phòng / toà chỉ "có tài khoản" khi đủ số TK; khai thiếu số là coi như chưa khai
và rơi xuống tầng trên. Hồ sơ chủ nhà cũ chỉ có TÊN ngân hàng (chữ tự gõ) nên
không có BIN → app vẫn hiện số TK nhưng không vẽ được mã VietQR.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.services.ngan_hang_vn import NGAN_HANG

_SO_TK = re.compile(r"^[0-9A-Za-z]{4,30}$")


def _ten_nh(bin_: Optional[str]) -> str:
    nh = NGAN_HANG.get(bin_ or "")
    return nh[1] if nh else ""


def _goi(bin_: Optional[str], so: Optional[str], chu: Optional[str], nguon: str) -> Optional[dict]:
    so = (so or "").strip()
    if not so:
        return None
    return {
        "bin": bin_ if bin_ in NGAN_HANG else None,
        "ngan_hang": _ten_nh(bin_),
        "so_tai_khoan": so,
        "chu_tai_khoan": (chu or "").strip(),
        "nguon": nguon,
    }


def cua_toa(toa: Optional[models.Building]) -> Optional[dict]:
    if toa is None:
        return None
    return _goi(toa.tk_ngan_hang, toa.tk_so, toa.tk_chu, "toa")


def cua_phong(db: Session, room: models.Room, host_id: Optional[int]) -> Optional[dict]:
    """Tài khoản khách cần chuyển cho phòng này — hoặc None nếu chưa ai khai."""
    tk = _goi(room.tk_ngan_hang, room.tk_so, room.tk_chu, "phong")
    if tk:
        return tk
    tk = cua_toa(db.get(models.Building, room.building_id))
    if tk:
        return tk
    if host_id is None:
        return None
    from app.models.host import HostProfile

    hp = db.query(HostProfile).filter(HostProfile.user_id == host_id).first()
    if hp is None:
        return None
    tk = _goi(None, hp.bank_account_number, hp.bank_account_holder, "ho_so")
    if tk:
        tk["ngan_hang"] = hp.bank_name or ""
    return tk


def kiem(bin_: str, so: str, chu: str) -> tuple[str, str, str]:
    """Chuẩn hoá + kiểm ô nhập; sai thì 422 nói rõ ô nào."""
    bin_ = (bin_ or "").strip()
    if bin_ not in NGAN_HANG:
        raise HTTPException(422, "Chọn ngân hàng trong danh sách")
    so = re.sub(r"[\s.\-]", "", so or "")
    if not _SO_TK.fullmatch(so):
        raise HTTPException(422, "Số tài khoản chỉ gồm chữ số (4–30 ký tự)")
    # Chủ TK in hoa không dấu — đúng như app ngân hàng hiển thị khi chuyển.
    chu = unicodedata.normalize("NFD", (chu or "").strip())
    chu = "".join(c for c in chu if unicodedata.category(c) != "Mn")
    chu = chu.replace("đ", "d").replace("Đ", "D").upper()
    chu = re.sub(r"\s+", " ", chu)
    if not 2 <= len(chu) <= 100:
        raise HTTPException(422, "Nhập tên chủ tài khoản")
    return bin_, so, chu


def ghi(obj, bin_: Optional[str], so: Optional[str], chu: Optional[str]) -> None:
    """Ghi lên toà / phòng. Bỏ trống số TK = XOÁ (phòng quay về dùng của toà)."""
    if not (so or "").strip():
        obj.tk_ngan_hang = obj.tk_so = obj.tk_chu = None
        return
    obj.tk_ngan_hang, obj.tk_so, obj.tk_chu = kiem(bin_ or "", so or "", chu or "")
