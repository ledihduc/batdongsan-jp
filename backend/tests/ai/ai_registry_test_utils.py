"""Dựng file registry tạm cho test loader/runner (plan 20261027-1102 Phase 05)."""

from __future__ import annotations

import os
import pathlib
from typing import Optional

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

import yaml

from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH

_GUIDE = {"ja": "ガイド", "vi": "Hướng dẫn", "en": "Guide"}


def make_action(**overrides) -> dict:
    """Action hợp lệ tối thiểu; handler trỏ tool thật để import được."""
    action = {
        "name": "find_station",
        "title": {"ja": "駅検索", "vi": "Tìm ga", "en": "Find station"},
        "description": {"ja": "駅を探す", "vi": "Tìm ga theo tên", "en": "Find a station by name"},
        "mode": "read",
        "requires_login": False,
        "enabled": True,
        "handler": {"type": "python", "target": "app.services.jp_search.ai_tools:tool_search_stations"},
        "params": {
            "type": "object",
            "additionalProperties": False,
            "required": ["q"],
            "properties": {"q": {"type": "string", "minLength": 1, "maxLength": 40}},
        },
    }
    action.update(overrides)
    return action


def write_registry(
    tmp_path: pathlib.Path, actions: list[dict], *, guide: Optional[dict] = None,
    market: str = "jp", default_lang: str = "ja",
) -> pathlib.Path:
    path = tmp_path / f"registry.{market}.yaml"
    doc = {"version": 2, "market": market, "default_lang": default_lang,
           "guide": guide or _GUIDE, "actions": actions}
    path.write_text(yaml.safe_dump(doc, allow_unicode=True, sort_keys=False), encoding="utf-8")
    return path


def packaged_registry_dict() -> dict:
    return yaml.safe_load(DEFAULT_REGISTRY_PATH.read_text(encoding="utf-8"))
