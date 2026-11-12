"""`registry.vn.yaml` đóng gói: 3 action, đủ ja/vi/en, bật AI cho region vn (Phase 13, AC16, T8, T17)."""

from __future__ import annotations

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

import yaml

from app.ai_capabilities.loader import PACKAGED_REGISTRY_DIR, ai_enabled_for_region, load_registry
from app.ai_capabilities.system_skills import render_system_skills
from app.config import settings

VN_PATH = PACKAGED_REGISTRY_DIR / "registry.vn.yaml"
LANGS = ("ja", "vi", "en")


def test_ai_registry_vn_packaged_file_loads_three_actions():
    # Act
    reg = load_registry(VN_PATH)
    # Assert
    assert reg.market == "vn" and reg.default_lang == "vi"
    assert reg.names() == ["search_listings", "get_listing", "save_favorite"]
    assert "request_viewing" not in reg.names()


def test_ai_registry_vn_every_text_has_ja_vi_en():
    # Arrange
    doc = yaml.safe_load(VN_PATH.read_text(encoding="utf-8"))
    texts = [doc["guide"]] + [a[k] for a in doc["actions"] for k in ("title", "description")]
    # Act / Assert
    for text in texts:
        assert all((text.get(lang) or "").strip() for lang in LANGS), text


def test_ai_registry_vn_save_favorite_is_write_with_login():
    # Act
    action = load_registry(VN_PATH).get("save_favorite")
    # Assert
    assert action.mode == "write" and action.requires_login is True


def test_ai_registry_enabled_for_vn_with_packaged_dir(monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "ai_registry_dir", "")
    # Act / Assert
    assert ai_enabled_for_region("vn") is True


def test_ai_system_skills_vn_lang_en_returns_english_titles():
    # Act
    out = render_system_skills(load_registry(VN_PATH), "en")
    # Assert
    assert out["market"] == "vn" and out["lang"] == "en"
    assert out["actions"][0]["title"] == "Search listings" and "Vietnam" in out["guide"]


def test_ai_system_skills_vn_default_lang_is_vietnamese():
    # Act
    out = render_system_skills(load_registry(VN_PATH))
    # Assert
    assert out["lang"] == "vi" and out["actions"][0]["title"] == "Tìm nhà"
