import base64
import os
import random
import string
from datetime import datetime

from fastapi import APIRouter, Body, Depends, HTTPException

from app import auth
from app.config import settings

router = APIRouter(prefix="/api", tags=["upload"])

_ALLOWED_IMAGE = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
# Video cho Reel. Cap riêng, lớn hơn ảnh (xem _MAX_VIDEO_BASE64_BYTES).
_ALLOWED_VIDEO = {".mp4", ".webm", ".mov", ".m4v"}
# File thiết kế (PDF) cho portfolio đơn vị (Đợt 2 profile uy tín). Chỉ PDF —
# .dwg/.cad bị loại: khó kiểm nội dung, ít khách mở được, dễ thành bãi rác.
_ALLOWED_DOC = {".pdf"}
_ALLOWED = _ALLOWED_IMAGE | _ALLOWED_VIDEO | _ALLOWED_DOC
# 8 MB raw → ~10.7 MB base64. Mục tiêu chặn anonymous abuse fill ổ cứng.
# Có thể nâng/giảm trong settings sau khi có observability.
_MAX_BASE64_BYTES = 11 * 1024 * 1024
# Reel video: 30 MB raw → ~40 MB base64. Cap riêng vì clip ngắn nặng hơn ảnh.
# LƯU Ý: base64 nạp cả vào RAM — nếu sau này reel dài hơn, chuyển sang
# multipart/streaming upload thay vì base64.
_MAX_VIDEO_BASE64_BYTES = 40 * 1024 * 1024
# PDF thiết kế: 20 MB raw → ~27 MB base64. Bản vẽ có thể nặng.
_MAX_DOC_BASE64_BYTES = 27 * 1024 * 1024


def _ext_of(filename: str) -> str:
    if not filename or "." not in filename:
        return ".jpg"
    e = "." + filename.rsplit(".", 1)[1].lower()
    return e if e in _ALLOWED else ".jpg"


@router.post("/upload", status_code=201)
def upload(
    body: dict = Body(...),
    _claims: dict = Depends(auth.require_user),
):
    """Upload là privileged action — bắt buộc auth để ngăn anonymous attacker
    spam ghi đĩa. Size cap chặn 100 MB blob nhồi vào memory."""
    data = body.get("data") or ""
    if not data:
        raise HTTPException(400, "Missing data")
    # Cap theo loại file: video (reel) > PDF thiết kế > ảnh.
    _ext = _ext_of(body.get("filename") or "")
    _is_video = _ext in _ALLOWED_VIDEO
    _is_doc = _ext in _ALLOWED_DOC
    if _is_video:
        _cap = _MAX_VIDEO_BASE64_BYTES
    elif _is_doc:
        _cap = _MAX_DOC_BASE64_BYTES
    else:
        _cap = _MAX_BASE64_BYTES
    if len(data) > _cap:
        raise HTTPException(413, "File quá lớn (ảnh >8MB, PDF >20MB, video >30MB)")
    try:
        raw = base64.b64decode(data)
    except Exception:
        raise HTTPException(400, "base64 không hợp lệ")

    # Kiểm nội dung THẬT (magic bytes), không tin đuôi file do client gửi.
    # Video: box 'ftyp' ở offset 4 (MP4/MOV/M4V) HOẶC EBML 1A45DFA3 (WebM).
    if _is_video:
        _ok = (len(raw) > 12 and raw[4:8] == b"ftyp") or raw[:4] == b"\x1a\x45\xdf\xa3"
        if not _ok:
            raise HTTPException(400, "File không phải video hợp lệ (mp4/webm/mov)")
    # PDF: 5 byte đầu là "%PDF-". Chặn đổi đuôi để nhét file lạ.
    if _is_doc and raw[:5] != b"%PDF-":
        raise HTTPException(400, "File không phải PDF hợp lệ")

    os.makedirs(settings.upload_dir, exist_ok=True)
    ext = _ext_of(body.get("filename") or "")
    suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
    name = f"{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{suffix}{ext}"
    path = os.path.join(settings.upload_dir, name)
    with open(path, "wb") as f:
        f.write(raw)
    return {"filename": name, "url": f"/uploads/{name}"}
