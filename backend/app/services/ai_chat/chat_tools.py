"""Tools + system prompt gửi Claude mỗi lượt chat (Phase 08, T13, research Q3).

Thứ tự block giữ prefix ổn định từng byte để prompt cache trúng: tool (cache ở tool cuối)
→ skill cố định → skill hệ thống (cache) → giờ hiện tại (đổi mỗi lượt, không cache).
"""

from __future__ import annotations

import copy
from datetime import datetime

from app.ai_capabilities.action_runner import encode_tool_result
from app.ai_capabilities.fixed_skill import fixed_instructions
from app.ai_capabilities.fixed_tools import FIXED_TOOLS
from app.ai_capabilities.loader import Registry
from app.ai_capabilities.system_skills import render_system_skills

CACHE_EPHEMERAL = {"type": "ephemeral"}


def to_anthropic_tools() -> list[dict]:
    """2 tool cố định dạng Messages API; `cache_control` ở phần tử cuối."""
    tools = [
        {"name": t["name"], "description": t["description"], "input_schema": copy.deepcopy(t["input_schema"])}
        for t in FIXED_TOOLS
    ]
    tools[-1]["cache_control"] = dict(CACHE_EPHEMERAL)
    return tools


def build_system_blocks(registry: Registry, lang: str, now: datetime) -> list[dict]:
    """[skill cố định, skill hệ thống đã JSON-encode (cache), giờ hiện tại theo `now` (không cache)]."""
    skills = encode_tool_result(render_system_skills(registry, lang))
    return [
        {"type": "text", "text": fixed_instructions()},
        {"type": "text", "text": "SYSTEM SKILLS\n" + skills, "cache_control": dict(CACHE_EPHEMERAL)},
        {"type": "text", "text": "現在日時 / now: " + now.isoformat(timespec="seconds")},
    ]
