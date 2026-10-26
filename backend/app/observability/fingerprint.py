"""
Fingerprint lỗi — chữ ký ổn định để gom (dedupe) các lần lỗi giống nhau.

Dùng ở 2 nơi:
  - error_handler khi ghi log 500 (để mỗi bản ghi có sẵn fingerprint), và
  - collect_errors.py khi gom nhóm.

Chuẩn hoá message (bỏ số, uuid, path cụ thể) để cùng loại lỗi rơi vào 1 nhóm
dù chi tiết khác nhau.
"""

from __future__ import annotations

import hashlib
import re

_UUID_RE = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I
)
_NUM_RE = re.compile(r"\d+")
_HEXADDR_RE = re.compile(r"0x[0-9a-f]+", re.I)
_QUOTED_RE = re.compile(r"'[^']*'|\"[^\"]*\"")
_ROUTE_SEG_RE = re.compile(r"/\d+(?=/|$)")


def normalize_route(route: str) -> str:
    """Thay segment số trong path bằng {id} để cùng endpoint gom 1 nhóm."""
    return _ROUTE_SEG_RE.sub("/{id}", route or "")


def normalize_message(msg: str) -> str:
    """Bỏ phần biến thiên (số, uuid, địa chỉ, chuỗi trong nháy) khỏi message."""
    s = msg or ""
    s = _UUID_RE.sub("<uuid>", s)
    s = _HEXADDR_RE.sub("<addr>", s)
    s = _QUOTED_RE.sub("<str>", s)
    s = _NUM_RE.sub("<n>", s)
    return s.strip()[:300]


def compute_fingerprint(
    *,
    exc_type: str | None = None,
    message: str | None = None,
    route: str | None = None,
    top_frame: str | None = None,
) -> str:
    """SHA1 ngắn từ (exc_type, message chuẩn hoá, route template, frame trên cùng)."""
    parts = [
        exc_type or "",
        normalize_message(message or ""),
        normalize_route(route or ""),
        top_frame or "",
    ]
    raw = "\x1f".join(parts)
    return hashlib.sha1(raw.encode("utf-8", "replace")).hexdigest()[:16]


def top_frame_of(tb_text: str) -> str:
    """Lấy dòng 'File ... line ..., in ...' cuối cùng (frame gần chỗ raise nhất)."""
    frames = [ln.strip() for ln in (tb_text or "").splitlines() if ln.strip().startswith("File ")]
    if not frames:
        return ""
    # Bỏ đường dẫn tuyệt đối, giữ phần sau 'app/' hoặc tên file.
    last = frames[-1]
    m = re.search(r"File \"(.+?)\", line (\d+), in (.+)", last)
    if not m:
        return normalize_message(last)
    path, line, func = m.group(1), m.group(2), m.group(3)
    short = re.sub(r"^.*?/(app/|scripts/|tests/)", r"\1", path)
    return f"{short}:{line}:{func}"
