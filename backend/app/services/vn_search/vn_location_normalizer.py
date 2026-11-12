"""Chuẩn hoá tham số `location` của search VN trước khi lọc (Phase 13, QA F1).

Model/khách viết địa danh nhiều dạng: "TP. Hồ Chí Minh", "Sài Gòn", "Hanoi", "Q1", "District 1",
"Ba Đình, Hà Nội". Dữ liệu `houses` lưu `city` "Hồ Chí Minh"/"Hà Nội", `district` "Quận 1"/"Ba Đình".
⇒ tách theo dấu phẩy thành nhiều phần (mọi phần phải khớp), mỗi phần bỏ tiền tố hành chính
("TP.", "Thành phố", "Tỉnh") và đổi bí danh / dạng viết tắt quận về tên lưu trong DB.
"""

from __future__ import annotations

import re
import unicodedata

_PREFIX_RE = re.compile(r"^(thành phố|thanh pho|tp\.?|tỉnh|tinh)\s*", re.IGNORECASE)
_SUFFIX_RE = re.compile(r"\s+(city|province)$", re.IGNORECASE)
_DISTRICT_RE = re.compile(r"^(?:quận|quan|q\.?|district|dist\.?)\s*(\d{1,2})$", re.IGNORECASE)
_CITY_ALIASES = {
    "hồ chí minh": "Hồ Chí Minh", "ho chi minh": "Hồ Chí Minh", "hcm": "Hồ Chí Minh", "hcmc": "Hồ Chí Minh",
    "sài gòn": "Hồ Chí Minh", "sai gon": "Hồ Chí Minh", "saigon": "Hồ Chí Minh",
    "hà nội": "Hà Nội", "ha noi": "Hà Nội", "hanoi": "Hà Nội",
}


def _normalize_part(raw: str) -> str:
    part = unicodedata.normalize("NFC", raw).strip()
    if part.lower().replace(".", "") in ("tphcm", "tp hcm"):
        return "Hồ Chí Minh"
    part = _SUFFIX_RE.sub("", _PREFIX_RE.sub("", part)).strip()
    district = _DISTRICT_RE.match(part)
    if district:
        return f"Quận {int(district.group(1))}"
    return _CITY_ALIASES.get(part.lower(), part)


def normalize_location(location: str | None) -> list[str]:
    """`"Quận 1, TP. Hồ Chí Minh"` ⇒ `["Quận 1", "Hồ Chí Minh"]`; rỗng ⇒ `[]`."""
    if not location:
        return []
    return [p for p in (_normalize_part(x) for x in location.split(",")) if p]


def escape_like(value: str) -> str:
    """Escape `%`, `_`, `\\` cho LIKE/ILIKE với `escape="\\"` (QA F6)."""
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
