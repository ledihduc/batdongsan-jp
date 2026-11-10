"""render_system_skills chọn ngôn ngữ + skill cố định trung tính thị trường (AC16, D18, D19 — Phase 05)."""

from __future__ import annotations

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.ai_capabilities.fixed_skill import fixed_instructions, fixed_skill_markdown
from app.ai_capabilities.loader import DEFAULT_REGISTRY_PATH, load_registry
from app.ai_capabilities.system_skills import render_system_skills

ACTION_KEYS = {"name", "title", "description", "mode", "requires_login", "params"}


def test_ai_system_skills_default_lang_returns_japanese():
    # Act
    out = render_system_skills(load_registry(DEFAULT_REGISTRY_PATH))
    # Assert
    assert out["lang"] == "ja" and out["market"] == "jp" and out["default_lang"] == "ja"
    assert "東京" in out["guide"] and out["actions"][0]["title"] == "賃貸物件を検索"


def test_ai_system_skills_lang_en_returns_english():
    # Act
    out = render_system_skills(load_registry(DEFAULT_REGISTRY_PATH), "en")
    # Assert
    assert out["actions"][0]["title"] == "Search rental listings" and "Tokyo" in out["guide"]


def test_ai_system_skills_lang_vi_returns_vietnamese():
    # Act
    out = render_system_skills(load_registry(DEFAULT_REGISTRY_PATH), "vi")
    # Assert
    assert out["actions"][0]["title"] == "Tìm nhà thuê" and "Bạn giúp" in out["guide"]


def test_ai_system_skills_unknown_lang_falls_back_to_english():
    # Act (registry không có zh)
    out = render_system_skills(load_registry(DEFAULT_REGISTRY_PATH), "zh")
    # Assert
    assert out["actions"][0]["title"] == "Search rental listings" and "Tokyo" in out["guide"]


def test_ai_system_skills_lists_enabled_actions_with_schema_mode_login():
    # Arrange
    reg = load_registry(DEFAULT_REGISTRY_PATH)
    # Act
    out = render_system_skills(reg, "ja")
    # Assert
    assert out["registry_version"] == reg.version
    assert [a["name"] for a in out["actions"]] == reg.names()
    for rendered, action in zip(out["actions"], reg.actions):
        assert set(rendered) == ACTION_KEYS
        assert rendered["params"] == action.params and rendered["mode"] == action.mode
        assert rendered["requires_login"] is action.requires_login
    assert {a["name"] for a in out["actions"] if a["mode"] == "write"} == {"save_favorite", "request_viewing"}


def test_ai_fixed_skill_instructions_are_market_neutral():
    # Act
    text = fixed_instructions()
    # Assert
    assert "get_system_skills" in text and "run_action" in text and "default_lang" in text
    assert not any(n in text for n in ["search_listings", "get_listing", "search_stations",
                                       "save_favorite", "request_viewing"])
    assert not any(w in text for w in ["Tokyo", "東京", "Việt Nam", "yen", "VND"])
    assert not text.startswith("---") and fixed_skill_markdown().startswith("---")
