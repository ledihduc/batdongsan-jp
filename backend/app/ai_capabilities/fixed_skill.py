"""Skill cố định `static/SKILL.md` — giống nhau mọi thị trường, dùng làm `instructions` MCP (P07) và system prompt chat (P08)."""

from __future__ import annotations

import pathlib
from functools import lru_cache

FIXED_SKILL_PATH = pathlib.Path(__file__).parent / "static" / "SKILL.md"


@lru_cache(maxsize=1)
def fixed_skill_markdown() -> str:
    """Cả file, kể cả front matter (để người dùng cài làm skill phía client)."""
    return FIXED_SKILL_PATH.read_text(encoding="utf-8")


def fixed_instructions() -> str:
    """Thân file, bỏ khối front matter `--- … ---` ở đầu."""
    text = fixed_skill_markdown()
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            text = text[end + len("\n---"):]
    return text.strip()
