"""Kết quả `get_system_skills`: guide + danh sách action theo ngôn ngữ người dùng (AC16, D18)."""

from __future__ import annotations

import copy
import re
from typing import Optional

from app.ai_capabilities.loader import Registry


def pick_text(texts: dict, lang: str, default_lang: str) -> str:
    """Ưu tiên `lang` → `en` → `default_lang` (loader đảm bảo có đủ ja/vi/en)."""
    for key in (lang, "en", default_lang):
        if texts.get(key):
            return texts[key]
    return ""


_LANG_ALIASES = {"vn": "vi", "jp": "ja"}


def normalize_lang(lang: Optional[str]) -> str:
    """`ja-JP`, `vi_VN`, `ja-JP,en;q=0.9` ⇒ `ja`/`vi`; rỗng/không đọc được ⇒ "" (QA M1)."""
    m = re.match(r"\s*([A-Za-z]{2,3})", lang or "")
    code = m.group(1).lower() if m else ""
    return _LANG_ALIASES.get(code, code)


def render_system_skills(registry: Registry, lang: Optional[str] = None) -> dict:
    lang = normalize_lang(lang) or registry.default_lang
    return {
        "registry_version": registry.version,
        "market": registry.market,
        "default_lang": registry.default_lang,
        "lang": lang,
        "guide": pick_text(registry.guide, lang, registry.default_lang),
        "actions": [
            {
                "name": a.name,
                "title": pick_text(a.title, lang, registry.default_lang),
                "description": pick_text(a.description, lang, registry.default_lang),
                "mode": a.mode,
                "requires_login": a.requires_login,
                "params": copy.deepcopy(a.params),  # kênh gọi sửa cũng không đụng registry
            }
            for a in registry.actions
        ],
    }
