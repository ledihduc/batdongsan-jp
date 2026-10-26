"""
Provinces service — load 63 tỉnh/thành Việt Nam từ JSON tĩnh.
Đánh dấu has_tiles dựa trên GULAND_PROVINCE_MAP (56 tỉnh có raster overlay
qua CDN guland; backend proxy + cache local — xem guland_tile_proxy.py).
"""

from __future__ import annotations

import json
import os
import re
import unicodedata
from functools import lru_cache
from typing import Any, Optional

from app.data.guland_province_map import GULAND_PROVINCE_MAP


def _strip_accents(text: str) -> str:
    """Bỏ dấu + bỏ dấu câu để fuzzy match (vd: 'TP. Hồ Chí Minh' → 'tp ho chi minh')."""
    nfkd = unicodedata.normalize("NFKD", text)
    no_marks = "".join(c for c in nfkd if not unicodedata.combining(c))
    # đ/Đ không decompose, xử lý thủ công
    s = no_marks.replace("đ", "d").replace("Đ", "D").lower()
    # Bỏ dấu câu (giữ chữ/số/khoảng trắng), gộp khoảng trắng → so khớp bền hơn.
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


# Alias city free-text phổ biến → slug tỉnh (đã chuẩn hoá bỏ dấu/câu, gộp space).
_CITY_ALIASES: dict[str, str] = {
    "sai gon": "tp-ho-chi-minh",
    "tphcm": "tp-ho-chi-minh",
    "tp hcm": "tp-ho-chi-minh",
    "hcm": "tp-ho-chi-minh",
    "ho chi minh": "tp-ho-chi-minh",
    "tp ho chi minh": "tp-ho-chi-minh",
    "thanh pho ho chi minh": "tp-ho-chi-minh",
    "ha noi": "ha-noi",
    "hn": "ha-noi",
    "thu do ha noi": "ha-noi",
    "da nang": "da-nang",
    "hue": "thua-thien-hue",
    "tt hue": "thua-thien-hue",
    "vung tau": "ba-ria-vung-tau",
    "ba ria vung tau": "ba-ria-vung-tau",
}


def province_slug_for_city(city: Optional[str]) -> Optional[str]:
    """Chuẩn hoá city free-text → slug tỉnh (province_code). None nếu không khớp.

    Thứ tự: (1) alias phổ biến (Sài Gòn/HCM/HN…), (2) fuzzy search theo tên/slug.
    """
    if not city:
        return None
    norm = _strip_accents(city)
    if not norm:
        return None
    if norm in _CITY_ALIASES:
        return _CITY_ALIASES[norm]
    hits = search_provinces(city, limit=1)
    return hits[0]["slug"] if hits else None


@lru_cache(maxsize=1)
def _load_raw() -> list[dict[str, Any]]:
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(here, "data", "vietnam-provinces.json")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _enrich(p: dict[str, Any]) -> dict[str, Any]:
    """Thêm has_tiles + tile_layer_slug (kèm v2/ prefix nếu có)."""
    slug = p["slug"]
    guland_path = GULAND_PROVINCE_MAP.get(slug)
    return {
        **p,
        "has_tiles": guland_path is not None,
        "tile_layer_slug": guland_path,
    }


def list_provinces() -> list[dict[str, Any]]:
    """Trả về 63 provinces (sorted by name), kèm has_tiles flag."""
    return [_enrich(p) for p in _load_raw()]


def search_provinces(q: str, limit: int = 20) -> list[dict[str, Any]]:
    """
    Tìm theo tên (có dấu hoặc không dấu) hoặc slug.
    Ưu tiên: startswith > contains.
    """
    q_norm = _strip_accents(q)
    if not q_norm:
        return []

    starts: list[dict[str, Any]] = []
    contains: list[dict[str, Any]] = []
    for p in _load_raw():
        name_norm = _strip_accents(p["name"])
        slug = p["slug"]
        if name_norm.startswith(q_norm) or slug.startswith(q_norm):
            starts.append(_enrich(p))
        elif q_norm in name_norm or q_norm in slug:
            contains.append(_enrich(p))
    return (starts + contains)[:limit]
